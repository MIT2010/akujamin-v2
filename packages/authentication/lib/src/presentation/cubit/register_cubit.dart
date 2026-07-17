import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import '../../data/resize_image.dart';
import '../../domain/normalize_extracted_field.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/complete_registration_usecase.dart';
import 'auth_cubit.dart';
import 'register_state.dart';

/// Orchestrates the form/KTP/submit half of registration — the selfie
/// camera *hardware* lifecycle lives in the separate [SelfieCameraCubit]
/// (both provided together by `RegisterPage`, same two-cubit-plus-page-
/// level-listener shape `TestPage` already uses for `TestCubit`+
/// `ProctoringCubit`), but [selfiePath] is tracked here because it has to
/// survive well past the camera screen — reused for both KTP extraction
/// and the final submit.
///
/// No UseCase for `loadForm`/`scanKtp` — both are thin pass-throughs
/// (`FormInputRepository.getForm` and `AuthRepository.extractKtp`, neither
/// has real orchestration of its own). `submit` calls
/// [CompleteRegistrationUseCase] instead, which *does* have real
/// validation (§21) — see that class's doc comment.
@injectable
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(
    this._formInputRepository,
    this._authRepository,
    this._completeRegistrationUseCase,
    this._authCubit,
  ) : super(const RegisterState());

  final FormInputRepository _formInputRepository;
  final AuthRepository _authRepository;
  final CompleteRegistrationUseCase _completeRegistrationUseCase;
  final AuthCubit _authCubit;

  final ImagePicker _picker = ImagePicker();

  void setSelfiePath(String path) {
    emit(state.copyWith(status: RegisterStatus.selfieTaken, selfiePath: path));
  }

  void retakeSelfie() {
    emit(state.copyWith(status: RegisterStatus.takingSelfie, selfiePath: null));
  }

  Future<void> loadForm() async {
    emit(state.copyWith(status: RegisterStatus.loadingForm));

    final result = await _formInputRepository.getForm('/registrasi/profile');

    result.fold(
      (failure) =>
          emit(state.copyWith(status: RegisterStatus.failed, error: failure)),
      (forms) =>
          emit(state.copyWith(status: RegisterStatus.inputForm, forms: forms)),
    );
  }

  /// Manual entry — always a value the field's own widget produced
  /// (`DynamicFormField` never hands back an option that isn't in its own
  /// list, and always ISO for dates), so no normalization risk here the
  /// way OCR-extracted values have.
  void setInput(String label, String value) {
    final updated = Map<String, String>.from(state.formResults)
      ..[label] = value;
    final cleared = clearDependentFields(label, state.forms, updated);
    emit(state.copyWith(formResults: cleared));
  }

  /// KTP scan is optional/assistive, exactly like the old app: cancelling
  /// the picker or a failed extraction both just return to `inputForm` for
  /// manual entry, never a hard stop.
  Future<void> scanKtp() async {
    final selfiePath = state.selfiePath;
    if (selfiePath == null) return;

    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    emit(state.copyWith(status: RegisterStatus.extractingKtp));

    try {
      final ktpBytes = await resizeImageBytes(image.path);
      final selfieBytes = await resizeImageBytes(selfiePath);

      final result = await _authRepository.extractKtp(
        ktpImageBytes: ktpBytes,
        selfieImageBytes: selfieBytes,
      );

      // Mandatory cleanup (docs/qa/register.md) — the KTP scan is
      // single-use (only ever sent to this one call), unlike the selfie,
      // which is still needed for the final submit. Best-effort, same
      // shape as `PaymentCubit._cleanupProofImage`: a cleanup failure must
      // never block the flow.
      await _deleteFileQuietly(image.path);

      result.fold(
        (failure) => emit(
          state.copyWith(status: RegisterStatus.inputForm, error: failure),
        ),
        (extracted) => emit(
          state.copyWith(
            status: RegisterStatus.ktpExtracted,
            formResults: _applyExtractedFields(extracted),
          ),
        ),
      );
    } catch (e) {
      await _deleteFileQuietly(image.path);
      emit(
        state.copyWith(
          status: RegisterStatus.inputForm,
          error: ValidationFailure(e.toString()),
        ),
      );
    }
  }

  /// Approved fix over the old app's `_normalizeInput`: a field whose
  /// extracted value can't be confidently normalized (an OCR select value
  /// matching no real option, a date matching neither ISO nor DD-MM-YYYY)
  /// is left **unset** here — not filled with a guess — so it surfaces as
  /// "still empty" for the user to fill in manually, exactly the same
  /// signal `CompleteRegistrationUseCase` already gives any other blank
  /// required field.
  Map<String, String> _applyExtractedFields(Map<String, String> extracted) {
    final results = Map<String, String>.from(state.formResults);

    for (final entry in extracted.entries) {
      final field = state.forms.where((f) => f.label == entry.key).firstOrNull;

      if (field == null) {
        results[entry.key] = entry.value;
        continue;
      }

      final normalized = field.isDate
          ? normalizeDateValue(entry.value)
          : field.isSelect
          ? normalizeSelectValue(field, entry.value)
          : entry.value;

      if (normalized != null) {
        results[entry.key] = normalized;
      } else {
        results.remove(entry.key);
      }
    }

    return results;
  }

  Future<void> submit() async {
    final selfiePath = state.selfiePath;
    if (selfiePath == null) {
      emit(
        state.copyWith(
          status: RegisterStatus.failed,
          error: const ValidationFailure('Foto selfie tidak ditemukan.'),
        ),
      );
      return;
    }

    emit(state.copyWith(status: RegisterStatus.submitting));

    try {
      // XFile, not dart:io's File -- real bug, found 2026-07-17 from a
      // live web submit: `File(path).readAsBytes()` throws "Unsupported
      // operation: _Namespace" on Flutter Web, since dart:io's
      // filesystem APIs don't exist there and `selfiePath` is actually a
      // `blob:` URL on web, not a real path. XFile reads bytes portably
      // on every platform.
      final selfieBytes = await XFile(selfiePath).readAsBytes();

      final result = await _completeRegistrationUseCase(
        CompleteRegistrationParams(
          forms: state.forms,
          formResults: state.formResults,
          selfieImageBytes: selfieBytes,
        ),
      );

      await result.fold(
        (failure) async {
          emit(
            state.copyWith(status: RegisterStatus.inputForm, error: failure),
          );
        },
        (_) async {
          // Only deleted on success, and only here — the selfie is reused
          // for KTP extraction *and* this final submit, so it can't be
          // cleaned up any earlier without breaking the flow.
          await _deleteFileQuietly(selfiePath);
          await _refreshRegisteredFlag();
          emit(state.copyWith(status: RegisterStatus.success));
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RegisterStatus.inputForm,
          error: ValidationFailure(e.toString()),
        ),
      );
    }
  }

  /// Mirrors the old app's `HomePage._makeProfile()`: re-fetches
  /// `/auth/me` rather than setting `isRegistered` locally, so the app's
  /// session state reflects whatever the server actually persisted.
  /// Best-effort — a failed refresh must never undo a registration that
  /// already succeeded server-side; the next full app restart picks up the
  /// correct flag regardless via `AuthCubit`'s own cached-session restore.
  Future<void> _refreshRegisteredFlag() async {
    final result = await _authRepository.refreshProfile();
    result.fold((_) {}, (value) {
      final (user, sessionProfile) = value;
      _authCubit.setAuthenticated(user, sessionProfile: sessionProfile);
    });
  }

  Future<void> _deleteFileQuietly(String path) async {
    // No filesystem to clean up on web -- `path` is a `blob:` URL there,
    // not a real file, and dart:io's `File` throws "Unsupported
    // operation" the moment it's touched at all (real bug, found
    // 2026-07-17). The browser garbage-collects the underlying blob
    // itself once nothing references it anymore; nothing to do here.
    if (kIsWeb) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort only — see doc comments above.
    }
  }
}

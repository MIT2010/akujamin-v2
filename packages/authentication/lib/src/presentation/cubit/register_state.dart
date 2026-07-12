import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared/shared.dart';

part 'register_state.freezed.dart';

/// Mirrors the old app's `RegisStatus` linear flow
/// (`takePict→takenPict→getting→inputForm→extracting→extracted→sending→
/// success/failed`), renamed for clarity. `takingSelfie`/`selfieTaken`
/// only ever apply before the form is loaded — once past `loadingForm`,
/// the selfie screen is never shown again (confirmed: the old app's own
/// `SelfieView` is gated on exactly those two statuses).
enum RegisterStatus {
  takingSelfie,
  selfieTaken,
  loadingForm,
  inputForm,
  extractingKtp,
  ktpExtracted,
  submitting,
  success,
  failed,
}

/// One flat class with a status enum, not a sealed union — same reasoning
/// as `TestState`: `forms`/`formResults`/`selfiePath` all need to stay
/// readable while `status == failed` (the form remains visible under an
/// error snackbar, it doesn't blank out).
@freezed
abstract class RegisterState with _$RegisterState {
  const factory RegisterState({
    @Default(RegisterStatus.takingSelfie) RegisterStatus status,
    @Default(<FormInputField>[]) List<FormInputField> forms,
    @Default(<String, String>{}) Map<String, String> formResults,
    String? selfiePath,
    Failure? error,
  }) = _RegisterState;
}

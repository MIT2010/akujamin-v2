import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/payment_account_detail.dart';

part 'payment_state.freezed.dart';

/// The wizard step, kept as a plain enum on one shared state class rather
/// than a freezed sealed union (unlike `HistoryState`/`ChatState`):
/// `formResults`/`forms`/`voucherCode`/`account` all genuinely need to
/// survive across step transitions (built up in `demography`, still read
/// in `payment` and `review`), which is exactly the shape a sealed union
/// of independent variants doesn't fit — same reasoning the old app's own
/// single `PaymentState` class already reflects.
enum PaymentStep { checking, demography, confirmation, payment, review }

@freezed
abstract class PaymentState with _$PaymentState {
  const factory PaymentState({
    @Default(PaymentStep.checking) PaymentStep step,
    @Default(<FormInputField>[]) List<FormInputField> forms,
    @Default(<String, String>{}) Map<String, String> formResults,
    String? voucherCode,
    PaymentAccountDetail? account,

    /// Proof-of-payment URL already on the server (from a previous
    /// session/upload) — distinct from [pickedImagePath], a freshly
    /// picked-but-not-yet-uploaded local file.
    String? existingProofUrl,
    String? pickedImagePath,
    Duration? remaining,
    @Default(false) bool isExpired,
    @Default(false) bool isPaid,
    @Default(false) bool isLoading,
    @Default(false) bool isFailed,
    Failure? error,
  }) = _PaymentState;
}

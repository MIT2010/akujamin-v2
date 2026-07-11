import 'package:core/core.dart';

import '../entities/form_input_field.dart';

/// Abstract contract for fetching a server-driven dynamic form schema
/// from a caller-supplied endpoint. No UseCase in front of this
/// (§21/ADR-004) — the old app's `GetFormsUsecase` was a one-line
/// passthrough, same shape as `about`/`onboarding`/`history`/`counseling`.
abstract class FormInputRepository {
  Future<Result<Failure, List<FormInputField>>> getForm(String endpoint);
}

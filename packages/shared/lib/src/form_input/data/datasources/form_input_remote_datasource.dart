import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

/// Deliberately thin, and deliberately returns a raw `List`, not a `Map`
/// envelope — this endpoint shape has no `{status, data}` wrapper. See
/// `FormInputFieldModel`'s doc comment for how this was confirmed against
/// the old app.
@injectable
class FormInputRemoteDataSource {
  final ApiClient _client;
  FormInputRemoteDataSource(this._client);

  Future<Result<Failure, List<dynamic>>> getForm(String endpoint) {
    return _client.get<List<dynamic>>(
      endpoint,
      parser: (json) => json as List<dynamic>,
    );
  }
}

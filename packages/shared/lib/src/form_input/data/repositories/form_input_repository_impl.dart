import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/form_input_field.dart';
import '../../domain/repositories/form_input_repository.dart';
import '../datasources/form_input_remote_datasource.dart';
import '../models/form_input_field_model.dart';

@LazySingleton(as: FormInputRepository)
class FormInputRepositoryImpl implements FormInputRepository {
  final FormInputRemoteDataSource _remote;
  FormInputRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, List<FormInputField>>> getForm(String endpoint) async {
    final result = await _remote.getForm(endpoint);

    return result.fold(
      Err.new,
      (list) => Ok(
        list
            .map(
              (e) => FormInputFieldModel.fromJson(
                e as Map<String, dynamic>,
              ).toEntity(),
            )
            .toList(),
      ),
    );
  }
}

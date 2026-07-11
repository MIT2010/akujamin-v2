import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/form_input_field.dart';
import 'form_field_option_model.dart';

part 'form_input_field_model.freezed.dart';
part 'form_input_field_model.g.dart';

/// DTO for one entry of the schema array returned by endpoints like
/// `GET /tes/pertanyaan` / `GET /registrasi/profile` — a bare JSON array,
/// not wrapped in a `{status, data}` envelope. Confirmed by reading the
/// old app's `FormInputApiServiceImpl.getForms` (returns a raw decoded
/// list, no envelope) and `FormInputRepositoryImpl.getForms` (maps the
/// list directly, no `status` check anywhere) — unlike most other
/// endpoints in this codebase, which do wrap in an envelope.
@freezed
abstract class FormInputFieldModel with _$FormInputFieldModel {
  const FormInputFieldModel._();

  const factory FormInputFieldModel({
    required String label,
    required String display,
    required String type,
    required bool validate,
    @JsonKey(name: 'read_only') required bool readOnly,
    @JsonKey(name: 'value') List<FormFieldOptionModel>? options,
    @JsonKey(name: 'requirement') List<String>? requirements,
  }) = _FormInputFieldModel;

  factory FormInputFieldModel.fromJson(Map<String, dynamic> json) =>
      _$FormInputFieldModelFromJson(json);

  FormInputField toEntity() => FormInputField(
    label: label,
    display: display,
    type: type,
    validate: validate,
    readOnly: readOnly,
    options: options?.map((o) => o.toEntity()).toList(),
    requirements: requirements,
  );
}

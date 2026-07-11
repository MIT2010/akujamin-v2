import 'package:freezed_annotation/freezed_annotation.dart';

import 'form_field_option.dart';

part 'form_input_field.freezed.dart';

/// One field of a server-driven dynamic form schema (e.g. `GET
/// /tes/pertanyaan`, `GET /registrasi/profile`). `type` stays a plain
/// string rather than a closed enum — the old app itself only ever
/// compares it against `'date'`/`'select'`, treating anything else as
/// free text, so a closed enum here would invent an exhaustive list the
/// API never confirmed (docs/MIGRATION_PLAYBOOK.md §0).
@freezed
abstract class FormInputField with _$FormInputField {
  const FormInputField._();

  const factory FormInputField({
    required String label,
    required String display,
    required String type,
    required bool validate,
    required bool readOnly,
    List<FormFieldOption>? options,
    List<String>? requirements,
  }) = _FormInputField;

  bool get isDate => type == 'date';
  bool get isSelect => type == 'select';
}

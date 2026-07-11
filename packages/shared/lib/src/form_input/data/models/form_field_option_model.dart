import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/form_field_option.dart';

part 'form_field_option_model.freezed.dart';
part 'form_field_option_model.g.dart';

/// DTO for one entry of a form field's `value` array.
///
/// The API's own JSON keys are swapped relative to what they mean: the
/// display text is sent under the key `"value"`, and the code to submit
/// is sent under the key `"kode"` — confirmed by reading the old app's
/// `OptionModel.fromJson`
/// (`lib/src/features/form_input/data/models/option_model.dart`), not
/// guessed (docs/MIGRATION_PLAYBOOK.md §2a). [label]/[value] below are
/// named for what they *mean*, not for the raw JSON key they come from —
/// do not "fix" this mapping without re-reading that source first.
@freezed
abstract class FormFieldOptionModel with _$FormFieldOptionModel {
  const FormFieldOptionModel._();

  const factory FormFieldOptionModel({
    @JsonKey(name: 'value') required String label,
    @JsonKey(name: 'kode') required String value,
    @JsonKey(name: 'parent_id') List<String>? parentIds,
  }) = _FormFieldOptionModel;

  factory FormFieldOptionModel.fromJson(Map<String, dynamic> json) =>
      _$FormFieldOptionModelFromJson(json);

  FormFieldOption toEntity() =>
      FormFieldOption(label: label, value: value, parentIds: parentIds);
}

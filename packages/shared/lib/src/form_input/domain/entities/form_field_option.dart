import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_field_option.freezed.dart';

/// One selectable option inside a [FormInputField] of type `select`.
@freezed
abstract class FormFieldOption with _$FormFieldOption {
  const factory FormFieldOption({
    required String label,
    required String value,
    List<String>? parentIds,
  }) = _FormFieldOption;
}

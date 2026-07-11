import 'entities/form_field_option.dart';
import 'entities/form_input_field.dart';

/// Filters [field]'s options down to the ones valid given the current
/// [formResults] — the "cascading select" behavior (e.g. `kota` filtered
/// by a previously-chosen `provinsi`). Ported from the old app's
/// `changeValues()` (`lib/src/core/constants/reusable.dart`), same
/// behavior including the quirk that an unfilled parent means *all*
/// options show, not none.
///
/// This is a pure function with no notion of "who calls it again" — the
/// reactive part of cascading selects lives entirely in whichever Cubit
/// owns `formResults`: every `setInput()` re-emits state, the view
/// rebuilds, and this function is recomputed fresh for every field on
/// every rebuild. See MIGRATION_LOG.md's form_input section for the full
/// design rationale.
List<FormFieldOption>? filterCascadingOptions(
  FormInputField field,
  Map<String, String> formResults,
) {
  final originalOptions = field.options;
  if (originalOptions == null || originalOptions.isEmpty) return null;

  final requirements = field.requirements;
  if (requirements == null || requirements.isEmpty) return originalOptions;

  final activeRequirements = requirements.where(
    (req) => formResults[req] != null,
  );

  if (activeRequirements.isEmpty) return originalOptions;

  return originalOptions.where((option) {
    final parentIds = option.parentIds;
    if (parentIds == null || parentIds.isEmpty) return false;

    return activeRequirements.any(
      (req) => parentIds.contains(formResults[req]),
    );
  }).toList();
}

/// Removes stale dependent-field values from [formResults] after
/// [changedLabel]'s value changes — a deliberate correction, not a
/// faithful port (the old app never cleared these). Two independent
/// reasons this is mandatory, not cosmetic: (1) this feeds a real write
/// path (`createVoucher`), so a code that no longer belongs to the
/// currently-selected parent must never be submitted; (2) Flutter's
/// `DropdownButtonFormField` throws a hard `AssertionError` if handed a
/// `value` that isn't present in its `items` — proven directly against
/// the Flutter SDK, not assumed.
///
/// Applies iteratively: if clearing a field's value causes *its own*
/// dependents to go stale too, those get cleared as well, until nothing
/// further needs clearing. This generalizes to multi-level dependency
/// chains without assuming the schema is only ever one level deep —
/// nothing in the confirmed data proves chains go deeper than one hop,
/// but the rule ("a field whose parent changed loses its stale value")
/// is the same rule applied repeatedly, not new behavior.
Map<String, String> clearDependentFields(
  String changedLabel,
  List<FormInputField> forms,
  Map<String, String> formResults,
) {
  final updated = Map<String, String>.from(formResults);
  final worklist = [changedLabel];

  while (worklist.isNotEmpty) {
    final justChanged = worklist.removeLast();

    for (final field in forms) {
      final requirements = field.requirements;
      if (requirements == null || !requirements.contains(justChanged)) {
        continue;
      }

      if (updated.remove(field.label) != null) {
        worklist.add(field.label);
      }
    }
  }

  return updated;
}

import 'package:shared/shared.dart';

/// Matches an OCR-extracted `select`-type value against [field]'s real
/// options — explicit failure, not the old app's silent "pick the first
/// option" fallback (`RegisterStateCubit._normalizeInput`:
/// `firstWhere(..., orElse: () => form.values!.first)`), the same class of
/// bug `CameraGateway.initialize` was fixed for (never silently substitute
/// something the caller didn't ask for). Tries an exact value match first,
/// then a case-insensitive substring match on the label — same two-step
/// intent the old app had — but returns `null` instead of guessing when
/// neither matches, leaving the field unset for manual entry rather than
/// silently selecting the wrong province/city from OCR noise.
String? normalizeSelectValue(FormInputField field, String rawValue) {
  final options = field.options;
  if (options == null || options.isEmpty) return rawValue;

  for (final option in options) {
    if (option.value == rawValue) return option.value;
  }

  final lowerValue = rawValue.toLowerCase();
  for (final option in options) {
    if (option.label.toLowerCase().contains(lowerValue)) return option.value;
  }

  return null;
}

/// Indonesian e-KTP cards physically print the birth date as `DD-MM-YYYY`
/// — see docs/qa/register.md for the full evidence chain (a real
/// `tgl_lahir: "1986-02-18"` example in the team's own Postman collection
/// confirms the *submit* endpoint wants ISO; the old app's reversal
/// heuristic only firing when `DateTime.tryParse` rejects the raw value is
/// consistent with, but not direct proof of, OCR returning the physical
/// card's own DD-MM-YYYY format).
final _ddMmYyyy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$');

/// Old app's `_normalizeInput` blindly reversed *any* dash-separated
/// string `DateTime.tryParse` couldn't read
/// (`value.split('-').reversed.join('-')`) — correct for DD-MM-YYYY,
/// silently wrong for anything else shaped like it (a 2-digit year, a
/// non-date value that happens to contain dashes). This checks the shape
/// explicitly first, then confirms the reconstructed string is a real
/// calendar date (catches `32-13-2026`, which the regex alone wouldn't —
/// `DateTime`'s constructor rolls invalid month/day values over into the
/// next month/year instead of throwing, so the parsed fields are compared
/// back against the ones the regex captured rather than trusting
/// `DateTime.tryParse` to reject them on its own), returning `null` — not
/// a guess — otherwise.
String? normalizeDateValue(String rawValue) {
  if (DateTime.tryParse(rawValue) != null) return rawValue;

  final match = _ddMmYyyy.firstMatch(rawValue);
  if (match == null) return null;

  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);

  final parsed = DateTime.tryParse('$year-${match.group(2)}-${match.group(1)}');
  if (parsed == null ||
      parsed.year != year ||
      parsed.month != month ||
      parsed.day != day) {
    return null;
  }

  return '$year-${match.group(2)}-${match.group(1)}';
}

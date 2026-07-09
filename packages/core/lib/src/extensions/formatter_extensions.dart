extension DateFormatterX on DateTime {
  /// `2026-07-06`
  String get toYmd =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

extension NumFormatterX on num {
  /// `1234567` -> `1.234.567` (Indonesian thousands grouping).
  String get withThousandsSeparator => toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  /// `1234567` -> `Rp1.234.567`
  String get asCurrencyIdr => 'Rp$withThousandsSeparator';
}

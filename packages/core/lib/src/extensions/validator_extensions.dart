final _emailPattern = RegExp(r'^[\w.\-+]+@([\w-]+\.)+[\w-]{2,}$');

extension StringValidatorX on String {
  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => !isBlank;

  bool get isValidEmail => _emailPattern.hasMatch(this);

  /// At least 8 chars, one uppercase letter and one digit.
  bool get isStrongPassword =>
      length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(this) &&
      RegExp(r'[0-9]').hasMatch(this);
}

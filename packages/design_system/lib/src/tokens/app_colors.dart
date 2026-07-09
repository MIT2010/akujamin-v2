import 'package:flutter/material.dart';

/// Light-theme color tokens. Never hardcode a `Color(...)` in feature code —
/// go through these tokens so a rebrand is a one-file change (§16).
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF2D6CDF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
}

/// Dark-mode counterparts, selected by [AppTheme.dark].
class AppColorsDark {
  const AppColorsDark._();

  static const Color primary = Color(0xFF9AB6FF);
  static const Color surface = Color(0xFF121212);
  static const Color error = Color(0xFFEF9A9A);
}

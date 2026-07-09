import 'package:flutter/material.dart';

import '../../tokens/app_spacing.dart';

/// Wraps [ElevatedButton] with the design tokens applied and owns its own
/// loading-spinner-replaces-label behavior, so every screen gets consistent
/// loading UI for free instead of scattering
/// `if (state is Loading) CircularProgressIndicator()` (§16, §23).
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(label),
              ],
            ),
    );
  }
}

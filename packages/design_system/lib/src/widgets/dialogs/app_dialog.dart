import 'package:flutter/material.dart';

/// Wraps [AlertDialog] behind a single static helper so confirm dialogs
/// look identical everywhere in the app (§16). Per §9, form validation
/// errors are shown inline, never through this dialog.
class AppDialog {
  const AppDialog._();

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Single-button variant of [confirm] — nothing to confirm, just an
  /// acknowledgement. Added for a real need, not speculatively: a migrated
  /// feature can reach a genuinely not-yet-built destination (another
  /// feature not migrated yet) and needs to say so explicitly rather than
  /// silently doing nothing when tapped (docs/qa/history.md).
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String okLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }
}

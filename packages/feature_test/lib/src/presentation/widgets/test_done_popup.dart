import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Non-dismissible section/test-boundary popup — `PopScope(canPop: false)`,
/// same as the old app's `TestDonePopup`: the only way out is the button,
/// which resolves the sheet's future so `TestPage` can call
/// `TestCubit.closePopup()`.
class TestDonePopup extends StatelessWidget {
  const TestDonePopup({
    super.key,
    required this.sectionName,
    required this.isLast,
  });

  final String sectionName;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Tes selesai',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isLast
                  ? 'Kamu telah menyelesaikan seluruh tes dan semua jawaban '
                        'tersimpan dengan aman.\n\nLanjut untuk melihat ringkasan.'
                  : 'Kamu telah menyelesaikan $sectionName dan seluruh jawaban '
                        'tersimpan dengan aman.\n\nLanjut ke bagian berikutnya.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Lanjut',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

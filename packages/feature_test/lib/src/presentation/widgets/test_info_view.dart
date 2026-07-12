import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Shared rendering for a test's or section's intro/instruction screen —
/// confirmed by reading `test_info_container.dart` that this content
/// genuinely uses markdown (`CustomMarkdownWidget` in the old app), not
/// just question text (plain, unaffected) — MIGRATION_LOG.md's Langkah 3.
class TestInfoView extends StatelessWidget {
  const TestInfoView({
    super.key,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.onNext,
  });

  final String title;
  final String content;
  final String? imageUrl;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          if (imageUrl != null) ...[
            Center(child: Image.network(imageUrl!, width: 300)),
            const SizedBox(height: AppSpacing.md),
          ],
          AppMarkdownText(data: content),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(label: 'Lanjut', onPressed: onNext),
          ),
        ],
      ),
    );
  }
}

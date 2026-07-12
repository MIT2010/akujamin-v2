import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../tokens/app_typography.dart';

/// Renders CommonMark-syntax content (bold/italic/links/lists/headings/
/// blockquotes/code, etc. — the full syntax, not a restricted subset) with
/// this package's type-scale tokens. Designed fresh as a generic,
/// domain-agnostic primitive — not a copy of the old app's
/// `CustomMarkdownWidget` — for any feature whose server-driven content
/// happens to use markdown formatting (`about`'s FAQ, `test`'s intro/
/// instruction text).
///
/// Built on `markdown_widget`, not `flutter_markdown` — verified before
/// choosing, not assumed: `flutter_markdown` is discontinued (pub.dev
/// marks it explicitly, pointing at `flutter_markdown_plus` as the
/// community successor). `markdown_widget` is the package the old app
/// already used, and it's independently healthy (not discontinued, 411
/// likes, 160 pub points at the time of this check) — reusing a
/// proven-in-production choice over adopting an unproven successor
/// lineage, with no behavior-parity risk either way.
class AppMarkdownText extends StatelessWidget {
  const AppMarkdownText({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownWidget(
      data: data,
      shrinkWrap: true,
      config: MarkdownConfig(
        configs: [
          PConfig(textStyle: AppTypography.bodyMedium),
          H1Config(style: AppTypography.headlineLarge),
          H2Config(style: AppTypography.headlineMedium),
          H3Config(style: AppTypography.titleLarge),
          H4Config(style: AppTypography.bodyLarge),
          H5Config(style: AppTypography.bodyLarge),
          H6Config(style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

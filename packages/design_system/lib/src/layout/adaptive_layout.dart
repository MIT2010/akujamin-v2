import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Swaps between `mobile`/`tablet`/`desktop` builders based on
/// [Breakpoints] (§16). `tablet`/`desktop` fall back to the next-smallest
/// provided builder so callers only need to implement the layouts that
/// actually diverge.
class AdaptiveLayout extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const AdaptiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (Breakpoints.isDesktop(width)) {
      return (desktop ?? tablet ?? mobile)(context);
    }
    if (Breakpoints.isTablet(width)) {
      return (tablet ?? mobile)(context);
    }
    return mobile(context);
  }
}

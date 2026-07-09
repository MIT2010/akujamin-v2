import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness() {
    return const MaterialApp(
      home: AdaptiveLayout(
        mobile: _LabeledBox.mobile,
        tablet: _LabeledBox.tablet,
        desktop: _LabeledBox.desktop,
      ),
    );
  }

  testWidgets('renders the mobile builder on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());

    expect(find.text('mobile'), findsOneWidget);
  });

  testWidgets('renders the tablet builder on a medium viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());

    expect(find.text('tablet'), findsOneWidget);
  });

  testWidgets('renders the desktop builder on a wide viewport', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());

    expect(find.text('desktop'), findsOneWidget);
  });

  testWidgets('falls back to mobile when tablet/desktop are omitted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdaptiveLayout(mobile: _LabeledBox.mobile)),
    );

    expect(find.text('mobile'), findsOneWidget);
  });
}

class _LabeledBox extends StatelessWidget {
  final String label;

  const _LabeledBox(this.label);

  static Widget mobile(BuildContext context) => const _LabeledBox('mobile');
  static Widget tablet(BuildContext context) => const _LabeledBox('tablet');
  static Widget desktop(BuildContext context) => const _LabeledBox('desktop');

  @override
  Widget build(BuildContext context) => Text(label);
}

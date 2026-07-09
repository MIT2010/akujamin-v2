import 'dart:async';

import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoRouterRefreshStream', () {
    test('notifies listeners on every stream event', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      var notifications = 0;
      final refreshStream = GoRouterRefreshStream(controller.stream)
        ..addListener(() => notifications++);
      addTearDown(refreshStream.dispose);

      controller.add(1);
      controller.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 2);
    });

    test('stops notifying after dispose', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      var notifications = 0;
      final refreshStream = GoRouterRefreshStream(controller.stream)
        ..addListener(() => notifications++);

      refreshStream.dispose();
      controller.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 0);
    });
  });
}

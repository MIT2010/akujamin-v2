import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnauthenticatedAuthSession', () {
    test('reports unauthenticated status', () {
      final session = UnauthenticatedAuthSession();

      expect(session.status.isAuthenticated, isFalse);
      expect(session.status.roles, isEmpty);
    });

    test('statusStream emits the same unauthenticated status once', () async {
      final session = UnauthenticatedAuthSession();

      final emitted = await session.statusStream.toList();

      expect(emitted, [AuthSessionStatus.unauthenticated]);
    });
  });
}

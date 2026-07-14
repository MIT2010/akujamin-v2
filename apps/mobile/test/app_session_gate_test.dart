import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/app.dart';
import 'package:mobile/src/di/injection.dart';
import 'package:shared/shared.dart' show getIt;
import 'package:shared_preferences/shared_preferences.dart';

/// The unauthenticated (no cached session) boot path is already covered by
/// widget_test.dart in this same directory — not duplicated here.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => getIt.reset());

  testWidgets(
    'a returning authenticated user never sees the login form flash before '
    'landing on /home — real fix found during the reconciliation audit: '
    'AuthState.initial() used to be treated the same as unauthenticated, '
    'so the very first frame rendered /login for an already-logged-in '
    'user before the redirect caught up',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'com.akujamin.mobile.access_token': 'test-access-token',
        'com.akujamin.mobile.cached_user': jsonEncode({
          'id': '1',
          'email': 'a@example.com',
          'role': 'peserta',
          'isRegistered': true,
        }),
      });

      await configureDependencies(env: Env.current);

      await tester.pumpWidget(const App());

      // The critical assertion: the very first frame — before the cached
      // session has any chance to resolve — must never render the login
      // form. A loading indicator instead of a wrong, populated screen.
      expect(find.text('Login'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsOneWidget);
    },
  );
}

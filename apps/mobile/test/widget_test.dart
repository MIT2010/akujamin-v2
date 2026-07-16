import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/app.dart';
import 'package:mobile/src/di/injection.dart';
import 'package:shared/shared.dart' show getIt;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => getIt.reset());

  testWidgets(
    'boots straight into the login page for an unauthenticated, '
    'not-first-launch user',
    (tester) async {
      // `feature_onboarding`'s DI graph loads a real SharedPreferences
      // instance during `configureDependencies()` (§12's `@preResolve`).
      // shared_preferences ships its own officially-supported in-memory
      // test double for exactly this. Seeded as already-completed here —
      // real gap, found 2026-07-16 during the akujamin-app comparison
      // audit: AppRouter now replicates the old app's mandatory
      // first-launch onboarding gate (see app_router_test.dart), so an
      // empty/unseeded prefs map would redirect to /onboarding instead of
      // /login, which is not what *this* test is about — see the test
      // below for that case.
      SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
      // `AuthCubit`'s constructor reads `SecureTokenStorage.getCachedUser()`
      // — the real `FlutterSecureStorage` platform channel has no handler
      // under `flutter_test` and hangs forever rather than throwing. This
      // previously went unnoticed because `AppRouter`'s redirect logic
      // didn't actually wait for that read to resolve before deciding
      // `/login` — now that it correctly does (App's session-check gate,
      // found during the reconciliation audit), the read has to actually
      // complete. The plugin's own official in-memory backing (empty map —
      // no cached session) is what `secure_token_storage_test.dart`'s
      // real-storage group already uses.
      FlutterSecureStorage.setMockInitialValues({});

      await configureDependencies(env: Env.current);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    },
  );

  testWidgets(
    'boots straight into the onboarding carousel for a genuine first '
    'launch — real gap, found 2026-07-16 during the akujamin-app '
    'comparison audit: the old app forces this before a guest ever '
    'reaches /login on first launch; verified here at the real, fully '
    'DI-wired app-boot level, not just against a fake FirstLaunchGate',
    (tester) async {
      // Unseeded (no 'has_completed_onboarding' key) — the exact shape a
      // real first install's SharedPreferences store has.
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      await configureDependencies(env: Env.current);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
    },
  );
}

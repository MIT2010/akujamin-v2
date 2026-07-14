import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/app.dart';
import 'package:mobile/src/di/injection.dart';
import 'package:shared/shared.dart' show getIt;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // `feature_onboarding`'s DI graph loads a real SharedPreferences instance
  // during `configureDependencies()` (§12's `@preResolve`). shared_preferences
  // ships its own officially-supported in-memory test double for exactly
  // this — seed it before the real call happens.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => getIt.reset());

  testWidgets(
    'boots straight into the login page for an unauthenticated user',
    (tester) async {
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
}

import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:mobile/src/app.dart';
import 'package:mobile/src/di/injection.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared/shared.dart' show getIt;
import 'package:shared_preferences/shared_preferences.dart';

/// `feature_home`'s DI graph opens a real Hive box during
/// `configureDependencies()` (§12's `@preResolve`), which needs
/// `getApplicationDocumentsDirectory()`. The real `MethodChannelPathProvider`
/// has no handler wired up under `flutter_test` and just hangs forever
/// instead of throwing — swap in a fake that resolves synchronously to a
/// temp dir so `Hive.initFlutter()` can actually finish.
class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.createTempSync('feature_home_test_').path;
}

/// Opening the *real*, file-backed box also hangs under `flutter_test`
/// (Hive's native storage backend needs a file lock that this VM test
/// environment never resolves — confirmed by isolating `Hive.openBox`
/// down to just that call). Pre-opening an in-memory box (`bytes: ...`)
/// under the same name works around it: `Hive.openBox` short-circuits on
/// an already-open box by name, so `RegisterModule.homeItemsBox`'s later
/// call just gets this in-memory one back instead of touching a real file.
///
/// Deliberately does *not* call `Hive.registerAdapters()` here —
/// `RegisterModule.homeItemsBox` already does that once, for real, a few
/// lines later during `configureDependencies()`. Registering the same
/// adapter twice throws (`HiveError: There is already a TypeAdapter for
/// typeId ...`), and an empty box doesn't need a decoder to open anyway.
Future<void> _preOpenInMemoryHomeItemsBox() async {
  await Hive.openBox<HomeItemModel>('home_items', bytes: Uint8List(0));
}

void main() {
  setUpAll(() => PathProviderPlatform.instance = _FakePathProviderPlatform());
  // `feature_onboarding`'s DI graph loads a real SharedPreferences instance
  // during `configureDependencies()` (§12's `@preResolve`, same pattern as
  // `feature_home`'s Hive box above). Unlike Hive/path_provider,
  // shared_preferences ships its own officially-supported in-memory test
  // double for exactly this — no fake platform class needed, just seed it
  // before the real call happens.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => getIt.reset());

  testWidgets(
    'boots straight into the login page for an unauthenticated user',
    (tester) async {
      await _preOpenInMemoryHomeItemsBox();
      await configureDependencies(env: Env.current);

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    },
  );
}

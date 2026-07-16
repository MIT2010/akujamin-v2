import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingLocalDataSource extends Mock
    implements OnboardingLocalDataSource {}

void main() {
  late _MockOnboardingLocalDataSource local;
  late FirstLaunchGateAdapter adapter;

  setUp(() {
    local = _MockOnboardingLocalDataSource();
    adapter = FirstLaunchGateAdapter(local);
  });

  group('FirstLaunchGateAdapter.isFirstLaunch', () {
    test('reads straight through to OnboardingLocalDataSource -- the bridge '
        'AppRouter uses so it never depends on feature_onboarding directly, '
        'same mechanism as AuthSessionAdapter for AuthSession', () {
      when(() => local.getIsFirstLaunch()).thenReturn(true);

      expect(adapter.isFirstLaunch, isTrue);
    });

    test('reflects false once the flag has been cleared', () {
      when(() => local.getIsFirstLaunch()).thenReturn(false);

      expect(adapter.isFirstLaunch, isFalse);
    });
  });
}

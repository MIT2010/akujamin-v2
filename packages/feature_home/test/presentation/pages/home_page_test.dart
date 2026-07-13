import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeCubit extends MockCubit<HomeState> implements HomeCubit {}

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockHomeCubit homeCubit;
  late _MockAuthCubit authCubit;

  Widget harness() {
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => BlocProvider<HomeCubit>.value(
                value: homeCubit,
                child: const HomeView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    homeCubit = _MockHomeCubit();
    authCubit = _MockAuthCubit();
    when(() => homeCubit.state).thenReturn(const HomeState.loaded([]));
    when(() => authCubit.state).thenReturn(const AuthState.unauthenticated());
  });

  group('HomeView AppBar — Riwayat/Akun no longer live here (TAHAP 3, '
      'MIGRATION_LOG.md dashboard-shell finding): apps/mobile\'s bottom-nav '
      'shell reaches /history and /profile now, so these AppBar icons would '
      'be a live duplicate of the shell tabs', () {
    testWidgets('the history and person icons are gone from the AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(harness());

      expect(find.byIcon(Icons.history), findsNothing);
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets(
      'the remaining AppBar actions (onboarding/FAQ/counseling/payment/'
      'logout) are still there — the removal was scoped to exactly the '
      'two duplicated icons, not the whole AppBar',
      (tester) async {
        await tester.pumpWidget(harness());

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
        expect(find.byIcon(Icons.payment_outlined), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      },
    );
  });
}

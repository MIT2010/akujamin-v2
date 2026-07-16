import 'package:authentication/src/domain/entities/user.dart';
import 'package:authentication/src/presentation/cubit/otp_login_cubit.dart';
import 'package:authentication/src/presentation/cubit/otp_login_state.dart';
import 'package:authentication/src/presentation/pages/otp_login_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockOtpLoginCubit extends MockCubit<OtpLoginState>
    implements OtpLoginCubit {}

void main() {
  late _MockOtpLoginCubit cubit;

  final expiresAt = DateTime.parse('2026-07-10T12:00:00.000Z');

  Widget harness(_MockOtpLoginCubit cubit) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => BlocProvider<OtpLoginCubit>.value(
              value: cubit,
              child: const OtpLoginView(),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('home-page')),
          ),
        ],
      ),
    );
  }

  setUp(() {
    cubit = _MockOtpLoginCubit();
    when(() => cubit.state).thenReturn(const OtpLoginState.phoneEntry());
    when(() => cubit.sendOtp(any())).thenAnswer((_) async {});
    when(() => cubit.resendOtp(any())).thenAnswer((_) async {});
    when(
      () => cubit.verifyOtp(
        phoneNumber: any(named: 'phoneNumber'),
        otpCode: any(named: 'otpCode'),
        expiresAt: any(named: 'expiresAt'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('shows the phone entry form initially', (tester) async {
    whenListen(
      cubit,
      const Stream<OtpLoginState>.empty(),
      initialState: const OtpLoginState.phoneEntry(),
    );

    await tester.pumpWidget(harness(cubit));

    expect(find.text('Nomor telepon'), findsOneWidget);
    expect(find.text('Kirim OTP'), findsOneWidget);
  });

  testWidgets('tapping "Kirim OTP" sends the entered phone number', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<OtpLoginState>.empty(),
      initialState: const OtpLoginState.phoneEntry(),
    );

    await tester.pumpWidget(harness(cubit));
    await tester.enterText(find.byType(TextField), '81234567890');
    await tester.tap(find.text('Kirim OTP'));

    verify(() => cubit.sendOtp('81234567890')).called(1);
  });

  testWidgets('shows the OTP entry form once otpEntry is reached', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<OtpLoginState>.empty(),
      initialState: OtpLoginState.otpEntry(
        phoneNumber: '81234567890',
        expiresAt: expiresAt,
      ),
    );

    await tester.pumpWidget(harness(cubit));

    expect(find.text('Kode OTP dikirim ke 81234567890'), findsOneWidget);
    expect(find.text('Verifikasi'), findsOneWidget);
  });

  testWidgets('tapping "Verifikasi" submits the entered OTP code', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<OtpLoginState>.empty(),
      initialState: OtpLoginState.otpEntry(
        phoneNumber: '81234567890',
        expiresAt: expiresAt,
      ),
    );

    await tester.pumpWidget(harness(cubit));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verifikasi'));

    verify(
      () => cubit.verifyOtp(
        phoneNumber: '81234567890',
        otpCode: '123456',
        expiresAt: expiresAt,
      ),
    ).called(1);
  });

  testWidgets('navigates to /home when the cubit emits success', (
    tester,
  ) async {
    const user = User(id: '1', email: 'a@example.com', role: 'admin');
    whenListen(
      cubit,
      Stream.fromIterable([OtpLoginState.success(user)]),
      initialState: const OtpLoginState.phoneEntry(),
    );

    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets(
    'the resend button is disabled and shows a countdown before expiry',
    (tester) async {
      final futureExpiry = DateTime.now().add(const Duration(minutes: 2));
      whenListen(
        cubit,
        const Stream<OtpLoginState>.empty(),
        initialState: OtpLoginState.otpEntry(
          phoneNumber: '81234567890',
          expiresAt: futureExpiry,
        ),
      );

      await tester.pumpWidget(harness(cubit));

      expect(find.text('Kirim Ulang'), findsNothing);
      expect(find.textContaining('Kirim ulang dalam'), findsOneWidget);
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.onPressed, isNull);

      // Dispose the widget tree so _ResendCountdown's Timer.periodic is
      // cancelled -- otherwise the test fails with a pending-timer error
      // since this countdown never reaches expiry on its own here.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tapping "Kirim Ulang" once expired calls OtpLoginCubit.resendOtp -- '
    'real gap, found 2026-07-16 during the akujamin-app comparison audit: '
    'this button had no counterpart at all until now',
    (tester) async {
      final pastExpiry = DateTime.now().subtract(const Duration(seconds: 1));
      whenListen(
        cubit,
        const Stream<OtpLoginState>.empty(),
        initialState: OtpLoginState.otpEntry(
          phoneNumber: '81234567890',
          expiresAt: pastExpiry,
        ),
      );

      await tester.pumpWidget(harness(cubit));

      expect(find.text('Kirim Ulang'), findsOneWidget);
      await tester.tap(find.text('Kirim Ulang'));

      verify(() => cubit.resendOtp('81234567890')).called(1);
    },
  );

  testWidgets('shows the failure message when verifyOtp fails', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable([
        OtpLoginState.verifyOtpFailure(
          failure: const UnauthorizedFailure(),
          phoneNumber: '81234567890',
          expiresAt: expiresAt,
        ),
      ]),
      initialState: OtpLoginState.otpEntry(
        phoneNumber: '81234567890',
        expiresAt: expiresAt,
      ),
    );

    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Session expired'), findsOneWidget);
  });
}

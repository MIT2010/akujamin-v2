import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockRegisterCubit extends MockCubit<RegisterState>
    implements RegisterCubit {}

class _MockSelfieCameraCubit extends MockCubit<SelfieCameraState>
    implements SelfieCameraCubit {}

class _MockCameraGateway extends Mock implements CameraGateway {}

void main() {
  late _MockRegisterCubit registerCubit;
  late _MockSelfieCameraCubit selfieCameraCubit;
  late _MockCameraGateway cameraGateway;

  const nikField = FormInputField(
    label: 'nik',
    display: 'NIK',
    type: 'text',
    validate: true,
    readOnly: false,
  );

  Widget harness() {
    return MaterialApp(
      home: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (context) => MultiBlocProvider(
                        providers: [
                          BlocProvider<SelfieCameraCubit>.value(
                            value: selfieCameraCubit,
                          ),
                          BlocProvider<RegisterCubit>.value(
                            value: registerCubit,
                          ),
                        ],
                        child: const RegisterView(),
                      ),
                    ),
                  );
                },
                child: const Text('open-register'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    registerCubit = _MockRegisterCubit();
    selfieCameraCubit = _MockSelfieCameraCubit();
    cameraGateway = _MockCameraGateway();
    when(() => cameraGateway.controller).thenReturn(null);
    when(() => selfieCameraCubit.gateway).thenReturn(cameraGateway);
    when(() => selfieCameraCubit.state).thenReturn(const SelfieCameraState());
    when(
      () => selfieCameraCubit.stream,
    ).thenAnswer((_) => const Stream<SelfieCameraState>.empty());
    when(() => selfieCameraCubit.takePhoto()).thenAnswer((_) async {});
  });

  // Bounded pumps, not `pumpAndSettle` — the `loadingForm`/`submitting`
  // statuses render an indeterminate `CircularProgressIndicator`/
  // `LinearProgressIndicator`, whose animation never settles and would
  // make `pumpAndSettle` hang until it times out.
  Future<void> openRegister(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open-register'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('takingSelfie status shows the selfie capture screen', (
    tester,
  ) async {
    when(() => registerCubit.state).thenReturn(const RegisterState());
    when(
      () => registerCubit.stream,
    ).thenAnswer((_) => const Stream<RegisterState>.empty());

    await openRegister(tester);

    expect(find.text('Selfie'), findsOneWidget);
    expect(find.byIcon(Icons.camera), findsOneWidget);
  });

  testWidgets('tapping the camera button calls SelfieCameraCubit.takePhoto', (
    tester,
  ) async {
    when(() => registerCubit.state).thenReturn(const RegisterState());
    when(
      () => registerCubit.stream,
    ).thenAnswer((_) => const Stream<RegisterState>.empty());

    await openRegister(tester);
    await tester.tap(find.byIcon(Icons.camera));

    verify(() => selfieCameraCubit.takePhoto()).called(1);
  });

  testWidgets('loadingForm status shows a spinner', (tester) async {
    when(
      () => registerCubit.state,
    ).thenReturn(const RegisterState(status: RegisterStatus.loadingForm));
    when(
      () => registerCubit.stream,
    ).thenAnswer((_) => const Stream<RegisterState>.empty());

    await openRegister(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'inputForm status renders the dynamic form fields and a scan button',
    (tester) async {
      when(() => registerCubit.state).thenReturn(
        const RegisterState(
          status: RegisterStatus.inputForm,
          forms: [nikField],
        ),
      );
      when(
        () => registerCubit.stream,
      ).thenAnswer((_) => const Stream<RegisterState>.empty());

      await openRegister(tester);

      expect(find.text('NIK'), findsOneWidget);
      expect(find.text('Ekstrak data KTP'), findsOneWidget);
      expect(find.text('Lanjutkan'), findsOneWidget);
    },
  );

  testWidgets('tapping Lanjutkan on the form calls RegisterCubit.submit', (
    tester,
  ) async {
    when(() => registerCubit.state).thenReturn(
      const RegisterState(status: RegisterStatus.inputForm, forms: [nikField]),
    );
    when(
      () => registerCubit.stream,
    ).thenAnswer((_) => const Stream<RegisterState>.empty());
    when(() => registerCubit.submit()).thenAnswer((_) async {});

    await openRegister(tester);
    await tester.tap(find.text('Lanjutkan'));

    verify(() => registerCubit.submit()).called(1);
  });

  testWidgets('submitting status shows the sending message', (tester) async {
    when(
      () => registerCubit.state,
    ).thenReturn(const RegisterState(status: RegisterStatus.submitting));
    when(
      () => registerCubit.stream,
    ).thenAnswer((_) => const Stream<RegisterState>.empty());

    await openRegister(tester);

    expect(find.text('Mengirim...'), findsOneWidget);
  });

  testWidgets('failed status shows the failure message', (tester) async {
    when(() => registerCubit.state).thenReturn(
      const RegisterState(
        status: RegisterStatus.failed,
        error: ValidationFailure('NIK masih kosong.'),
      ),
    );
    when(
      () => registerCubit.stream,
    ).thenAnswer((_) => const Stream<RegisterState>.empty());

    await openRegister(tester);

    expect(find.text('NIK masih kosong.'), findsOneWidget);
  });

  testWidgets('a success status pops the page with true', (tester) async {
    whenListen(
      registerCubit,
      Stream.fromIterable([
        const RegisterState(status: RegisterStatus.success),
      ]),
      initialState: const RegisterState(status: RegisterStatus.submitting),
    );

    await openRegister(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('open-register'), findsOneWidget);
  });
}

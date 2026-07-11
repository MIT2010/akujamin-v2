import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_history/feature_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCertificateCubit extends MockCubit<CertificateState>
    implements CertificateCubit {}

/// Only covers Initial/Loading/Error: `CertificateLoaded` builds a real
/// `PdfController`/`PdfView`, which talks to `pdfx`'s native platform
/// channel — unavailable under `flutter_test` (no plugin bindings
/// registered), so it isn't something a widget test can safely exercise.
/// That path is verified via real-app manual QA instead (docs/qa/history.md).
void main() {
  late _MockCertificateCubit certificateCubit;

  Widget harness(_MockCertificateCubit certificateCubit) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/certificate?url=https://example.com/cert.pdf',
        routes: [
          GoRoute(
            path: '/certificate',
            builder: (context, state) => BlocProvider<CertificateCubit>.value(
              value: certificateCubit,
              child: const CertificateView(),
            ),
          ),
        ],
      ),
    );
  }

  setUp(() {
    certificateCubit = _MockCertificateCubit();
  });

  testWidgets('shows a spinner while loading', (tester) async {
    when(
      () => certificateCubit.state,
    ).thenReturn(const CertificateState.loading());

    await tester.pumpWidget(harness(certificateCubit));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error message and a retry button', (tester) async {
    when(() => certificateCubit.state).thenReturn(
      const CertificateState.error(
        ServerFailure('Gagal memuat sertifikat', statusCode: 500),
      ),
    );
    when(() => certificateCubit.load(any())).thenAnswer((_) async {});

    await tester.pumpWidget(harness(certificateCubit));

    expect(find.text('Gagal memuat sertifikat'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));

    verify(
      () => certificateCubit.load('https://example.com/cert.pdf'),
    ).called(1);
  });
}

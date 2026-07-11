import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_history/feature_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCertificateRepository extends Mock
    implements CertificateRepository {}

void main() {
  late _MockCertificateRepository repository;

  final bytes = Uint8List.fromList([1, 2, 3]);
  const url = 'https://example.com/cert.pdf';

  setUp(() {
    repository = _MockCertificateRepository();
  });

  group('CertificateCubit.load', () {
    blocTest<CertificateCubit, CertificateState>(
      'given the repository resolves the PDF bytes',
      setUp: () {
        when(() => repository.download(url)).thenAnswer((_) async => Ok(bytes));
      },
      build: () => CertificateCubit(repository),
      act: (cubit) => cubit.load(url),
      expect: () => [
        const CertificateState.loading(),
        CertificateState.loaded(bytes),
      ],
    );

    blocTest<CertificateCubit, CertificateState>(
      'given the repository fails',
      setUp: () {
        when(
          () => repository.download(url),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
      },
      build: () => CertificateCubit(repository),
      act: (cubit) => cubit.load(url),
      expect: () => [
        const CertificateState.loading(),
        const CertificateState.error(NetworkFailure()),
      ],
    );
  });
}

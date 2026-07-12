import 'package:feature_payment/feature_payment.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage storage;
  late PaymentLocalDataSource dataSource;

  setUp(() {
    storage = _MockFlutterSecureStorage();
    dataSource = PaymentLocalDataSource(storage);
  });

  group('PaymentLocalDataSource', () {
    test('fixes the ADR-011-class vulnerability: reads/writes/deletes use a '
        'prefixed key, never the old app\'s bare "psychologist" key — proven '
        'directly against the mocked storage call, not just described in a '
        'comment', () async {
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => 'conf.27');
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await dataSource.getPsychologistId();
      await dataSource.savePsychologistId('conf.27');
      await dataSource.clearPsychologistId();

      final captured = verify(
        () => storage.read(key: captureAny(named: 'key')),
      ).captured;
      expect(captured.single, isNot('psychologist'));
      expect(captured.single, startsWith('com.akujamin.mobile.'));

      verify(
        () => storage.write(
          key: 'com.akujamin.mobile.payment_psychologist_id',
          value: 'conf.27',
        ),
      ).called(1);
      verify(
        () =>
            storage.delete(key: 'com.akujamin.mobile.payment_psychologist_id'),
      ).called(1);
    });
  });
}

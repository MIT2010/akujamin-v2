import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceMatchResultModel.fromJson', () {
    test("maps match: true to FaceMatchStatus.matched, carries similarity "
        'through as confidence', () {
      final result = FaceMatchResultModel.fromJson({
        'match': true,
        'similarity': 0.92,
      });

      expect(result.status, FaceMatchStatus.matched);
      expect(result.confidence, 0.92);
    });

    test('maps match: false to FaceMatchStatus.notMatched', () {
      final result = FaceMatchResultModel.fromJson({
        'match': false,
        'similarity': 0.31,
      });

      expect(result.status, FaceMatchStatus.notMatched);
    });

    test('confidence is null when similarity is absent', () {
      final result = FaceMatchResultModel.fromJson({'match': true});

      expect(result.confidence, isNull);
    });
  });
}

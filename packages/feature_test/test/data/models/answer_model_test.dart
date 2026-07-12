import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnswerModel.fromJson', () {
    test('maps jawaban_id/jawaban into answerId/answer', () {
      final model = AnswerModel.fromJson({
        'jawaban_id': 'A1',
        'jawaban': 'Setuju',
      });

      expect(model.answerId, 'A1');
      expect(model.answer, 'Setuju');
    });

    test('normalizes a numeric jawaban_id to a String — unverified against '
        'live traffic either way, so this is defensive, not assumed', () {
      final model = AnswerModel.fromJson({'jawaban_id': 42, 'jawaban': 'Ya'});

      expect(model.answerId, '42');
    });
  });

  test('toEntity carries both fields through unchanged', () {
    const model = AnswerModel(answerId: 'A1', answer: 'Setuju');

    final entity = model.toEntity();

    expect(entity.answerId, 'A1');
    expect(entity.answer, 'Setuju');
  });
}

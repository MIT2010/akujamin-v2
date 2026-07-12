import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SubItemModel.fromJson takes text from the map key, not a JSON field',
    () {
      final model = SubItemModel.fromJson('Pernyataan 1', {
        'sub_id': 'S1',
        'jawaban': [
          {'jawaban_id': 'A1', 'jawaban': 'Setuju'},
        ],
      });

      expect(model.text, 'Pernyataan 1');
      expect(model.subId, 'S1');
      expect(model.answers, hasLength(1));
      expect(model.answers.first.answerId, 'A1');
    },
  );

  test(
    'SubItemModel.fromJson defaults to no answers when jawaban is missing',
    () {
      final model = SubItemModel.fromJson('x', {'sub_id': 'S1'});

      expect(model.answers, isEmpty);
    },
  );

  test('toEntity carries the sub-item through unchanged', () {
    const model = SubItemModel(
      subId: 'S1',
      text: 'Pernyataan 1',
      answers: [AnswerModel(answerId: 'A1', answer: 'Setuju')],
    );

    final entity = model.toEntity();

    expect(entity.subId, 'S1');
    expect(entity.text, 'Pernyataan 1');
    expect(entity.answers.single.answerId, 'A1');
  });
}

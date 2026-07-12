import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuestionModel.fromJson', () {
    test('maps a plain question with jawaban', () {
      final model = QuestionModel.fromJson('Apakah kamu setuju?', {
        'qid': 'Q1',
        'show_question': true,
        'is_multiple': 0,
        'jawaban': [
          {'jawaban_id': 'A1', 'jawaban': 'Setuju'},
          {'jawaban_id': 'A2', 'jawaban': 'Tidak setuju'},
        ],
      }, TestType.pengetahuan);

      expect(model.text, 'Apakah kamu setuju?');
      expect(model.id, 'Q1');
      expect(model.testType, TestType.pengetahuan);
      expect(model.showQuestion, isTrue);
      expect(model.isMultiple, isFalse);
      expect(model.answers, hasLength(2));
      expect(model.subItems, isNull);
    });

    test('falls back to id when qid is absent', () {
      final model = QuestionModel.fromJson('x', {
        'id': 'Q2',
      }, TestType.psikologi);

      expect(model.id, 'Q2');
    });

    test('is_multiple: 1 maps to isMultiple true', () {
      final model = QuestionModel.fromJson('x', {
        'is_multiple': 1,
      }, TestType.psikologi);

      expect(model.isMultiple, isTrue);
    });

    test('show_question defaults to true when absent', () {
      final model = QuestionModel.fromJson('x', {}, TestType.psikologi);

      expect(model.showQuestion, isTrue);
    });

    test('parses sub_items keyed by sub_id, text taken from the map key', () {
      final model = QuestionModel.fromJson('x', {
        'sub_items': {
          'Pernyataan 1': {
            'sub_id': 'S1',
            'jawaban': [
              {'jawaban_id': 'A1', 'jawaban': 'Ya'},
            ],
          },
          'Pernyataan 2': {
            'sub_id': 'S2',
            'jawaban': [
              {'jawaban_id': 'A2', 'jawaban': 'Ya'},
            ],
          },
        },
      }, TestType.psikologi);

      expect(model.subItems, hasLength(2));
      expect(model.subItems!.map((s) => s.subId), containsAll(['S1', 'S2']));
    });

    test('approved fix: sub_items serialized as an empty list ([]) instead of '
        'an empty object ({}) — the old app\'s own Laravel/PHP empty-array '
        'quirk, already guarded for soal but not for sub_items — no longer '
        'crashes with a List-cast-to-Map TypeError, resolves to no sub-items '
        'instead', () {
      final model = QuestionModel.fromJson('x', {
        'sub_items': <dynamic>[],
      }, TestType.psikologi);

      expect(model.subItems, isNull);
    });

    test('sub_items entirely absent also resolves to no sub-items', () {
      final model = QuestionModel.fromJson('x', {}, TestType.psikologi);

      expect(model.subItems, isNull);
    });
  });

  test('toEntity carries every field through unchanged', () {
    const model = QuestionModel(
      text: 'Soal',
      testType: TestType.pengetahuan,
      showQuestion: true,
      id: 'Q1',
      intro: 'Intro',
      mediaType: 'audio',
      mediaUrl: 'https://example.com/a.mp3',
      isMultiple: true,
      answers: [AnswerModel(answerId: 'A1', answer: 'Ya')],
      subItems: [
        SubItemModel(
          subId: 'S1',
          text: 'Sub',
          answers: [AnswerModel(answerId: 'A1', answer: 'Ya')],
        ),
      ],
    );

    final entity = model.toEntity();

    expect(entity.text, 'Soal');
    expect(entity.testType, TestType.pengetahuan);
    expect(entity.id, 'Q1');
    expect(entity.mediaType, 'audio');
    expect(entity.isMultiple, isTrue);
    expect(entity.answers, hasLength(1));
    expect(entity.subItems, hasLength(1));
  });
}

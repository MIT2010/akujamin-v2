import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SectionModel.fromJson', () {
    test('parses soal keyed by question text', () {
      final model = SectionModel.fromJson('Bab 1', {
        'soal': {
          'Apakah kamu setuju?': {'qid': 'Q1'},
        },
        'intro': {'deskripsi': 'Pengantar'},
        'instruksi': 'Baca dengan seksama',
      }, TestType.pengetahuan);

      expect(model.name, 'Bab 1');
      expect(model.questions, hasLength(1));
      expect(model.questions.first.text, 'Apakah kamu setuju?');
      expect(model.intro?.description, 'Pengantar');
      expect(model.instructions, 'Baca dengan seksama');
    });

    test('an empty soal serialized as [] instead of {} resolves to no '
        'questions instead of crashing — same guard the old app already had '
        'for this exact field, applied uniformly here', () {
      final model = SectionModel.fromJson('Bab 1', {
        'soal': <dynamic>[],
      }, TestType.pengetahuan);

      expect(model.questions, isEmpty);
    });

    test('intro/instructions are null when absent', () {
      final model = SectionModel.fromJson('Bab 1', {
        'soal': <String, dynamic>{},
      }, TestType.pengetahuan);

      expect(model.intro, isNull);
      expect(model.instructions, isNull);
    });
  });

  test('toEntity carries every field through unchanged', () {
    const model = SectionModel(
      name: 'Bab 1',
      questions: [
        QuestionModel(
          text: 'Soal',
          testType: TestType.pengetahuan,
          showQuestion: true,
        ),
      ],
      intro: IntroModel(description: 'Pengantar'),
      instructions: 'Baca',
    );

    final entity = model.toEntity();

    expect(entity.name, 'Bab 1');
    expect(entity.questions, hasLength(1));
    expect(entity.intro?.description, 'Pengantar');
    expect(entity.instructions, 'Baca');
  });
}

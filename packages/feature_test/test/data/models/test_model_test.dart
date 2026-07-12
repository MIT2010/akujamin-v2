import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TestModel.fromJson', () {
    test('a name containing "Pengetahuan" is type pengetahuan', () {
      final model = TestModel.fromJson('Tes Pengetahuan Umum', {
        'bab': <String, dynamic>{},
      });

      expect(model.type, TestType.pengetahuan);
    });

    test('any other name is type psikologi', () {
      final model = TestModel.fromJson('Tes Kepribadian', {
        'bab': <String, dynamic>{},
      });

      expect(model.type, TestType.psikologi);
    });

    test('parses bab keyed by section name', () {
      final model = TestModel.fromJson('Tes Kepribadian', {
        'bab': {
          'Bab 1': {'soal': <String, dynamic>{}},
        },
      });

      expect(model.sections, hasLength(1));
      expect(model.sections.first.name, 'Bab 1');
    });

    test('an empty bab serialized as [] instead of {} resolves to no '
        'sections instead of crashing — the old app never guarded this field '
        'at all (only soal), applied here for consistency', () {
      final model = TestModel.fromJson('Tes Kepribadian', {'bab': <dynamic>[]});

      expect(model.sections, isEmpty);
    });
  });

  test('toEntity carries every field through unchanged', () {
    const model = TestModel(
      name: 'Tes Kepribadian',
      type: TestType.psikologi,
      sections: [SectionModel(name: 'Bab 1', questions: [])],
      intro: IntroModel(description: 'x'),
      instructions: 'y',
    );

    final entity = model.toEntity();

    expect(entity.name, 'Tes Kepribadian');
    expect(entity.type, TestType.psikologi);
    expect(entity.sections, hasLength(1));
    expect(entity.intro?.description, 'x');
    expect(entity.instructions, 'y');
  });
}

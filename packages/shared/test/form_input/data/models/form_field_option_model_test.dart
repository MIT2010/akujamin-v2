import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('FormFieldOptionModel.fromJson', () {
    test('reads the API\'s "value" key as the display label and its "kode" '
        'key as the submit value — the API names these the opposite of '
        'what they mean, confirmed against the old app\'s OptionModel, not '
        'guessed', () {
      final model = FormFieldOptionModel.fromJson({
        'value': 'Jawa Barat',
        'kode': '32',
      });

      expect(model.label, 'Jawa Barat');
      expect(model.value, '32');
    });

    test('maps parent_id into parentIds for cascading options', () {
      final model = FormFieldOptionModel.fromJson({
        'value': 'Bandung',
        'kode': '3273',
        'parent_id': ['32'],
      });

      expect(model.parentIds, ['32']);
    });

    test('parentIds is null when parent_id is absent (top-level option)', () {
      final model = FormFieldOptionModel.fromJson({
        'value': 'Jawa Barat',
        'kode': '32',
      });

      expect(model.parentIds, isNull);
    });

    test('toEntity carries the resolved fields over as-is', () {
      final entity = FormFieldOptionModel.fromJson({
        'value': 'Bandung',
        'kode': '3273',
        'parent_id': ['32'],
      }).toEntity();

      expect(entity.label, 'Bandung');
      expect(entity.value, '3273');
      expect(entity.parentIds, ['32']);
    });
  });
}

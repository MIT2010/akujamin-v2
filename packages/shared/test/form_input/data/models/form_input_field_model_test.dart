import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('FormInputFieldModel.fromJson', () {
    test('parses a date field with no options/requirements', () {
      final model = FormInputFieldModel.fromJson({
        'label': 'tgl_lahir',
        'display': 'Tanggal Lahir',
        'type': 'date',
        'validate': true,
        'read_only': false,
      });

      expect(model.label, 'tgl_lahir');
      expect(model.display, 'Tanggal Lahir');
      expect(model.type, 'date');
      expect(model.validate, isTrue);
      expect(model.readOnly, isFalse);
      expect(model.options, isNull);
      expect(model.requirements, isNull);
    });

    test('parses a select field, mapping "value" (array) into options and '
        '"requirement" (array) into requirements', () {
      final model = FormInputFieldModel.fromJson({
        'label': 'kota',
        'display': 'Kota',
        'type': 'select',
        'validate': true,
        'read_only': false,
        'requirement': ['provinsi'],
        'value': [
          {
            'value': 'Bandung',
            'kode': '3273',
            'parent_id': ['32'],
          },
          {
            'value': 'Surabaya',
            'kode': '3578',
            'parent_id': ['35'],
          },
        ],
      });

      expect(model.requirements, ['provinsi']);
      expect(model.options, hasLength(2));
      expect(model.options!.first.label, 'Bandung');
      expect(model.options!.first.value, '3273');
    });

    test('read_only true is preserved on a plain text field', () {
      final model = FormInputFieldModel.fromJson({
        'label': 'jenis_tes',
        'display': 'Jenis Tes',
        'type': 'text',
        'validate': false,
        'read_only': true,
      });

      expect(model.readOnly, isTrue);
    });

    test('toEntity maps every field through to the domain entity', () {
      final entity = FormInputFieldModel.fromJson({
        'label': 'provinsi',
        'display': 'Provinsi',
        'type': 'select',
        'validate': true,
        'read_only': false,
        'value': [
          {'value': 'Jawa Barat', 'kode': '32'},
        ],
      }).toEntity();

      expect(entity.label, 'provinsi');
      expect(entity.isSelect, isTrue);
      expect(entity.isDate, isFalse);
      expect(entity.options!.single.label, 'Jawa Barat');
      expect(entity.options!.single.value, '32');
    });
  });
}

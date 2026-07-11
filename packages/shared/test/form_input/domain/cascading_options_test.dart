import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

/// provinsi -> kota, the exact example walked through with the user
/// before this was built: `kota`'s options carry `parentIds` pointing at
/// `provinsi`'s option values, and `kota.requirements` names `provinsi`.
FormInputField _provinsiField() => const FormInputField(
  label: 'provinsi',
  display: 'Provinsi',
  type: 'select',
  validate: true,
  readOnly: false,
  options: [
    FormFieldOption(label: 'Jawa Barat', value: '32'),
    FormFieldOption(label: 'Jawa Timur', value: '35'),
  ],
);

FormInputField _kotaField() => const FormInputField(
  label: 'kota',
  display: 'Kota',
  type: 'select',
  validate: true,
  readOnly: false,
  requirements: ['provinsi'],
  options: [
    FormFieldOption(label: 'Bandung', value: '3273', parentIds: ['32']),
    FormFieldOption(label: 'Surabaya', value: '3578', parentIds: ['35']),
  ],
);

void main() {
  group('filterCascadingOptions', () {
    test('returns all options unfiltered when the parent has not been set yet '
        '(matches the old app: kota is pickable before provinsi)', () {
      final result = filterCascadingOptions(_kotaField(), {});

      expect(result, hasLength(2));
    });

    test('is genuinely reactive: the same field, called again with a '
        'different formResults, produces a different filtered result — not '
        'just a static single-call assertion', () {
      final field = _kotaField();

      final beforeProvinsiChosen = filterCascadingOptions(field, {});
      expect(beforeProvinsiChosen, hasLength(2));

      final afterJawaBarat = filterCascadingOptions(field, {'provinsi': '32'});
      expect(afterJawaBarat, hasLength(1));
      expect(afterJawaBarat!.single.label, 'Bandung');

      final afterJawaTimur = filterCascadingOptions(field, {'provinsi': '35'});
      expect(afterJawaTimur, hasLength(1));
      expect(afterJawaTimur!.single.label, 'Surabaya');
    });

    test('a field with no requirements is never filtered', () {
      final result = filterCascadingOptions(_provinsiField(), {'kota': '3273'});

      expect(result, hasLength(2));
    });

    test('a field with no options returns null', () {
      const field = FormInputField(
        label: 'catatan',
        display: 'Catatan',
        type: 'text',
        validate: false,
        readOnly: false,
      );

      expect(filterCascadingOptions(field, {}), isNull);
    });
  });

  group('clearDependentFields', () {
    test('removes a stale child value from formResults itself when its '
        'parent changes — not just from what gets displayed', () {
      final forms = [_provinsiField(), _kotaField()];
      final formResults = {'provinsi': '35', 'kota': '3578'};

      final updated = clearDependentFields('provinsi', forms, formResults);

      expect(updated.containsKey('kota'), isFalse);
      expect(updated['provinsi'], '35');
    });

    test('does nothing when the child was never filled in', () {
      final forms = [_provinsiField(), _kotaField()];
      final formResults = {'provinsi': '35'};

      final updated = clearDependentFields('provinsi', forms, formResults);

      expect(updated, formResults);
    });

    test('does not touch unrelated fields', () {
      final forms = [_provinsiField(), _kotaField()];
      final formResults = {'provinsi': '35', 'kota': '3578', 'nama': 'Budi'};

      final updated = clearDependentFields('provinsi', forms, formResults);

      expect(updated['nama'], 'Budi');
    });

    test('cascades transitively through a multi-level chain '
        '(provinsi -> kota -> kecamatan)', () {
      const kecamatan = FormInputField(
        label: 'kecamatan',
        display: 'Kecamatan',
        type: 'select',
        validate: true,
        readOnly: false,
        requirements: ['kota'],
        options: [
          FormFieldOption(label: 'Coblong', value: '01', parentIds: ['3273']),
        ],
      );

      final forms = [_provinsiField(), _kotaField(), kecamatan];
      final formResults = {'provinsi': '35', 'kota': '3578', 'kecamatan': '01'};

      final updated = clearDependentFields('provinsi', forms, formResults);

      expect(updated.containsKey('kota'), isFalse);
      expect(
        updated.containsKey('kecamatan'),
        isFalse,
        reason:
            'kecamatan depends on kota, which just went stale too — '
            'clearing must propagate, not stop at one hop',
      );
    });
  });
}

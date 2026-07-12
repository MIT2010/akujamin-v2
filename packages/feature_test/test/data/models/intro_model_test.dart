import 'package:feature_test/feature_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IntroModel.fromJson maps deskripsi/image', () {
    final model = IntroModel.fromJson({
      'deskripsi': 'Selamat datang',
      'image': 'https://example.com/intro.png',
    });

    expect(model.description, 'Selamat datang');
    expect(model.imageUrl, 'https://example.com/intro.png');
  });

  test('IntroModel.fromJson tolerates missing fields', () {
    final model = IntroModel.fromJson(<String, dynamic>{});

    expect(model.description, isNull);
    expect(model.imageUrl, isNull);
  });

  test('toEntity carries both fields through unchanged', () {
    const model = IntroModel(description: 'x', imageUrl: 'y');

    final entity = model.toEntity();

    expect(entity.description, 'x');
    expect(entity.imageUrl, 'y');
  });
}

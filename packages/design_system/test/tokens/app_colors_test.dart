import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark palettes expose distinct primary colors', () {
    expect(AppColors.primary, isNot(AppColorsDark.primary));
    expect(AppColors.surface, isNot(AppColorsDark.surface));
  });
}

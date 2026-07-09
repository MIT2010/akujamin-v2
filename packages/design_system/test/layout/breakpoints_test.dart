import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breakpoints', () {
    test('classifies widths below 600 as mobile', () {
      expect(Breakpoints.isMobile(320), isTrue);
      expect(Breakpoints.isTablet(320), isFalse);
      expect(Breakpoints.isDesktop(320), isFalse);
    });

    test('classifies widths between 600 and 1024 as tablet', () {
      expect(Breakpoints.isTablet(700), isTrue);
      expect(Breakpoints.isMobile(700), isFalse);
      expect(Breakpoints.isDesktop(700), isFalse);
    });

    test('classifies widths at or above 1024 as desktop', () {
      expect(Breakpoints.isDesktop(1024), isTrue);
      expect(Breakpoints.isTablet(1024), isFalse);
    });
  });
}

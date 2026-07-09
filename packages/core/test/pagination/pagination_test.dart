import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Pagination', () {
    test('computes totalPages and hasNextPage', () {
      const page = Pagination<int>(
        items: [1, 2, 3],
        page: 1,
        pageSize: 3,
        totalItems: 10,
      );

      expect(page.totalPages, 4);
      expect(page.hasNextPage, isTrue);
    });

    test('hasNextPage is false on the last page', () {
      const page = Pagination<int>(
        items: [10],
        page: 4,
        pageSize: 3,
        totalItems: 10,
      );

      expect(page.hasNextPage, isFalse);
    });

    test('round-trips through fromJson/toJson', () {
      const page = Pagination<int>(
        items: [1, 2],
        page: 1,
        pageSize: 2,
        totalItems: 4,
      );

      final json = page.toJson((item) => item);
      final decoded = Pagination<int>.fromJson(json, (item) => item as int);

      expect(decoded, page);
    });
  });
}

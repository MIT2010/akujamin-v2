import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('ApiResponse', () {
    test('round-trips through fromJson/toJson', () {
      const response = ApiResponse<String>(
        success: true,
        message: 'ok',
        data: 'payload',
      );

      final json = response.toJson((data) => data);
      final decoded = ApiResponse<String>.fromJson(
        json,
        (data) => data as String,
      );

      expect(decoded, response);
    });

    test('data is nullable for empty-body responses', () {
      const response = ApiResponse<String>(success: true);

      expect(response.data, isNull);
      expect(response.message, isNull);
    });
  });
}

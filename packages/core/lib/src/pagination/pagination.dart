import 'package:freezed_annotation/freezed_annotation.dart';

part 'pagination.freezed.dart';
part 'pagination.g.dart';

/// Generic paged-list model shared by every feature repository.
@Freezed(genericArgumentFactories: true)
abstract class Pagination<T> with _$Pagination<T> {
  const Pagination._();

  const factory Pagination({
    required List<T> items,
    required int page,
    required int pageSize,
    required int totalItems,
  }) = _Pagination<T>;

  factory Pagination.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$PaginationFromJson(json, fromJsonT);

  int get totalPages => pageSize == 0 ? 0 : (totalItems / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
}

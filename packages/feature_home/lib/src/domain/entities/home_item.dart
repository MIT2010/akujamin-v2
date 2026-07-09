import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_item.freezed.dart';

/// Pure Dart, no json, no Flutter/Hive import (§4's dependency rule) — a
/// single factory constructor, so per ADR-005 this is `abstract class ...
/// with _$HomeItem`, not `sealed class`.
@freezed
abstract class HomeItem with _$HomeItem {
  const factory HomeItem({
    required String id,
    required String title,
    required String subtitle,
    String? imageUrl,
  }) = _HomeItem;
}

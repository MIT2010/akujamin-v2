import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/home_item.dart';

part 'home_item_model.freezed.dart';

/// hive_ce's own Freezed support (see hive_ce_generator's `@GenerateAdapters`
/// — no per-field `@HiveType`/`@HiveField` needed, unlike the old
/// `hive`/`hive_generator` pattern, which doesn't play well with Freezed's
/// generated private impl class anyway) generates a `HomeItemModelAdapter`
/// reading/writing this class through its public getters. Both it and
/// json_serializable's output default to the `.g.dart` extension, so
/// `source_gen`'s combining builder merges them into this one part file —
/// giving this annotation its own separate `part` would just leave a
/// dangling, never-generated file.
@GenerateAdapters([AdapterSpec<HomeItemModel>()])
part 'home_item_model.g.dart';

/// DTO that maps to the [HomeItem] domain entity (§19). Single factory
/// constructor → `abstract class ... with _$HomeItemModel` per ADR-005.
@freezed
abstract class HomeItemModel with _$HomeItemModel {
  const HomeItemModel._();

  const factory HomeItemModel({
    required String id,
    required String title,
    required String subtitle,
    String? imageUrl,
  }) = _HomeItemModel;

  factory HomeItemModel.fromJson(Map<String, dynamic> json) =>
      _$HomeItemModelFromJson(json);

  HomeItem toEntity() =>
      HomeItem(id: id, title: title, subtitle: subtitle, imageUrl: imageUrl);
}

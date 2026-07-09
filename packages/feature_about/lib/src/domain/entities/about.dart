import 'package:freezed_annotation/freezed_annotation.dart';

part 'about.freezed.dart';

/// One FAQ entry. Pure Dart, no json, no Flutter import (§4's dependency
/// rule) — single factory constructor, so per ADR-005 this is
/// `abstract class ... with _$About`, not `sealed class`.
///
/// Migrated from akujamin-app's `AboutEntity` (`type`/`text`) — field names
/// kept as-is (not renamed to e.g. `category`) for direct traceability to
/// the API contract; the old entity already normalized the wire field
/// `jenis` to `type` (see [AboutModel.fromJson] in about_model.dart), so
/// this only carries that normalization forward
/// (docs/MIGRATION_PLAYBOOK.md §2's mapping recipe).
@freezed
abstract class About with _$About {
  const factory About({required String type, required String text}) = _About;
}

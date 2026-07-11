import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/counseling_session.dart';

part 'counseling_session_model.freezed.dart';
part 'counseling_session_model.g.dart';

/// DTO for `/chat/list`'s `data` array. Field renames confirmed by reading
/// the old app's `CounselingModel.fromJson`
/// (`lib/src/features/counseling/data/models/counseling_model.dart`) — not
/// guessed (docs/MIGRATION_PLAYBOOK.md §2a). `tanggal` is parsed with
/// `DateTime.parse` (not `tryParse`), matching the old app exactly — a
/// missing/malformed date is a real parse failure there too, not something
/// to silently paper over here.
@freezed
abstract class CounselingSessionModel with _$CounselingSessionModel {
  const CounselingSessionModel._();

  const factory CounselingSessionModel({
    @JsonKey(name: 'conversation_id') required int id,
    @JsonKey(name: 'kode_voucher') required String code,
    @JsonKey(name: 'psikolog_name') required String psychologist,
    required String status,
    @JsonKey(name: 'tanggal') required DateTime createdAt,
  }) = _CounselingSessionModel;

  factory CounselingSessionModel.fromJson(Map<String, dynamic> json) =>
      _$CounselingSessionModelFromJson(json);

  CounselingSession toEntity() => CounselingSession(
    id: id,
    code: code,
    psychologist: psychologist,
    status: status,
    createdAt: createdAt,
  );
}

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/test_history_item.dart';

part 'test_history_item_model.freezed.dart';
part 'test_history_item_model.g.dart';

/// DTO for one entry of `/tes/list-voucher`'s `datas` array. Field renames
/// confirmed by reading the old app's `VoucherModel.fromJson`
/// (`lib/src/features/payment/data/models/voucher_model.dart`) — not
/// guessed (docs/MIGRATION_PLAYBOOK.md §2a).
@freezed
abstract class TestHistoryItemModel with _$TestHistoryItemModel {
  const TestHistoryItemModel._();

  const factory TestHistoryItemModel({
    @JsonKey(name: 'kode_voucher') required String code,
    @JsonKey(name: 'jenis_pekerjaan') required String job,
    @JsonKey(name: 'negara_tujuan') required String destinationCountry,
    @JsonKey(name: 'status_ujian') required String status,
    @JsonKey(name: 'nama_lembaga') required String institution,
    @JsonKey(name: 'nama_psikolog') required String psychologist,
    @JsonKey(name: 'ujian_ke') required String testAttempt,
    @JsonKey(name: 'hasil_tes') required String testResult,
    @JsonKey(name: 'tgl_regis') required DateTime createdAt,
    @JsonKey(name: 'sertifikat') String? certificateUrl,
  }) = _TestHistoryItemModel;

  factory TestHistoryItemModel.fromJson(Map<String, dynamic> json) =>
      _$TestHistoryItemModelFromJson(json);

  TestHistoryItem toEntity() => TestHistoryItem(
    code: code,
    job: job,
    destinationCountry: destinationCountry,
    status: status,
    institution: institution,
    psychologist: psychologist,
    testAttempt: testAttempt,
    testResult: testResult,
    createdAt: createdAt,
    certificateUrl: certificateUrl,
  );
}

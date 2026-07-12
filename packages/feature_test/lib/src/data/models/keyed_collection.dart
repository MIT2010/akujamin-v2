/// The old app's `/pertanyaan/getv2` response serializes each of `bab`
/// (sections), `soal` (questions) and `sub_items` as a JSON object keyed by
/// an arbitrary string (the key becomes the entity's `name`/`text`) — except
/// when the collection is empty, where Laravel/PHP serializes an empty
/// associative array as `[]` instead of `{}`. The old app's own
/// `SectionModel.fromJson` already guards `soal` for exactly this
/// (`data['soal'].isNotEmpty ? (cast) : []`) but `QuestionModel.fromJson`
/// never got the same guard for `sub_items` — a latent `TypeError` risk
/// (`List` cast to `Map`), found while auditing before this feature's code
/// was written (MIGRATION_LOG.md permanent findings, docs/qa/test.md §Langkah
/// 3). Applied uniformly to all three fields here instead of guarding only
/// the one the old app happened to hit.
Map<String, dynamic> asKeyedMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  return const {};
}

/// A test's category, inferred from its name containing `"Pengetahuan"`
/// (general-knowledge) vs. everything else (psychological) — the old app's
/// own detection rule (`TestModel.fromJson`), not guessed. Determines which
/// field names `saveTestAnswer`'s request body uses
/// (`pengetahuan_umums_id`/`jawaban_pengetahuan_umum_id` vs.
/// `psikologis_id`/`jawaban_psikologis_id`).
enum TestType { pengetahuan, psikologi }

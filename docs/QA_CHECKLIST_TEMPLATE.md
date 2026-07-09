# QA checklist template

A generic, reusable template for the manual side-by-side QA that
[MIGRATION_PLAYBOOK.md](MIGRATION_PLAYBOOK.md) §4's definition-of-done
requires — "seen rendering in the real running app" means *driven through
its real inputs*, not just opened once. This file itself stays generic;
each migration project fills in its own copy per feature.

## How to use

1. **Copy this file once per migrated feature**, before you start manual
   QA — e.g. `docs/qa/about.md` in the migration project (not in this
   starter kit repo). Don't fill in the template in place here.
2. **Run the old app and the new app side by side.** The old app is the
   source of truth for "correct" behavior until cutover — the new app is
   being checked *against* it, not against your memory of what it should do.
3. **Add one row per meaningfully different input or action** on the
   migrated screen(s): what you did, what you expected, what the old app
   actually did, what the new app actually did. Only check the box when old
   and new match — or when they deliberately differ, note *why* in the
   "Hasil di app baru" cell (e.g. "improved: old app silently failed here,
   new app shows an error message") rather than leaving a mismatch unexplained.
4. **Don't skip edge cases.** At minimum, cover: empty/initial state,
   validation errors, a server failure (4xx/5xx), a network failure, and
   any boundary values specific to the feature (max length, empty list,
   pagination edge). A happy-path-only checklist doesn't earn the checkbox
   in the definition-of-done.
5. **This is evidence, not paperwork.** Link the filled-in file from your
   project's migration tracking (e.g. `MIGRATION_LOG.md`'s row for that
   feature) when you mark it done — a reviewer (including future you)
   should be able to open it and see what was actually checked.

### When a row can't be filled in from the old app

Some checks won't have an old-app equivalent — genuinely new behavior, or
the old app crashes/misbehaves in a way you're not replicating on purpose.
Write `N/A — <why>` in the "Hasil di app lama" column instead of leaving it
blank, so it's clear the gap was noticed, not missed.

---

## Template

Copy the table below (replace the example rows with the feature's actual
inputs/actions):

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka halaman tanpa login | Redirect ke `/login` | | | [ ] |
| Buka halaman dalam keadaan normal | Data tampil sesuai data server | | | [ ] |
| Submit form dengan field wajib kosong | Validasi error muncul, tidak ada request ke server | | | [ ] |
| Submit dengan input valid | Sukses, data tersimpan/tampil di tempat yang benar | | | [ ] |
| Server mengembalikan error (4xx/5xx) | Pesan error yang jelas untuk user, app tidak crash | | | [ ] |
| Tidak ada koneksi internet | Sesuai §11 kit (stale-cache jika ada cache, atau pesan error jaringan jika tidak) | | | [ ] |
| Nilai batas (mis. teks maksimum panjang, list kosong, angka nol/negatif) | Sesuai perilaku yang didefinisikan, tidak crash | | | [ ] |

---

## See also

- [MIGRATION_PLAYBOOK.md](MIGRATION_PLAYBOOK.md) — §4's definition-of-done
  is what this checklist provides evidence for.
- [../ARCHITECTURE.md](../ARCHITECTURE.md) §28 (Testing Strategy) and
  ADR-010 — automated tests and this manual checklist cover different
  things; neither substitutes for the other.

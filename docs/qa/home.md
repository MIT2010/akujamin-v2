# QA checklist — `home` (`/home` shell tab body content)

Migrated from the old app's real `dashboard/presentation/pages/home_page.dart`
(profile teaser + incomplete-profile nudge). Found and built during the
**reconciliation audit** (2026-07-14, LANGKAH 1-3), not a normal
feature-by-feature migration slice — the content this replaced
(`HomeCubit`/`HomeItem`/a Hive-cached paginated feed) was confirmed, by
checking against `flutter_starter_kit` (the template this project was
bootstrapped from), to be generic starter-kit demo content that predates
every real migration decision in this repo. It was never derived from the
old app at all — the reconciliation audit's own `reconciliation_audit.html`
artifact and [MIGRATION_LOG.md](../../MIGRATION_LOG.md)'s `dashboard` row
record this finding in full.

---

## What was removed, and why it was safe to remove

`HomeCubit`, `HomeState`, `HomeItem`(+model), `HomeFeed`, `HomeRepository`
(+impl), `HomeRemoteDataSource`, `HomeLocalDataSource`, the Hive
`home_items` box registration, and the `HomeItemCard` widget — all deleted,
not left behind unused. Verified before deleting, not assumed:

- `git log --diff-filter=A -- 'packages/feature_home/**'` shows
  `feature_home` already existed, in this exact shape, in the very first
  "Bootstrap akujamin-v2 from flutter_starter_kit" commit — before `about`
  (the pilot feature) was even migrated.
- `flutter_starter_kit`'s own `packages/feature_home` (the template
  repo, a separate checkout on the same machine) has the identical
  `HomeItem`/`home_feed.dart`/Hive-datasource shape — confirming this
  is the template's own demo content, not something akujamin-v2 built.
- Grepped the whole old app (`akujamin-app`) for `home/feed`, `HomeItem`,
  and any Hive-cache concept — zero hits. No such endpoint or abstraction
  exists anywhere in the app this project migrates from.

---

## What replaced it

`avatar`/`name` (profile teaser) and the `!isRegistered` nudge, both read
directly from `AuthCubit.state` — no repository/datasource/UseCase of its
own, same "one source of truth, not a second copy of the same data"
reasoning as `feature_profile`'s `ProfileView` (see
[account.md](account.md)). `feature_home` now depends only on
`authentication`, `design_system`, `shared`; `core`/`hive_ce`/
`hive_ce_flutter`/`freezed_annotation`/`json_annotation` all dropped from
its `pubspec.yaml` since nothing in the package needs them anymore.

The AppBar's five action icons (onboarding/FAQ/counseling/payment-gate/
logout — already migrated in an earlier session) are unchanged; the old
app's menu-grid concept those icons already replace is not rebuilt a
second time, per the explicit instruction for this slice.

---

## Two real bugs found and fixed while building this, not part of the ask

**1. `HomeView`'s Payment button had no `BlocProvider<AuthCubit>` ancestor
in production code — a live crash-on-tap bug.** `context.read<AuthCubit>()`
(in the Payment icon's `onPressed`) requires a `BlocProvider<AuthCubit>`
somewhere above it in the widget tree. Grepped `apps/mobile/lib` for
`BlocProvider`: zero matches. The only place `AuthCubit` was ever provided
for `/home` was inside `home_page_test.dart`'s own test harness — the test
was compensating for a wiring gap that never existed in the real app,
so it passed while the real button would have thrown
`ProviderNotFoundException` the moment a user tapped it. Fixed by
`HomePage` providing the singleton via `BlocProvider<AuthCubit>.value(value:
getIt<AuthCubit>())`, the exact pattern `ProfilePage` already used
correctly. Directly relevant here regardless: the new profile teaser reads
`AuthCubit.state` from `HomeView`'s `build()` method itself, not just a
button handler, so this had to be fixed for the new content to work at
all — not scope creep.

**2. A returning authenticated user briefly saw the login form before
landing on `/home` — measured directly, not assumed.** `AuthSessionAdapter.
_toStatus()` mapped `AuthState.initial()` (the window between app start and
`AuthCubit._restoreCachedSession()` resolving) to the same
`AuthSessionStatus.unauthenticated` as a confirmed-logged-out session. A
throwaway widget test pre-seeding a real cached session (`FlutterSecureStorage.
setMockInitialValues`) proved the very first frame `AppRouter` builds
renders `/login`'s populated form, not a blank gap — worse than the "jeda
kosong" originally asked about, since it's a flash of the *wrong, fully
rendered* screen. Fixed with a minimal loading gate in `App.build()`
(`BlocBuilder<AuthCubit, AuthState>`: while `AuthInitial`, show a bare
`CircularProgressIndicator`; only build the real `MaterialApp.router` once
the first real `AuthState` is known) — the minimal functional equivalent of
the old app's dedicated `AuthStatus.checkingSession`/`/splash` gate, not
its full carousel/branding (see [GAPS.md](../../GAPS.md) for why the full
splash screen itself stays an accepted gap).

Fixing this exposed a **pre-existing, unrelated test-environment gap**:
`flutter_secure_storage`'s real platform channel hangs forever under
`flutter_test` (same class of issue as `path_provider`, already documented
in `widget_test.dart`'s own comments) — previously never mattered because
the buggy `initial == unauthenticated` mapping made the app not actually
wait for that read to resolve. `apps/mobile/test/widget_test.dart` now
seeds `FlutterSecureStorage.setMockInitialValues({})` before booting, the
same official in-memory backing `secure_token_storage_test.dart`'s
real-storage group already uses.

---

## Explicitly out of scope

- **The about/counseling/payment menu grid** — already has a live
  equivalent (the AppBar icons), not rebuilt as a second surface.
- **A full splash/branding screen** — the session-restore *gate* (bug #2
  above) is fixed for real; the old app's full carousel/logo splash screen
  is not rebuilt. See [GAPS.md](../../GAPS.md).

---

## Side-by-side checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka `/home` dengan SessionProfile ada | Avatar + "Halo, {nama}" + email tampil | `HomePage` baca `AuthStateCubit.state.user`, tampilkan avatar/nama | `HomeView` baca `AuthCubit.state.sessionProfile`, tampilkan avatar/nama, fallback ke `Icon(Icons.person)` bila avatar kosong — verified widget test | [x] |
| Buka `/home` tanpa SessionProfile (flow email/password sintetis) | Tidak crash, tampilkan identitas yang masuk akal | N/A — app lama hanya punya flow OTP, selalu ada profile lengkap | Fallback ke `user.email` sebagai nama tampilan — verified widget test | [x] |
| User belum `isRegistered` | Banner "lengkapi profil" tampil, bisa ditekan ke `/register` | `home_menu_config.dart`'s gate — redirect ke `register` saat tombol Tes Psikologi ditekan, tanpa nudge visual terpisah di body halaman | Banner permanen di body (bukan cuma gate reaktif saat tombol ditekan) — nudge lebih terlihat, disengaja — verified widget test termasuk navigasi tap | [x] — perbaikan visibilitas, bukan port apa adanya |
| User sudah `isRegistered` | Banner tidak tampil | N/A | Verified widget test | [x] |
| Tekan tombol Payment (`isRegistered == false`) | Redirect ke `/register`, TIDAK crash | Gate `home_menu_config.dart` | Sama — dan sekarang benar-benar tidak crash karena `BlocProvider<AuthCubit>` sudah disambungkan (bug #1 di atas) — verified widget test | [x] — perbaikan bug nyata |
| Tekan Logout | Sesi berakhir, kembali ke `/login` | `AuthStateCubit.clearToken()` + redirect | `context.read<AuthCubit>().logout()` + `context.go('/login')` — verified widget test | [x] |
| Buka app dengan sesi tersimpan (returning user) | Langsung ke `/home`, tidak pernah menampilkan form login | N/A — app lama punya gate `AuthStatus.checkingSession`/`/splash` eksplisit untuk ini | Sebelum perbaikan bug #2: form login sempat ter-render 1 frame sebelum redirect ke `/home` — SEKARANG: loading indicator minimal ditampilkan sampai status sesi diketahui, form login tidak pernah dirender untuk user yang sudah login — verified widget test (`app_session_gate_test.dart`), dibuktikan lewat pengukuran frame-by-frame sebelum perbaikan | [x] — perbaikan bug nyata, dibuktikan terukur |
| Buka app tanpa sesi tersimpan | Langsung ke `/login` | Sama | Sama, tidak berubah oleh perbaikan bug #2 — verified widget test | [x] |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `dashboard`/`home` rows,
  and the reconciliation-audit section this whole slice comes from.
- [GAPS.md](../../GAPS.md) — the full splash-screen gap this file's bug
  fix narrows but doesn't fully close.
- [account.md](account.md) — the "no repository of its own, read straight
  from `AuthCubit.state`" pattern this file's teaser reuses, and the
  `SessionProfile`/`nik`-separate-from-`User` design it depends on.

# QA checklist — `about` (FAQ) migration pilot

Copied from [../QA_CHECKLIST_TEMPLATE.md](../QA_CHECKLIST_TEMPLATE.md) and
filled in for `packages/feature_about`, the pilot feature (AUDIT.md §4,
MIGRATION_LOG.md). Read the "Environment constraints" section first — it
explains why the evidence here is real-data/real-code but not screen
recordings, and precisely what that does and doesn't cover.

---

## Environment constraints (read this first)

Two independent things blocked the usual screenshot-based proof this
project's earlier features (`feature_home`, `feature_profile` in the
starter kit) used, both diagnosed, not guessed at:

1. **OS-level GUI automation (simulated mouse clicks) can't reach the
   interactive desktop from this tool execution context.** `PrintWindow`
   captured the running `mobile.exe` window fine (proving the window is
   real and rendering), but `SetCursorPos`/`mouse_event` silently no-op'd —
   confirmed via `GetForegroundWindow()` never matching the app's window
   handle after `SetForegroundWindow()`, and the OS cursor position never
   moving to the intended coordinates. This is Windows session/window-
   station isolation, a real security boundary for background/service
   execution contexts, not a coordinate mistake (verified across two
   separate click attempts at different, correctly-computed target points).
2. **`RenderRepaintBoundary.toImage()` inside `flutter_test` hangs
   indefinitely in this sandbox.** Confirmed by isolating it: the identical
   widget/Cubit test *without* the `toImage()` call completes in about a
   second; the same test *with* it never returns (killed after exceeding
   `flutter test`'s internal 10-minute ceiling, twice, on different attempts).

Neither is a defect in `feature_about`'s code — both are this specific
sandboxed environment's limits on screen capture and input injection.
Given that, verification below is **assertion-based and real-data-based
instead of screenshot-based**: every check exercises the actual production
code (`AboutCubit`, `AboutRepositoryImpl`, `AboutRemoteDataSource`,
`ApiClient`, real `Dio`) against a real local HTTP server, or the exact
data that call returned — not mocked Dart objects standing in for a
network response. What's *not* independently proven here is that a human
finger/mouse click reaches the FAQ icon on a real screen — the route and
UI entry point are wired (§ below) and covered by `melos run analyze` +
the repository/cubit unit tests, but the tap-through itself isn't captured
as a video/screenshot the way `feature_profile`'s was.

**What was verified, concretely (throwaway test files, run then deleted —
not part of the repo):**

- **Real network pipeline**, `AboutRepositoryImpl` → `AboutRemoteDataSource`
  → `ApiClient` → real `Dio` → a local mock server serving the exact
  `{status, message, datas}` envelope shape the real `/faq/get` endpoint
  uses (per `about_api_service.dart` in the old app): confirmed for the
  success path (3 real items round-tripped, `jenis`→`type` mapping
  correct), the app-level failure path (`status != 'ok'` → `ServerFailure`
  with the server's message), and the HTTP-level failure path (500 →
  `ServerFailure` via `ApiClient`'s existing DioException mapping).
- **Real widget rendering**, `AboutView` (the actual production widget,
  not a stand-in) pumped with a real `AboutCubit`: loading state (spinner +
  `FAQ` app bar title), loaded state showing all 3 real FAQ item titles,
  tap-to-expand revealing the *exact* real text string from the network
  call above, error state showing the real failure message and a working
  retry button that re-resolves to the loaded state.
- **App boots and the entry point exists**: a real `mobile.exe` Windows
  build was launched and screenshotted via `PrintWindow` — it landed
  (via a pre-existing cached session, a separate observation noted below)
  directly on `Home`, showing the FAQ icon button (leftmost of the three
  AppBar actions) next to Profile and Logout, confirming the UI entry
  point from ADR-010's wiring checklist is actually present on screen.
- **Whole-workspace pipeline green**: `melos run gen` / `analyze` /
  `format` / `test` all pass for the entire `akujamin-v2` workspace with
  `feature_about` included (14 packages, `feature_about`'s own 5 unit
  tests among them).

**Incidental finding, not a feature_about bug:** the Windows build landed
straight on `/home` already authenticated, without ever showing `/login`.
`flutter_secure_storage`'s Windows Credential Manager entry is keyed by
the app's bundle identifier, which was never customized when `akujamin-v2`
was bootstrapped from the starter kit (`com.example.mobile`, unchanged) —
so a token saved by an earlier starter-kit login session on this same
Windows account is being picked up here too. Not a security issue for a
shipped app (different real bundle ids on real devices), but worth fixing
before this matters more: give `akujamin-v2` its own `applicationId`.

**Old-app comparison — a real constraint, stated plainly.** The legacy
`akujamin-app`'s `Env.baseURL` has no working default (`String.fromEnvironment('BASE_URL_API', defaultValue: '/api')` — a bare relative
path, not a real host) and requires a `--dart-define` value this
environment doesn't have; its `about` screen additionally sits behind a
real login with no test credentials available here. Both were confirmed,
not assumed (checked `env.dart`, traced the auth-gated route to
`dashboard`). So the "Hasil di app lama" column below is filled from
**direct reading of the old app's actual source** (`about_api_service.dart`,
`about_repo_impl.dart`, `dashboard/blocs/about/about_state_cubit.dart` —
all fully read, cited by exact behavior, not guessed) rather than a live
run. This is weaker than watching the old app run, and it's flagged as
such rather than presented as equivalent.

---

## Checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka halaman FAQ dalam keadaan normal | Data tampil sesuai data server | Per source: `AboutStateCubit.getAbout()` emits `Loading` → calls `GetAboutUsecase` → `Success(List<AboutEntity>)`, rendered by whatever screen currently owns the list (`dashboard`, not `about_page.dart` itself — see AUDIT.md §4 caveat 1) | `AboutCubit.getAbout()` emits `loading` → `loaded(List<About>)`; `AboutView` shows all 3 item titles from the real mock response (`Umum`, `Pembayaran`, `Akun`) | [x] |
| Tap satu item FAQ | Konten pertanyaan tersebut terlihat | Per source: old `AboutPage` renders markdown `text` for the single item navigated to (via route `extra`) | `ExpansionTile` expands, shows the plain-text `text` field — verified the *exact* real string returned by the mock server appears | [x] — see note on markdown below |
| Server mengembalikan status aplikasi bukan `'ok'` (app-level error, HTTP 200) | Pesan error ditampilkan, bukan crash | Per source: `AboutRepositoryImpl.getAbout()` (old) checks `data['status'] != 'ok'` → `Left(ErrorModel(code: 422, message: data['message']))` | `AboutRepositoryImpl.getAbout()` (new) checks the same field → `Err(ServerFailure(envelope['message']))` — confirmed real round-trip returns the mock's exact message `"FAQ tidak ditemukan"` | [x] |
| Server mengembalikan error HTTP (5xx) | Pesan error yang jelas untuk user, app tidak crash | N/A — old `BaseApiService` maps any `DioException` via a shared `ErrorHandler`, not independently re-verified here (out of scope: verifying old app's HTTP error path isn't part of migrating `about`) | `AboutView` shows `Internal server error` (the real message `ApiClient` derived from the mock's 500 response) + a `Coba lagi` button; tapping retry re-calls `getAbout()` and recovers to the loaded state | [x] |
| Tidak ada koneksi internet | Sesuai §11 kit — `about` has no local cache (matches `feature_profile`, unlike `feature_home`), so this should behave identically to "server error": a clear `NetworkFailure` message, not a crash, no silent stale data (there's nothing to fall back to) | N/A — not independently checked against the old app | Not separately exercised this pass — `ApiClient`'s existing `ConnectivityInterceptor`/`_mapDioError` (already unit-tested in `packages/core`) is what would fire; `about` adds no new code on this path since it has no cache to fall back to | [ ] — see note below |
| Buka halaman FAQ tanpa login | N/A — `about` doesn't have its own auth gate; reachability depends on being on `/home` first, which *is* gated | N/A | Route `/about` isn't in `shared`'s public-route allowlist, same treatment as `/profile`/`/home` — not independently re-tested here since it's identical to the already-covered `/profile` case, not new behavior `about` introduces | [ ] — not new to this feature, not re-verified |
| FAQ list kosong (`datas: []`) | Tampilkan pesan kosong, bukan crash | N/A — not checked against old app | `AboutView` has an explicit `items.isEmpty` branch showing "Belum ada FAQ." — present in the code (`about_page.dart`) but not exercised against a real empty-array response this pass | [ ] — code path exists, not independently exercised |

**Rows left unchecked above are honest gaps, not silently skipped** — each
has a reason next to it. The core data-flow and error-handling paths (the
ones that actually differ between old and new architecture, which is the
whole point of this pilot) are checked; the network-connectivity and
empty-list branches reuse already-tested `core` code and the one path this
feature adds no new logic to.

**Markdown rendering note:** the old app renders FAQ text through
`CustomMarkdownWidget`; the migrated version renders plain `Text` —
a deliberate, tracked simplification (AUDIT.md §3 flags a real markdown
widget as a `design_system` addition still to be built), not a missed
requirement. If the real FAQ content uses markdown formatting (bold,
lists), that formatting won't render until that widget exists.

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `about`'s row, linked here.
- [../../AUDIT.md](../../AUDIT.md) §4 — why `about` was picked as the pilot.
- [../MIGRATION_PLAYBOOK.md](../MIGRATION_PLAYBOOK.md) §4 — the
  definition-of-done this checklist is evidence for.

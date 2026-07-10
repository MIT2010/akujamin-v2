# QA checklist — `onboarding` (intro carousel) migration

Copied from [../QA_CHECKLIST_TEMPLATE.md](../QA_CHECKLIST_TEMPLATE.md) and
filled in for `packages/feature_onboarding`, the second migrated feature
(MIGRATION_LOG.md). Read "Environment constraints" first — same as
`about`'s QA doc, and for the same reasons.

---

## Environment constraints (same as `about`, not re-litigated)

Screenshot-based proof (this project's earlier established bar) is not
achievable in this environment for two independently diagnosed reasons —
full detail in [about.md](about.md): OS-level GUI automation is blocked by
Windows session isolation, and `RenderRepaintBoundary.toImage()` hangs
inside `flutter_test` in this sandbox. Verification below is
assertion-based against real code and (for the local-storage layer) real
data instead.

**One thing `onboarding` proves that `about` couldn't**: `about` needed an
external mock HTTP server for its "real data" proof. `onboarding` is
local-only, so its "real" pipeline test needed *nothing external* —
`SharedPreferences.setMockInitialValues({})` is the officially-supported
in-memory backing for that plugin, and the test below exercises the real
`OnboardingRepositoryImpl` → `OnboardingLocalDataSource` →
`SharedPreferences` chain with **zero mocking at any layer**, stronger
than what was possible for `about`.

**What was verified, concretely (throwaway test files, run then deleted —
not part of the repo):**

- **Real local-storage pipeline, no mocking anywhere**: constructed a real
  `OnboardingRepositoryImpl(OnboardingLocalDataSource(realPrefs))` against
  `SharedPreferences.setMockInitialValues({})`. Confirmed: reads `true`
  (first launch) before anything is written, `setIsFirstLaunch()`
  succeeds, and a subsequent read genuinely returns `false` — real
  persistence across separate repository calls, not a mocked assertion.
- **Real widget rendering**, `OnboardingView` (the actual production
  widget) pumped with a real `OnboardingCubit`: loading/checking state,
  the full 4-slide carousel with the *exact* real copy text from the old
  app (welcome message, "why AKUJAMIN", camera-access disclosure,
  KTP/face-verification disclosure), tapping through all 4 slides via
  `AppButton` "Lanjut"/"Mulai" taps, confirmed `complete()` is actually
  called on the last slide, confirmed the `alreadyCompleted` state
  correctly skips the carousel entirely, confirmed the `error` state shows
  the real `CacheFailure` message with a working retry button, and
  confirmed both `finished` and `alreadyCompleted` genuinely trigger
  `context.go('/home')` (driven through a real minimal `GoRouter`, not
  just asserted the state — an earlier version of this test emitted the
  state *before* the widget subscribed and caught its own bug: the
  listener never saw a transition, so navigation silently never fired;
  fixed by emitting after `pumpWidget`, matching real app timing).
- **Whole-workspace pipeline green**: `melos run gen`/`analyze`/`format`/
  `test` all pass with `feature_onboarding` included. This *did* catch a
  real issue the first time: `apps/mobile/test/widget_test.dart` hung for
  the full 10-minute `flutter test` ceiling because `configureDependencies()`
  now loads a real `SharedPreferences` instance (via `feature_onboarding`'s
  `@preResolve`), and that test never registered `shared_preferences`'
  test double — same class of problem as the pre-existing Hive/
  path_provider fake already in that file, fixed the same way
  (`SharedPreferences.setMockInitialValues({})` in `setUp`).

**Real, deliberate architectural decision found and documented in code**:
the old app stored this flag in `flutter_secure_storage`
(`OnboardingLocalServiceImpl`) — the wrong tier for a non-sensitive
boolean per the kit's own ARCHITECTURE.md §24 storage table. The migrated
version uses `shared_preferences` instead. This is a correction, not a
downgrade — MIGRATION_PLAYBOOK.md §3's "storage tier must not downgrade"
rule protects genuinely sensitive fields from landing somewhere weaker;
there was nothing sensitive in a first-launch flag to begin with.

**Old-app comparison**: unlike `about` (blocked by missing backend
credentials), `onboarding` has no network dependency at all, so there's no
comparable "couldn't run the old app" gap here — the old app's actual
source (`OnboardingLocalServiceImpl`, `OnboardingRepositoryImpl`,
`OnboardingPage`) was read in full and is what "Hasil di app lama" below
is grounded in.

---

## Checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka layar onboarding saat status belum pernah disimpan | Tampilkan carousel 4 slide | Old app always shows the carousel unconditionally (never checked the flag itself — see below) | `checkStatus()` reads the flag, shows the carousel (`showCarousel` state) — verified with the real copy text for all 4 slides | [x] |
| Buka layar onboarding saat status sudah pernah diselesaikan | Lewati carousel | N/A — old app never checked this on entry (always showed the carousel regardless); this read-before-show behavior is new, added specifically to exercise the repository's read path within this feature (see docs/qa/onboarding.md's own cubit doc comment) | `alreadyCompleted` state skips the carousel, navigates straight to `/home` — verified | [x] |
| Selesaikan carousel (tap "Mulai" di slide terakhir) | Status tersimpan, lanjut ke aplikasi | Calls `context.read<AuthStateCubit>().setIsFirstLaunch()` (old app couples this to the *auth* cubit, not its own onboarding state — not carried over, see §0 golden rule) | `complete()` calls the real `OnboardingRepository.setIsFirstLaunch()`, confirmed the flag genuinely persists (real `SharedPreferences`, no mock), then navigates to `/home` | [x] |
| Penyimpanan status gagal (disk/platform error) | Pesan error, tombol coba lagi, tidak crash | N/A — old `OnboardingRepository` returns a bare `Future<bool>`/`Future<void>`, no error path modeled at all | `CacheFailure` shown with real message + `Coba lagi` button, retry re-triggers `checkStatus()` — this is the *first* feature to exercise `CacheFailure` (declared in `core` since day one, unused until now) | [x] |
| Auto-tampil sebelum login pada instalasi pertama (real first launch) | Carousel muncul otomatis, gating splash→onboarding→login | Old app's `AuthStateCubit`-driven router redirect auto-shows this pre-login | **Not reproduced** — reachable via a manual entry point on Home instead (ADR-010's minimal-wiring bar, same as every migrated feature so far). Deferred, not dropped — real router-redirect integration needs `shared`'s `AppRouter` extended with an onboarding-aware check, out of scope for proving this feature's own pattern | [ ] — known, tracked gap |
| Visual assets (logo, KTP scan icon, camera icon dsb.) | Tampilkan brand assets asli | Real image assets (`ImageAsset.icon`, `ImageAsset.ktpScan`, etc.) | Simplified to Material `Icon`s — the old app's actual asset files aren't available to port into this repo. Copy *text* is verbatim from the old app (real consent language), only the imagery is simplified | [ ] — known, tracked simplification |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `onboarding`'s row.
- [../../AUDIT.md](../../AUDIT.md) — feature inventory and the `about`
  pilot's original selection reasoning `onboarding` follows.
- [about.md](about.md) — the environment-constraints writeup this file
  points back to rather than repeats.

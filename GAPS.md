# Gaps — AKUJAMIN migration

Every gap below was consciously found and accepted at some point during the
migration — none were silently missed. This file exists so they live in one
place instead of scattered across `MIGRATION_LOG.md` and 11 separate
`docs/qa/*.md` files. **Every line cites its real source** — built by
re-grepping `MIGRATION_LOG.md` and every `docs/qa/*.md` file for
"belum direplikasi", "tidak diuji", "di luar cakupan", "belum diuji",
"CATATAN:", "accepted gap", "deferred", "out of scope", "TODO" and reading
the surrounding context — not transcribed from memory. Where a quote below
is close to but not the literal wording of a linked doc, the doc itself is
still the authority; check it before acting on this file alone.

See [MIGRATION_LOG.md](MIGRATION_LOG.md) for full per-feature migration
history and [docs/reconciliation_audit.html](docs/reconciliation_audit.html)
for the file-by-file reconciliation (LANGKAH 1) this file's last section
comes from.

---

## 🚨 REQUIRES EXTERNAL ESCALATION — not an accepted migration gap

**Everything below this file's intro is a gap *we* consciously accepted.
This one is different: it is a live backend vulnerability, found by this
app but not caused by it, and it cannot be closed by anything in this
repo. It needs to be escalated to whoever owns the Development backend —
recorded here so it does not quietly sit as "just another item" in a
list of self-accepted tradeoffs.**

**`POST /tes/create` (`createVoucher`) leaks a raw SQL error —
including the internal DB host, port, database name, and connection-pool
name — to the client, on every single call, for every account, because
its own server-side `kode_voucher` generator is broken and deterministic
(not random).** Full details, evidence, and the two-attempts-two-accounts
reproduction are in **[MIGRATION_LOG.md finding #11](MIGRATION_LOG.md)**
(search for `**11. 🔴 OPEN`) — not duplicated here beyond the summary
below, so the two documents can't drift apart on the facts.

**Why this belongs here and not in the sections below**: sections (a)-(c)
are about *this app's* behavior deliberately falling short of the old
app's. This is the opposite direction — the *backend* is exposing
infrastructure internals it should never expose, and failing a core
write path (starting a psychology test) for every user, regardless of
which client calls it. Nothing in `akujamin-v2` (or the old app, for that
matter) can fix either half of this from the client side.

**Two distinct problems, confirmed 2026-07-15, both still open:**

1. **Information disclosure** — the full SQL `INSERT` statement, bound
   values, DB host/port/database name, and the named connection pool
   (`db_partner`) come back verbatim in a client-facing error string.
   This is infrastructure detail that must never reach a client,
   security posture aside — confirmed to originate backend-side
   (Laravel/FrankenPHP), not something any request shape or client-side
   handling can suppress.
2. **A broken, deterministic voucher-code generator** — `kode_voucher`
   is server-generated (the client never supplies one), yet it returned
   the *exact same* code (`U2JH8RAHQZ5YYGTE`) on every one of 5 separate
   `createVoucher` calls, across 2 independent user accounts and 2
   separate process runs minutes apart — ruling out both random chance
   and per-account derivation. `POST /tes/create` is confirmed broken
   backend-wide, not account-specific, and no client-side retry can ever
   succeed until the backend team fixes the generator or clears
   whatever already occupies that code in `peserta`.

**Action needed, external to this repo**: report both findings to
whoever owns the Development backend (contact unknown to this session —
whoever receives this file should route it). Until fixed, `LANGKAH 2.5`
(counseling) and `LANGKAH 2.6` (test-taking) stay unreachable end-to-end
against this environment, since both need a real voucher that
`createVoucher` cannot currently produce.

---

## (a) UI behavior deliberately simplified

**Onboarding visual assets replaced with Material Icons, copy text kept
verbatim.** *"asset visual asli (logo/ikon KTP) diganti Material Icon, copy
text asli dipertahankan"* — [MIGRATION_LOG.md](MIGRATION_LOG.md) (`onboarding`
row). Reason given directly in [docs/qa/onboarding.md](docs/qa/onboarding.md)
("Visual assets" row): *"the old app's actual asset files aren't available
to port into this repo."*

**`ChatMessageStatus` only has `pending`/`sent`/`failed` — no
`delivered`/`read`.** [docs/qa/counseling.md](docs/qa/counseling.md)
(decision e): the old app's own `MessageStatus` enum had those two extra
states but they were purely decorative (never actually verified), so this
migration deliberately doesn't fabricate them — *"deliberately honest, not a
fake read-receipt system... states the app can actually verify."*

**About/counseling/payment menu grid not rebuilt as a second surface.**
[docs/qa/home.md](docs/qa/home.md), "Explicitly out of scope": the AppBar
icons already reach the same destinations, so the old dashboard's tile grid
wasn't duplicated.

**Five cosmetic UI abstractions from the old app have no counterpart —
found during the reconciliation audit (LANGKAH 1), not previously tracked
anywhere.** Source: [docs/reconciliation_audit.html](docs/reconciliation_audit.html)
(11-file unclassified list) — each had a real call site in the old app
(confirmed live, not dead code) but no documented decision to skip or
replace it exists prior to this audit:
- `core/shared/pages/coming_soon_page.dart` — the old dashboard's
  about-menu null-content fallback screen.
- `core/shared/widgets/dashed_border.dart` — payment/register upload
  screens; silently replaced with a plain solid border everywhere it would
  have appeared.
- `core/shared/widgets/double_back_to_exit_wrapper.dart` — dashboard-root
  double-back-to-exit UX pattern.
- `core/shared/widgets/page_layout.dart` — shared page-chrome widget the
  old app used widely; every migrated page now builds its own
  `Scaffold`/`AppBar` instead.
- `payment/presentation/widgets/confirmation_loading.dart` +
  `wave_glow_loader.dart` — a ripple/glow loading animation on the payment
  confirmation step; migrated pages use a plain loading indicator instead.

**iOS's `CFBundleDisplayName` still reads the starter kit's own template
default ("Mobile"), not `flavors/*.json`'s `APP_NAME`.** Found alongside
the `APP_NAME` fix (2026-07-17, MIGRATION_LOG.md's later findings) —
Android's `productFlavors` already had per-flavor
`resValue("app_name", ...)` infrastructure (just wired to hardcoded
labels instead of the real JSON config, now fixed), so extending it to
read `flavors/*.json` was a same-shape change. iOS has per-flavor Xcode
schemes (`dev`/`staging`/`prod`) but no equivalent
`Info.plist`-per-scheme variable injection was ever set up — building
that (an `.xcconfig` per scheme, `$(APP_DISPLAY_NAME)` substitution in
`Info.plist`) is new infrastructure, not a one-line fix like Android's,
and this migration has never once exercised an iOS build (every session
of live verification used Chrome web or, for this specific fix, a real
Android debug APK). Deferred rather than guessed at.

**`third_party/no_screenshot` is a temporary local vendor patch, not a
permanent fork.** Found/fixed 2026-07-17 (MIGRATION_LOG.md finding
#24) — pub.dev's `no_screenshot` 1.2.0 ships an `android/build.gradle`
whose AGP-9 migration has a real bug (assumes `android.builtInKotlin`
is `true` whenever AGP's major version is `>= 9`, but Flutter's own
template default is `false` — `flutter/flutter#183910`), so this
project vendors a copy with only that one file patched, wired in via
`dependency_overrides` in the workspace-root `pubspec.yaml`. The
package itself is healthy and actively maintained (160 pub points, 280
likes, not discontinued) — this is a stopgap for a landing-day bug in
its latest release, not a maintenance-status replacement. **Action
item**: check pub.dev for a `no_screenshot` release past 1.2.0
whenever this is revisited; the moment upstream genuinely fixes AGP 9
support (verify with a real `flutter build apk`, not just the
changelog claiming it), delete `third_party/no_screenshot`, drop the
`dependency_overrides` entry, and bump `feature_test`'s
`no_screenshot` constraint to that version.

---

## (b) Not tested against a real external system

**Pusher wire-level connection — `counseling`.** *"CATATAN: koneksi Pusher
wire-level tidak diuji terhadap server sungguhan di sandbox ini... logika
reconnect/backoff/filter event sepenuhnya diuji lewat fake gateway."* —
[MIGRATION_LOG.md](MIGRATION_LOG.md) (`counseling` row); full detail in
[docs/qa/counseling.md](docs/qa/counseling.md) § Environment constraints:
*"this sandbox has no Pusher/Soketi test server available, and standing one
up was judged out of proportion to this slice's scope... Not verified: does
`CounselingSocketGatewayImpl` correctly parse a real server's Pusher-protocol
frames, does the real library's `connectionErrorHandler` actually invoke the
callback the way this code assumes."*

**Pusher wire-level connection — `payment`.** *"CATATAN: Pusher wire-level
tidak diuji terhadap server sungguhan di sandbox ini (sama seperti
counseling)..."* — [MIGRATION_LOG.md](MIGRATION_LOG.md) (`payment` row);
[docs/qa/payment.md](docs/qa/payment.md): *"the real-time
`conf.<psychologistId>` channel/event flow is fully exercised through
`PaymentCubit`'s tests against a controllable fake... never against a live
Pusher/Soketi server."*

**`flutter build ipa` + `--dart-define-from-file` — never empirically
re-tested against a real Xcode archive.** Verified during this session
(2026-07-14) against `flutter/flutter#142976` (*"--dart-define-from-file
does not work with flutter build ipa"*): closed 2024-05-23 on an anecdotal
"fixed by upgrading to 3.19.4" report (not a cited PR/commit), and no new
duplicate has been filed since despite 2+ years of `dart-define-from-file`
being in heavy real-world use — high confidence it's resolved on the pinned
3.44.4. But this project still has **no macOS/Xcode toolchain available in
this environment** (same constraint already named for iOS signing generally
— see `flutter_starter_kit`'s `RELEASE.md` §1, which this project doesn't
yet have its own copy of), so the actual `flavors/*.json` +
`--dart-define-from-file` combination has never been run through a real
`flutter build ipa` here. First real iOS release build should double-check
`String.fromEnvironment` values actually loaded, not assume the research.

**Full `apps/mobile` boot outside `flutter_test`'s official test doubles.**
[docs/qa/test.md](docs/qa/test.md): *"booting the full app's
`configureDependencies()`... throws `MissingPluginException` for
`getApplicationDocumentsDirectory`... this time with no official in-memory
test double to swap in."*

**PDF rendering (`feature_history`'s certificate viewer).**
[docs/qa/history.md](docs/qa/history.md): *"PDF rendering can't be exercised
under `flutter_test` at all... This is a real, currently unverified gap —
flagged rather than silently assumed to work."* Also: *"`flutter_test`'s
`TestWidgetsFlutterBinding` globally blocks real `dart:io HttpClient`
requests... not scoped to the fake-async zone, so `tester.runAsync()` alone
does not bypass it."*

**Camera/proctoring/screenshot platform channels.**
[docs/qa/test.md](docs/qa/test.md): *"Camera/proctoring/screenshot themselves
are hardware/platform-channel-backed with no test-host implementation
available here."* Same class of gap for `register`'s KTP/selfie capture —
[docs/qa/register.md](docs/qa/register.md): *"`image_picker`'s actual native
picker call... and `CameraGateway`'s real hardware capture are **not**
unit-testable... only the bare picker/camera invocation is left to manual
verification."*

**Real push-notification delivery on a physical device.**
[docs/qa/dashboard.md](docs/qa/dashboard.md): *"this sandbox has no
Android/iOS device attached (same constraint class as `register.md`'s camera
environment note)."* Same doc: *"The permission-prompt UI itself was not
visually confirmed... the fix is proven at the unit level via `verifyNever`,
not by watching a real Android permission dialog."*

**Screenshot-based UI proof (`about`, `onboarding`).**
[MIGRATION_LOG.md](MIGRATION_LOG.md) (`about` row): *"screenshot-based proof
wasn't possible in this environment (session-isolation + a `toImage()` hang,
both documented there), so evidence is assertion-based against real data
instead."* [docs/qa/about.md](docs/qa/about.md): `toImage()` "hangs
indefinitely in this sandbox"; OS-level GUI automation "can't reach the
interactive desktop from this tool execution context." `onboarding` row:
*"same screenshot-proof environment constraints as `about`."*

---

## (c) Design decisions deliberately different from the old app

**`StatusVoucher` splits the old app's single `PaymentStatus.review`
catch-all into `underReview`/`paid` — but the `'PT'`/`'TP'` literal
abbreviations they're derived from remain unconfirmed.**
[docs/qa/payment.md](docs/qa/payment.md): *"The literal expansion of
`'PT'`/`'TP'` remains unconfirmed — no response example or documentation
text exists to translate them from, only their functional behavior in
`PaymentStateCubit._mapStatus()`. Recorded honestly as unconfirmed rather
than guessed."* Same finding in [MIGRATION_LOG.md](MIGRATION_LOG.md)'s
shared-foundations section.

**Notification tap-to-navigate deep-linking not wired.**
[docs/qa/dashboard.md](docs/qa/dashboard.md): *"`NotificationGateway.
onNotificationTapped`... exists and is exposed, but nothing in `apps/mobile`
subscribes to it yet — a deliberate scope decision, not an oversight...
Rebuilding that table wasn't part of this slice's explicit definition of
done."*

**`UserProfileModel`'s envelope-nesting question — ✅ answered and fixed
2026-07-15, no longer a gap.** Live-backend verification against the real
Development environment confirmed `/auth/me` nests every field under
`data` except `is_regis` (a top-level sibling), and that `role` doesn't
appear in that response at all (sourced from the JWT claim instead) — see
[MIGRATION_LOG.md](MIGRATION_LOG.md) Permanent Finding #10 for the full
mismatch and fix. Left here, not moved to the resolved section below, so
the original open question stays traceable to its answer.

---

## Explicitly not gaps (resolved during the 2026-07-14 reconciliation audit)

Recorded here only so nobody re-discovers these as "still open" from an
earlier reading of this project's history:

- **Access-token refresh** — was a candidate gap (TTL number genuinely
  undeterminable from any accessible source). **Resolved, not accepted**:
  the actual pattern (`RefreshTokenInterceptor`, reactive-on-401) never
  needed the TTL number at all — wired to a real `/auth/refresh` call, see
  [docs/qa/auth_login.md](docs/qa/auth_login.md) and this session's commit
  history (`0c0374a`).
- **Session-restore login-form flash** — was found and fixed for real
  (`apps/mobile/lib/src/app.dart`'s session gate), not accepted as a gap.
  See [docs/qa/home.md](docs/qa/home.md).
- **`AuthInterceptor` never attached to the real `Dio` instance** — a real,
  previously-undiscovered bug (no authenticated request ever sent a Bearer
  token), found and fixed alongside the refresh-token wiring, not a
  documented prior gap. Its methodological root cause is now closed too:
  every feature's own tests mocked the network boundary and only checked
  response handling, never what was actually sent, so nothing could have
  caught this. `apps/mobile/test/auth_header_wiring_test.dart` now proves
  the literal `Authorization: Bearer <token>` header against the real
  DI-wired `Dio` instance — not a mock — and this is recorded as a named
  regression-proof technique in `flutter_starter_kit`'s ARCHITECTURE.md
  §28 ("verify request headers/metadata, not just response content") so
  it doesn't stay a one-off.
- **`feature_counseling`'s "Mulai Tes Kedua" placeholder** — was a stale,
  unrevisited decision (found while compiling this file, see the earlier
  revision of this section), not a consciously-accepted gap. **Fixed
  2026-07-14**: `ChatPage`'s `_EndedBanner` now does real navigation
  (`context.push('/test/$code')`), the exact same route-string pattern
  `feature_history`'s "Lanjutkan Tes" button already used. Proven with a
  real tap-through test against a `GoRouter`-backed harness (not just a
  removed placeholder assertion) — see
  `packages/feature_counseling/test/presentation/pages/chat_page_test.dart`.
- **`apps/mobile`'s `applicationId`/bundle identifiers** — the GAPS.md
  candidate for this (quoting [docs/qa/about.md](docs/qa/about.md): *"give
  `akujamin-v2` its own `applicationId`"*) turned out to already be
  resolved, not an open gap at all: `git log` confirms the real fix landed
  in commit `8996188` (ADR-011's secure-storage-bleed fix), which predates
  `docs/qa/about.md`'s note by several commits — that doc line was simply
  never updated after the fix shipped. Verified directly against the
  current source, not assumed: `com.akujamin.mobile` is the real
  `applicationId`/`namespace` in `build.gradle.kts`, and the real
  `PRODUCT_BUNDLE_IDENTIFIER`/`APPLICATION_ID` on iOS/macOS/Linux, checked
  2026-07-14. `docs/qa/about.md`'s stale line has been corrected to match.

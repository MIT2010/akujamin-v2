# Sensitive-data checklist — `test` (largest, riskiest remaining feature)

Filled in **before writing any test-taking-UI code** — the camera/proctoring
prerequisite has already been built and tested separately (see
MIGRATION_LOG.md's `test` row, permanent finding #7). This is Langkah 3-4
of the feature's audit: a full flow map plus this checklist, both required
before any question/answer/timer/screenshot-block code is written. Every
claim below is grounded in code actually read this session, cited by file —
none of it is assumed.

The side-by-side old-app/new-app behavior checklist (the
`docs/QA_CHECKLIST_TEMPLATE.md` format `about.md`/`onboarding.md`/
`auth_login.md` used) will be **appended to this same file** once the
test-taking UI is built and verified — this file starts as the pre-code
sensitive-data plan and becomes the full QA record.

---

## 1. Inventory of sensitive fields

| Field | Where it appears | Lifetime in old app |
|---|---|---|
| Raw test answers (selected answer IDs, per question) | `saveTestAnswer` request body (`POST /api/pertanyaan/savev2`), a raw JSON string built by `QuestionMapper.toJson()` — `kode_voucher`, `psikologis_id`/`pengetahuan_umums_id`(+`pengetahuan_umum_subs_id`), `jawaban_*_id` | In-memory only client-side (`TestState.answers`, a `Map<String, List<String>>` keyed by `QuestionStep.key`), gone once `TestStateCubit` is disposed. Sent to the server **per question, immediately** on tapping Next — not batched, not cached locally |
| Proctoring face frames (periodic face-match, every ~250ms while attentive) | `POST /api/pertanyaan/face-matchv2`, multipart JPEG bytes converted in-memory from the live `CameraImage` stream (`convertCameraImageToJpeg`) | **Never touches disk.** Confirmed by reading `camera/data/repositories/camera_repo_impl.dart`'s `_startMatch()` in full: it reads `_latestFrame` (an in-memory `CameraImage` held by the live `imageStream` subscription), converts to JPEG bytes, uploads directly. It never calls `CameraDatasourceImpl.captureImage()`/`takePicture()` — the file-writing method permanent finding #4 is about. `feature_test`'s already-built `ProctoringGatewayImpl` inherits the same property (verified: it never calls `CameraGateway.captureImage()` either — that method exists on the gateway but nothing in the proctoring slice calls it) |
| Face-match result (matched/notMatched/error + similarity/confidence score) | Response body of the same `/face-matchv2` call | In-memory only (`FaceDetectorState.matchStatus`), not persisted |
| Exam content itself (questions, answer options, media URLs, intro/instruction text) | Response body of `getTests` (`POST /api/pertanyaan/getv2`) | Held in `TestState.tests` for the session, not persisted. Different sensitivity category from the rows above — exam-integrity/confidentiality, not personal data |
| `kode_voucher` | Present in all three calls above | Already an identifier tracked elsewhere (payment/history) — not new exposure introduced by `test` itself |

## 2. Storage tier

**Nothing in this feature is persisted to local storage at all** — no
`shared_preferences`, no `flutter_secure_storage`, no on-disk cache anywhere
in `test`'s data flow. Everything is in-memory and request-scoped, cleared
when the cubit is disposed. This is the good-baseline case: unlike `auth`'s
tokens or `onboarding`'s flag, there is no storage-tier decision to make for
`test`'s own data.

The one real on-device risk in this feature isn't storage — it's **capture**
(screenshots/screen-recordings of exam content). See §4.

## 3. Transit and logging

**Extends permanent finding #3, doesn't repeat it.** Re-verified directly
against `package:dio` 5.10.0's actual source (`lib/src/form_data.dart`):
`FormData` declares no `toString()` override at all, so
`'Data: ${options.data}'` in the old app's `LoggerInterceptor.onRequest`
only ever prints `Instance of 'FormData'` for a FormData-bodied request —
the same proof already used for `counseling`'s `sendMessage` in finding #3,
now applied to `test`'s own three calls:

- `getTests` — `FormData.fromMap(param)` → **not leaked** by this
  interceptor.
- `saveTestAnswer` — `data: param`, a **raw `String`**, not `FormData` →
  interpolates directly into the log line → **leaked in full, per question,
  on every submit**. This is finding #3's headline case; already recorded,
  not new here.
- `face-matchv2` (the proctoring upload) — `FormData.fromMap({'image': ...})`
  → **not leaked** by the request-side logger. The face image bytes
  themselves are safe from this specific vector.

**New, not previously stated anywhere:** the **response**-side log line
(`logger.d('...Data: ${response.data}')` in `onResponse`) is unconditional —
it fires for every response regardless of how the request was sent. So:

- `face-matchv2`'s response (`match`/`similarity`) — the face-match
  **result**, including the confidence score, is printed to the dev console
  in full. Lower sensitivity than the raw image itself, but still a
  biometric-adjacent value worth naming explicitly rather than assuming
  "FormData is safe" covers the whole call.
- `getTests`'s response — the **entire exam content** (every question,
  section, answer option, across every test) prints to the console on load.
  Different category from personal data (exam-integrity/confidentiality,
  not privacy), but same root cause, same fix.

Same mitigation as finding #3: automatically avoided once `test` goes
through `core`'s body-free `LoggingInterceptor` — no new code needed for
this mechanism. The same rule finding #3 already established applies here
too: never add an ad-hoc debug print of a raw answer/result/exam-content
payload anywhere in this feature's code, even temporarily.

**Transit**: no certificate pinning in the old app (already established
generally in `auth_login.md` §3) — nothing feature-specific to add here.

## 4. Lifecycle — screenshot protection (the real unresolved gap)

**Permanent finding #8, restated here because it's this feature's, not
someone else's.** `DisableScreenshotUsecase`'s only call site
(`TestPage.initState()`) is commented out; `EnableScreenshotUsecase` has
three live call sites (`TestStatus.done`'s handler in `test_page.dart`,
`TestHeader`'s back button, `DoubleBackToExitWrapper.onBack` wired in
`test_routes.dart`). Net effect: **screenshot/screen-recording protection
never actually engages at any point during a live exam in the shipped old
app**, despite all the cleanup code around it existing and working
correctly — a real, shipped regression, not a hypothetical.

Not fixed yet — there is no test-taking UI in this repo to wire it into.
When that UI is built, the migrated version must call the real
disable-on-enter (fixing the bug), not port the commented-out state as-is.

No other lifecycle concern applies here — §2 already established nothing
is persisted, so there's no "clear on logout" question for `test` the way
there was for `auth`'s tokens.

## 5. Explicitly out of scope for this checklist

- `register`/KTP/selfie capture — a separate flow with its own sensitive-data
  checklist (ID document images, a stricter category than proctoring frames)
  when that's migrated. Not folded in here.
- `matchFace`/`TestRepository.matchFace()` — dead code, confirmed via
  exhaustive grep not called from anywhere in the presentation layer, not
  ported.
- Camera+proctoring's own architecture/failure-handling (the
  `CameraFailure` taxonomy, grace-period/violation timing) — covered by
  `packages/shared`'s and `packages/feature_test`'s own automated test
  suites (`camera_gateway_impl_test.dart`, `proctoring_cubit_test.dart`),
  not a sensitive-data question.

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — permanent findings #3
  (logging interceptor), #4 (face-image cleanup — scoped to
  `captureImage()`'s file-writing path, **not** `test`'s own periodic
  match, see §1 above), #7 (`CameraGateway`'s honest-failure fix), #8
  (screenshot gap, unresolved).
- [auth_login.md](auth_login.md) — the original logging-interceptor proof
  pattern (`FormData.toString()`) this file reapplies to `test`'s two
  FormData calls.

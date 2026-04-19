---
phase: 05-gps-session-lifecycle
plan: 03
subsystem: application-layer-orchestration
tags: [riverpod, controller, state-machine, permission-flow, shared-preferences, wave-3, tdd]

# Dependency graph
requires:
  - phase: 05-gps-session-lifecycle
    plan: 01
    provides: "Fix/FixId domain, FixStore port + DriftFixStore impl, LocationStream port, SessionStore.watchAll(), fixStoreProvider, session_settings distance-filter SharedPreferences keys, 5 Phase 05 constants (kDefaultDistanceFilterMeters, kMaxAcceptableAccuracyMeters, kFirstFixTimeoutSeconds, kNotificationChannelId, kSessionActiveBannerHeightDp)"
  - phase: 05-gps-session-lifecycle
    plan: 02
    provides: "LocationStream upgraded to SessionId + required sessionDisplayName, sealed GpsError hierarchy (LocationPermissionDeniedException/LocationServiceDisabledException/TrackingBackgroundKilledException), LocationPermissionOutcome enum, locationStreamProvider, sessionNotificationServiceProvider, oemDetectorProvider"
provides:
  - "ActiveSessionController @Riverpod(keepAlive: true) — GPS session lifecycle orchestrator (start/stop/_onFix/_onStreamError); owns the single StreamSubscription<Fix>"
  - "Sealed ActiveSessionState hierarchy (Idle / Starting / Tracking / ErrorState) with Tracking.copyWith for fixCount+lastFix updates"
  - "requestLocationAlways() top-level pure function — two-step Android 10+ permission chain with PermissionRequester seam; regression-locked against silent-ignore of direct Always"
  - "openLocationSettings() thunk over permission_handler.openAppSettings for deep-link recovery"
  - "sessionSettingsProvider Riverpod Notifier wrapping SharedPreferences — distanceFilter_meters clamped to [2, 100], permission_flow_completed + oem_guidance_seen one-shot flags"
  - "clampDistanceFilterMeters() + kMinDistanceFilterMeters/kMaxDistanceFilterMeters exports for Plan 05-04 slider"
  - "SessionSettingsSnapshot immutable value type for atomic settings reads"
affects: [05-04-settings-ui, 05-05-session-ui, 05-06-auto-resume]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ProviderContainer + override fakes for controller tests: every infrastructure port replaced via `providerName.overrideWith` so the controller exercises its full code path without touching AppDatabase/geolocator/flutter_local_notifications"
    - "PermissionRequester typedef seam: `Future<PermissionStatus> Function(Permission)` defaults to `(p) => p.request()`; tests inject a closure that records the order + returns programmed statuses without needing PermissionHandlerPlatform overrides"
    - "Controller error policy: GpsError variants flip state to ErrorState + rethrow; non-GpsError (ConcurrentActivationException, ...) propagate untyped via Riverpod's AsyncError so the UI layer applies its own recovery policy (stop()+start() for concurrent activation)"
    - "AsyncValue.value (not valueOrNull) — Riverpod 3.x API; the Riverpod-2 valueOrNull getter no longer exists. State read in _onFix uses `state.value` and checks `is Tracking`"
    - "SharedPreferences-backed Riverpod Notifier with Future<T> build + setters that persist-then-update-state: every mutation goes through setInt/setBool + state = AsyncData(current.copyWith(...))"

key-files:
  created:
    - "lib/application/state/active_session_state.dart"
    - "lib/application/controllers/active_session_controller.dart"
    - "lib/application/controllers/README.md"
    - "lib/application/permissions/location_permission_flow.dart"
    - "lib/application/permissions/README.md"
    - "lib/application/providers/session_settings_provider.dart"
  modified:
    - "test/application/controllers/active_session_controller_test.dart (skip-stub -> 8 GREEN tests)"
    - "test/application/permissions/location_permission_flow_test.dart (skip-stub -> 6 GREEN tests)"

key-decisions:
  - "ActiveSessionController builds synchronously (returns Idle()) with DB/settings resolution lazy inside start() — fast first frame + no UI spinner on app boot. Async cost only paid on the first user-initiated start(). Matches 05-CONTEXT.md wiring option (a)."
  - "start() DB-first ordering: sessionStore.activate(id) FIRST, then sessionStore.requireById(id) to hydrate displayName for the notification title, then notification init, then subscription. Failures at activate() (ConcurrentActivationException) surface BEFORE any subscription state is wired — nothing to tear down on error."
  - "SessionStore.activate(SessionId) returns Future<void> (not Session) per the Phase 03 contract; plan pseudocode showed Future<Session>. Controller uses requireById(id) after activate() to fetch the displayName. Two round-trips but both against an in-memory Drift connection; cost negligible."
  - "ConcurrentActivationException propagates untyped via AsyncError (NOT as ErrorState(GpsError)) — domain-level exception, not GPS error. UI (Plan 05-04) pattern-matches `asyncValue.error is ConcurrentActivationException` to trigger its stop()+start() chain. Keeps the controller a pure state machine (no policy)."
  - "cancelOnError: false on the subscription — a single recoverable GpsError (permission revoked, service disabled) flips state to ErrorState but leaves the subscription alive so the UI can surface + recover without a full stop/start cycle. The subscription is only torn down by explicit stop() or when the controller is disposed."
  - "stop() is best-effort on dismiss + deactivate — notification dismiss and DB deactivate failures are logged-and-swallowed. Once the user tapped Stop, state MUST settle to Idle regardless of housekeeping outcomes."
  - "PermissionRequester typedef seam (not a wrapper class / not a Permission subclass) — permission_handler's `Permission.locationWhenInUse` is a `const PermissionWithService._(5)` instance; subclassing is not possible. A `Future<PermissionStatus> Function(Permission)` closure is the narrowest seam that lets tests record invocations without pulling in PermissionHandlerPlatform test channels."
  - "Regression test `neverRequestsAlwaysIfWhenInUseNotGrantedFirst` — locks the Android-10+ silent-ignore pitfall. Plan 05-02 flagged this in 05-RESEARCH.md Pattern 3; now it's a test guard that fails loudly if the two-step chain is ever collapsed to a direct Always request."
  - "sessionSettingsProvider exposes an immutable SessionSettingsSnapshot (not three discrete providers) — the controller's initialization path awaits once and gets everything. Setter methods persist THEN update state; subscribers see new values on the next microtask."
  - "clampDistanceFilterMeters hoisted to a top-level function + exposed as const min/max — reusable by Plan 05-04's slider UI which also needs to clamp before writing, and by Plan 05-05 / future callers that read user-entered values."

patterns-established:
  - "ProviderContainer(overrides: [provider.overrideWith((ref) async => fake)]) test rig — every dependency Future is made sync-resolvable by returning the fake directly; sync providers use overrideWith((ref) => fake). Pattern scales to every future Riverpod controller test."
  - "Hand-rolled fakes (implements Port) with public recording fields (activatedIds: List<SessionId>, inserts: List<Fix>, initializeCount: int) — no mockito/mocktail, matches Phase 03 store-test convention. Fakes live inside the test file unless reuse across multiple tests is proven."
  - "PermissionRequester seam: typedef-based injection for platform-plugin functions that return Futures of enum-like values. Applicable to any permission_handler / url_launcher / share_plus / image_picker flow."
  - "Controller state.value pattern-match (not is-chain on AsyncValue) — read state.value once, check Dart type pattern-match. Riverpod 3.x API is cleaner than 2.x when you already know the sealed state type."

requirements-completed:
  - SESS-04
  - SESS-05
  - GPS-01
  - GPS-02
  - GPS-04

# Metrics
duration: "~10 min"
completed: 2026-04-19
---

# Phase 05 Plan 03: Permission Flow + ActiveSessionController Summary

**The application-layer orchestrator stitching Plan 05-01 (persistence) and Plan 05-02 (platform plumbing) together: `ActiveSessionController` owns the GPS lifecycle, the sealed `ActiveSessionState` hierarchy, and the two-step Android 10+ permission flow. Plan 05-04 UI now has a clean controller + sealed state to watch and dispatch to.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-19T10:04:41Z
- **Completed:** 2026-04-19T10:14:44Z
- **Tasks:** 2
- **Files created:** 6 (controller + state + permission flow + settings provider + 2 READMEs)
- **Files modified:** 2 (turning Wave-0 skip-stubs into GREEN tests)
- **Commits:** 2 (`110daf7`, `dd7c863`)

## Accomplishments

- **`ActiveSessionController`** @Riverpod(keepAlive: true) orchestrating Idle -> Starting -> Tracking -> Idle | ErrorState state machine. 8 GREEN tests cover every transition including the Android-silent-ignore regression and `ConcurrentActivationException` propagation.
- **Sealed `ActiveSessionState`** hierarchy — `Idle` / `Starting(sessionId)` / `Tracking(...)` / `ErrorState(GpsError)`. `Tracking.copyWith` lets `_onFix` bump `fixCount` + `lastFix` without re-allocating session-level fields.
- **`requestLocationAlways()`** — pure top-level function implementing the two-step Android 10+ chain verbatim per 05-RESEARCH Pattern 3. `PermissionRequester` typedef seam enables testing without platform channels; 6 GREEN tests including the `neverRequestsAlwaysIfWhenInUseNotGrantedFirst` regression guard.
- **`sessionSettingsProvider`** Riverpod Notifier wrapping SharedPreferences — `distanceFilter_meters` clamped to `[2, 100]`, `permission_flow_completed` + `oem_guidance_seen` one-shot flags. Setters persist then update state atomically.
- **14 total tests GREEN** (8 controller + 6 permission) — 2 Wave-0 skip-stubs from Plan 05-01 turned GREEN.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ActiveSessionState + SessionSettings provider + permission flow | `110daf7` | 7 files (5 new + 1 test turned green + 1 regenerated .g.dart) |
| 2 | ActiveSessionController + 8 controller tests green | `dd7c863` | 23 files (3 new + 1 test turned green + 19 format-aligned .g.dart) |

## ActiveSessionController State Machine

```
                    ┌─────────────┐
                    │    Idle     │ ◄─────── initial, post-stop()
                    └──────┬──────┘
                           │ start(id)
                           ▼
                    ┌─────────────┐
                    │  Starting   │  DB.activate + notif.initialize + subscribe
                    └──────┬──────┘
                           │ subscription live
                           ▼
                    ┌─────────────┐ ◄──┐
           ┌────────│  Tracking   │    │ _onFix: persist + increment
           │        └──────┬──────┘────┘
           │               │
           │               │ stream emits GpsError
           │               ▼
           │        ┌─────────────┐
           │        │  ErrorState │  subscription alive for recovery
           │        └──────┬──────┘
           │               │ stop() (or another start())
           │ stop()        │
           ▼               ▼
                    ┌─────────────┐
                    │    Idle     │
                    └─────────────┘
```

**Concurrent activation:** when another code path holds the partial-unique-index on `t_sessions.status='active'`, `sessionStore.activate(id)` throws `ConcurrentActivationException`. The controller propagates this untyped (NOT as ErrorState — it's a domain exception, not a GPS error). The UI layer catches it and applies its stop-current-first policy.

## Design Decision — UI, Not Controller, Handles "Start Auto-Stops Current Session"

From 05-CONTEXT.md §UI rules: "Start d'une autre session = stop auto de l'active (SESS-06 DB partial unique index déjà enforced Phase 03, maintenant testé end-to-end)".

The plan made this a **UI-layer** concern rather than a controller concern:

- `ActiveSessionController.start(id)` is a pure state-machine operation. It activates the id; if the DB refuses (`ConcurrentActivationException`), the controller surfaces that as `AsyncError` and rethrows.
- `SessionListScreen` in Plan 05-04 catches `ConcurrentActivationException`, calls `controller.stop()` (which deactivates the current session), then retries `controller.start(id)` for the newly-requested session.
- This keeps the "stop current first" policy at the **UX decision boundary** (the screen that initiated the new-session tap) rather than embedding it in the orchestrator.
- Reusable pattern for Plan 05-06's auto-resume — if a resume notification fires while another session is active, the same UI policy applies.

Alternative considered: controller internally chains `stop()` + `start()` on `ConcurrentActivationException`. Rejected — would hide a two-step state transition inside what callers expect to be atomic; harder to test; mixes orchestration with policy.

## Permission Flow Contract + Testing Strategy

**Contract:**

```dart
Future<LocationPermissionOutcome> requestLocationAlways({
  PermissionRequester requestPermission = _defaultRequestPermission,
});
```

Returns one of four `LocationPermissionOutcome` values. Never throws.

**Two-step chain:**
1. Request `Permission.locationWhenInUse`:
   - Granted → proceed to step 2.
   - Denied → return `LocationPermissionOutcome.denied` (re-request allowed).
   - Permanently denied → return `LocationPermissionOutcome.permanentlyDenied` (deep-link required).
2. Request `Permission.locationAlways`:
   - Granted → return `LocationPermissionOutcome.granted` (full background).
   - Denied → return `LocationPermissionOutcome.whileInUseOnly` (foreground-only).
   - Permanently denied → return `LocationPermissionOutcome.permanentlyDenied`.

**Regression invariant:** step 2 MUST NOT execute unless step 1 returned `granted`. Android 10+ silently ignores a direct `Permission.locationAlways.request()` — returns `denied` without showing a prompt. The `neverRequestsAlwaysIfWhenInUseNotGrantedFirst` test locks this in: it asserts the `PermissionRequester` fake received exactly one call with `Permission.locationWhenInUse`.

**Testing without flutter_test's binding:** the `PermissionRequester` typedef is the injection point. Tests pass a closure that:
1. Records every `Permission` it's called with.
2. Returns programmed `PermissionStatus` values per `Permission`.

No widget-test binding, no `PermissionHandlerPlatform` test channels, no MethodChannel mocks. Runs under `flutter test` only because `PermissionStatus` is exported from the Flutter plugin (the plugin ships with the `flutter_test` SDK transitively via its platform channels), but no binding is required.

## SessionSettings SharedPreferences Keys Inventory

| Key                          | Type   | Default                         | Clamp        | Owner             |
|------------------------------|--------|----------------------------------|---------------|-------------------|
| `distanceFilter_meters`      | int    | `kDefaultDistanceFilterMeters=5` | `[2, 100]`    | User (slider P5-04)|
| `permission_flow_completed`  | bool   | `false`                          | —             | Controller (set once at grant) |
| `oem_guidance_seen`          | bool   | `false`                          | —             | UI (set once after guidance screen dismissed) |

Namespace-free flat keys match Phase 01 convention (see `debug_menu_screen`). Deliberate: if a future schema bump migrates these keys, a single `prefs.migrate()` function can rename them in one place without touching a namespace prefix.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan pseudocode: `sessionStore.activate(id)` returns `Future<Session>`, but actual contract is `Future<void>`**
- **Found during:** Task 2 (writing controller `start()`)
- **Issue:** Plan 05-03-PLAN.md's action snippet had `final activated = await sessionStore.activate(id);` and then `sessionDisplayName: activated.displayName`. The real `SessionStore.activate` (Phase 03, `lib/domain/sessions/session_store.dart:50`) returns `Future<void>`.
- **Fix:** After `await sessionStore.activate(id)`, call `await sessionStore.requireById(id)` to hydrate the `Session` row for `displayName` + `startedAtUtc`. Two round-trips on the in-memory Drift connection; cost negligible.
- **Files modified:** `lib/application/controllers/active_session_controller.dart`.
- **Verification:** `startTransitionsToTracking` test green — `locationStream.capturedDisplayName == 'Balade de test'`.
- **Committed in:** `dd7c863`.

**2. [Rule 1 - Bug] `AsyncValue.valueOrNull` does not exist in Riverpod 3.x**
- **Found during:** Task 2 first compile
- **Issue:** Plan pseudocode used `state.valueOrNull`. The Riverpod 2.x `valueOrNull` getter was renamed/collapsed in Riverpod 3.x — `AsyncValue.value` is now directly nullable (`ValueT? get value`). `valueOrNull` simply doesn't exist on `AsyncValue<T>`.
- **Fix:** Swapped `state.valueOrNull` for `state.value` in the controller's `_onFix` and in every test's state-read assertion. Added a comment documenting the Riverpod-3 API.
- **Files modified:** `lib/application/controllers/active_session_controller.dart`, `test/application/controllers/active_session_controller_test.dart`.
- **Verification:** `flutter analyze` clean; 8 controller tests green.
- **Committed in:** `dd7c863`.

**3. [Rule 3 - Blocking] `avoid_redundant_argument_values` on `lastFix: null` + `prefer_const_constructors` on `SessionId('sess_...')` in tests**
- **Found during:** Task 2 post-implementation `flutter analyze`
- **Issue:** `Tracking.lastFix` is nullable with default `null` — passing `lastFix: null` explicitly was flagged. Test fixtures used `final sessionId = SessionId('sess_...')` which the linter flagged as `prefer_const_constructors` (extension-type `SessionId.value` is const-compatible).
- **Fix:** Dropped the explicit `lastFix: null` on the `Tracking()` construction in `start()`. Switched test `final sessionId` to `const sessionId` (sed replace across 7 test cases). Also removed an unused `session_settings_provider` import from the controller test.
- **Files modified:** `lib/application/controllers/active_session_controller.dart`, `test/application/controllers/active_session_controller_test.dart`.
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` → `No issues found!`
- **Committed in:** `dd7c863`.

**4. [Rule 3 - Blocking] Project-wide `dart format --line-length 160` drift on 20 .g.dart files**
- **Found during:** Task 2 (post-codegen CI-equivalent check)
- **Issue:** Same pattern documented in 05-01-SUMMARY Deviation #7 — CI runs `dart format --line-length 160 --set-exit-if-changed .`; `dart_style` output from `riverpod_generator` / `freezed` / `json_serializable` / `drift_dev` drifted from what the project's format gate expects on a sub-line-length boundary. Running build_runner from scratch emits multi-line `extends $FunctionalProvider<A, B, C>` whereas `dart format --line-length 160` reflows to a single line when under 160 chars.
- **Fix:** Ran `dart format --line-length 160 .` project-wide. No semantic changes — pure whitespace alignment across 20 generated files.
- **Files modified:** 19 .g.dart files across `lib/application/`, `lib/domain/`, `lib/infrastructure/`, `lib/presentation/` + 1 session_settings_provider.g.dart we generated in Task 1.
- **Verification:** `dart format --line-length 160 --set-exit-if-changed .` clean (modulo non-Dart test fixtures).
- **Committed in:** `dd7c863`.

---

**Total deviations:** 4 auto-fixed (2 × Rule 1 bugs in plan pseudocode + Riverpod-3 API, 2 × Rule 3 blocking on analyzer/format gates).

**Impact on plan:** All four are mechanical corrections to plan-level or upstream-library drift. #1 is the most notable — the plan's pseudocode was copied from 05-RESEARCH.md Pattern 2 which predates the Phase 03 `activate() -> Future<void>` contract finalization. The `requireById` round-trip is a small cost and a cleaner shape (controller doesn't conflate activation with hydration).

## Issues Encountered

None blocking. Every deviation resolved inline.

**Out-of-scope pre-existing issues observed during test runs (NOT fixed — belong to prior phases):**
- `test/infrastructure/gps/geolocator_location_stream_test.dart` fails under pure `dart test` (imports `flutter_test` transitively which requires the Flutter SDK's `dart:ui` Color/Rect — absent in the pure-Dart runner). Passes under `flutter test`. Pre-existing from Plan 05-02 Task 1 — the file is in the pure-Dart test dir but must run under `flutter test`. CI's `gates` job scopes `dart test` to `test/domain/` + `test/infrastructure/` so this is a latent issue: `flutter analyze` passes, but any future attempt to include `test/infrastructure/gps/` in the `dart test` glob would fail. Out-of-scope for Plan 05-03.
- `test/infrastructure/db/backup_test.dart::rotate` occasionally fails on Windows with `PathNotFoundException` on the `.tmp` workfile. Pre-existing Phase 04 test — identified as architectural flakiness in the Phase 04 review gate (stat-vs-filename ordering), but the Windows-specific `.tmp` delete race is a separate failure mode. Not caused by Plan 05-03; logged for a future phase fix.

## User Setup Required

None — no new dependencies, no native platform changes, no new SDK tooling. SharedPreferences is already pinned + audited; `permission_handler` + `permission_handler_platform_interface` are Phase 01 dependencies already in `pubspec.yaml` + `DEPENDENCIES.md`.

## Handoff Notes for Downstream Plans

### Plan 05-04 (Settings + End-to-end UI)

Available from this plan:
- **`activeSessionControllerProvider`** — UI watches with `ref.watch(activeSessionControllerProvider)`. Returns `AsyncValue<ActiveSessionState>`. Pattern-match exhaustively on the sealed `ActiveSessionState`:
  ```dart
  ref.watch(activeSessionControllerProvider).when(
    data: (state) => switch (state) {
      Idle() => const IdleSessionView(),
      Starting(:final sessionId) => StartingSessionView(sessionId: sessionId),
      Tracking(:final sessionId, :final fixCount, :final lastFix, :final distanceFilterMeters) =>
        TrackingDashboardView(sessionId: sessionId, fixCount: fixCount, lastFix: lastFix, distanceFilterMeters: distanceFilterMeters),
      ErrorState(:final error) => GpsErrorRecoveryView(error: error),
    },
    loading: () => const CircularProgressIndicator(),
    error: (err, st) => err is ConcurrentActivationException
      ? SwitchSessionPrompt(attemptedId: err.attemptedId)
      : UnexpectedErrorView(error: err),
  );
  ```
- **`requestLocationAlways()`** — PermissionRationaleScreen's "Continuer" button dispatches to this. Branch on the returned `LocationPermissionOutcome`:
  - `granted` → markPermissionFlowCompleted() + start session.
  - `whileInUseOnly` → warn dialog + offer start anyway.
  - `denied` → navigate `/permissions/denied`.
  - `permanentlyDenied` → navigate `/permissions/denied` with deep-link CTA.
- **`openLocationSettings()`** — PermissionDeniedScreen's "Ouvrir les paramètres" button.
- **`sessionSettingsProvider`** — watch with `ref.watch(sessionSettingsProvider)` on the settings slider; write with `ref.read(sessionSettingsProvider.notifier).setDistanceFilterMeters(value)`. Clamp `[2, 100]` is applied automatically.
- **`clampDistanceFilterMeters()` + `kMinDistanceFilterMeters=2` + `kMaxDistanceFilterMeters=100`** — exposed for the Slider's min/max.

### Plan 05-05 (Session UI)

- **SessionListScreen "Start" tap flow:**
  1. If `sessionSettings.permissionFlowCompleted == false` → navigate `/permissions/rationale`.
  2. Else: `controller.start(sessionId)` directly.
  3. Catch `ConcurrentActivationException(attemptedId: x)` → `controller.stop()` + retry `controller.start(x)`.
- **SessionDetailScreen "Stop" tap flow:** just `controller.stop()`; the controller handles subscription cancellation + notification dismiss + DB deactivate.
- **Active-session cross-route banner:** watches `activeSessionControllerProvider`; shows only when state is `Tracking`.

### Plan 05-06 (Auto-resume + store review)

- **ConcurrentActivationException propagation pattern** established here — Plan 05-06's BOOT_COMPLETED receiver can reuse the same "catch + stop + retry" shape when auto-resume fires against a session that was already reactivated by another path.
- **ErrorState(GpsError)** — Plan 05-06 watchdog can directly `state = AsyncData(ErrorState(TrackingBackgroundKilledException()))` without touching the subscription; the UI already knows how to render this.

## Next Phase Readiness

- **Application-layer orchestration complete.** ActiveSessionController + ActiveSessionState + permission flow + sessionSettings — all green.
- **14 tests GREEN** (8 controller + 6 permission) — 2 Wave-0 skip-stubs turned GREEN.
- **Sealed state hierarchy exhaustively matchable** — Plan 05-04 UI benefits from compile-time exhaustiveness.
- **No new dependencies added** — pubspec untouched; DEPENDENCIES.md untouched.
- **Known carryovers:**
  - `test/infrastructure/gps/geolocator_location_stream_test.dart` runner-scope mismatch (Plan 05-02 artifact, not P05-03).
  - `backup_test.dart::rotate` Windows `.tmp` race (Phase 04 flakiness, not P05-03).

---
*Phase: 05-gps-session-lifecycle*
*Completed: 2026-04-19*

## Self-Check: PASSED

- lib/application/state/active_session_state.dart: FOUND
- lib/application/controllers/active_session_controller.dart: FOUND
- lib/application/controllers/README.md: FOUND
- lib/application/permissions/location_permission_flow.dart: FOUND
- lib/application/permissions/README.md: FOUND
- lib/application/providers/session_settings_provider.dart: FOUND
- Commit 110daf7: FOUND
- Commit dd7c863: FOUND

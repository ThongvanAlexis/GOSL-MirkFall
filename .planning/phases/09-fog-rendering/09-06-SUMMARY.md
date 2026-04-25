---
phase: 09-fog-rendering
plan: 06
subsystem: reveal-streaming
tags: [riverpod, family-provider, gps-stream, reveal-pipeline, session-lifecycle, fog-of-war]

# Dependency graph
requires:
  - phase: 09-fog-rendering
    provides: computeRevealMask geometry kernel (plan 09-03), activeMirkRendererProvider + builtinMirkStylesProvider + factory (plan 09-05), Session.mirkStyleId Freezed field (plan 09-05 Task 0)
  - phase: 05-gps-session-lifecycle
    provides: ActiveSessionController + LocationStream port + GeolocatorLocationStream impl (plan 05-02/05-03)
  - phase: 03-persistence-domain-models
    provides: RevealedTileStore.mergeMask + DriftRevealedTileStore + SessionStore + DriftSessionStore (plan 03-06)
provides:
  - "RevealStreamingController — buffers GPS fixes; flushes on count (20) or interval (2 s) trigger; per-fix reveal writes via computeRevealMask + RevealedTileStore.mergeMask; dispose() flushes pending"
  - "revealStreamingControllerProvider(SessionId) — family-style @riverpod returning a session-scoped controller; intentionally NOT keepAlive; ref.onDispose flushes remaining fixes"
  - "MirkStyleSessionController — per-session style picker target; persists t_sessions.mirk_style_id + invalidates activeMirkRendererProvider; defensive throw on unknown style / missing session"
  - "mirkStyleSessionControllerProvider — @Riverpod(keepAlive: true) wrapping the controller with sessionStore + styleStore + ref.invalidate(activeMirkRendererProvider)"
  - "SessionStore.updateMirkStyle({sessionId, mirkStyleId?}) — narrow column write bypassing full row read-modify-write; throws SessionNotFoundException on 0 rows"
  - "LocationStream.lastKnownFix — Fix? getter on the port; populated on every accepted GeolocatorLocationStream emission; survives dispose() for short-reconnect"
  - "MirkStyleNotFoundException + NoActiveSessionException — defensive exception types for the style-swap flow (CLAUDE.md §Error handling level 2)"
  - "ActiveSessionController.start() initial-reveal hook — fast path (cached lastKnownFix → revealInitial immediately) + slow path (first incoming fix triggers revealInitial via _onFix)"
  - "ActiveSessionController.stop() reveal flush — drains pending buffered fixes + invalidates the family-provider slot before settling Idle, no data loss on session end"
affects:
  - plan 09-07 (MirkOverlay — visible-tile snapshot consumer of the reveal pipeline; MirkStylePickerSheet calls mirkStyleSessionControllerProvider.select; reveal data flows to MirkRenderer.paint via this plan's mergeMask writes)
  - plan 09-08 (50k-tile perf probe seeds reveal data via this plan's RevealStreamingController + read-back via existing RevealedTileStore APIs)
  - phase 11 (markers under-mirk MARK-07 read the same revealed bitmap state shipped by this plan)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Family-style @riverpod for session-scoped controllers — avoids circular-watch when both directions need to read each other; caller resolves the family key from upstream state at the call site"
    - "Best-effort flush + invalidate in stop() — writes pending fixes BEFORE the Idle transition + invalidates the family slot to dispose the controller before next start() races a brand-new instance"
    - "Initial-reveal fast/slow path — cached LocationStream.lastKnownFix triggers revealInitial in start(); absent cache defers to first-fix in _onFix. Both paths guarded by _initialRevealDone bool"
    - "Per-tile mergeMask error tier — single-tile DB write failure logs + continues; whole-batch failure would drop later tiles' reveal data and cost more than one tile's update"
    - "Renderer invalidation via injected callback — MirkStyleSessionController takes void Function() invalidateRenderer in constructor DI; tests substitute a counter without a ProviderContainer"
    - "lastKnownFix cache survives dispose() — port doc explicitly allows short-reconnect scenarios; consumers MUST still null-check"

key-files:
  created:
    - lib/application/providers/mirk_style_session_controller_provider.dart
    - lib/application/providers/mirk_style_session_controller_provider.g.dart
    - test/application/controllers/active_session_controller_initial_reveal_test.dart
  modified:
    - lib/application/controllers/reveal_streaming_controller.dart
    - lib/application/controllers/mirk_style_session_controller.dart
    - lib/application/controllers/active_session_controller.dart
    - lib/application/controllers/active_session_controller.g.dart
    - lib/application/providers/reveal_streaming_controller_provider.dart
    - lib/application/providers/reveal_streaming_controller_provider.g.dart
    - lib/domain/sessions/session_store.dart
    - lib/domain/gps/location_stream.dart
    - lib/infrastructure/stores/drift_session_store.dart
    - lib/infrastructure/gps/geolocator_location_stream.dart
    - test/application/controllers/reveal_streaming_controller_test.dart
    - test/application/controllers/mirk_style_session_controller_test.dart
    - test/application/controllers/active_session_controller_test.dart
    - test/application/providers/active_mirk_renderer_provider_test.dart
    - test/infrastructure/gps/geolocator_location_stream_test.dart
    - test/infrastructure/platform/boot_completed_watchdog_test.dart
    - test/presentation/screens/session_list_screen_test.dart
    - test/smoke_test.dart
    - test/helpers/fake_location_stream.dart
  deleted:
    - test/domain/compute_reveal_mask_no_callers_test.dart

key-decisions:
  - "revealStreamingControllerProvider is family-style on SessionId (not session-watching) — a dedicated `watch(activeSessionControllerProvider)` would have created a circular dependency since ActiveSessionController._onFix and stop() now READ this provider. Caller resolves the active session id from controller state at the call site. Trade-off: callers must pass the id; benefit: no circular-detection runtime error."
  - "SessionStore.updateMirkStyle is a narrow column write — bypasses _toInsertCompanion (which would require a full Session read first). Drift impl uses SessionsCompanion(mirkStyleId: Value(...)) directly. Throws SessionNotFoundException on 0 rows for symmetric semantics with activate/deactivate (Phase 03 Batch G finding #3)."
  - "MirkStyleSessionController takes invalidateRenderer as a constructor callback — keeps the controller a plain Dart class with constructor DI (CLAUDE.md §Dependency Injection). Tests inject a counter; production wires `() => ref.invalidate(activeMirkRendererProvider)`. The provider is the injection seam, not Ref."
  - "_initialRevealDone bool tracked on the controller — guards against double-firing the 20 m disc seed when both fast path (cached lastKnownFix) and slow path (first incoming fix) could compete. Reset to false in stop() so the next start() seeds again."
  - "stop() invalidates the family-provider slot AFTER flush — manual flush before invalidate guarantees the buffer drains BEFORE next start() can race with a fresh controller instance for the same sessionId. Provider's onDispose also calls dispose() which itself flushes; the manual flush is defense-in-depth for a clean ordering invariant."
  - "Per-tile mergeMask failure is log-and-continue (CLAUDE.md §Error handling level 2) — losing one tile's data is strictly better than losing all subsequent tiles' data on the same fix's batch. The batched-flush model amplifies the cost of propagating a single failure."
  - "FakeLocationStream.emit() now also primes _lastKnownFix — keeps the test fake congruent with GeolocatorLocationStream's production behaviour. New setLastKnownFix(fix) helper for the cache-before-listen test path."
  - "Removed test/domain/compute_reveal_mask_no_callers_test.dart — Phase 04 scope guard whose docstring (\"guard temporaire jusqu'à Phase 09\") explicitly declared it should be deleted when Phase 09 lands. Plan 09-03 was supposed to remove it but didn't; plan 09-06's RevealStreamingController is the first real caller of computeRevealMask outside its definition site, so the guard now blocks the green build."

patterns-established:
  - "Family-style controller provider for session-scoped state when bidirectional read is needed (controller A reads provider B which is per-session-of-controller-A). Avoids circular-watch via family key on the upstream state's identifier."
  - "Initial-reveal fast/slow path with idempotent boolean guard — applies to any session-scoped one-shot side-effect that can be triggered by multiple sources (cache hit OR first emission)."
  - "Best-effort + invalidate in lifecycle methods — flush before invalidate to enforce ordering when a destructor needs to run BEFORE a new instance can be constructed. Pairs with @riverpod ref.onDispose handlers that also flush (defense-in-depth)."

requirements-completed: [MIRK-01, MIRK-02, MIRK-07]

# Metrics
duration: ~34 min
completed: 2026-04-25
---

# Phase 09 Plan 06: Reveal Streaming Controller + Mirk Style Session Controller + ActiveSessionController wire-up — Summary

**Three controller-layer artefacts that complete the runtime reveal pipeline (GPS fix → reveal mask → DB) and the in-session style-swap path. Plus port extensions for the LocationStream `lastKnownFix` cache and the SessionStore `updateMirkStyle` narrow-column write.**

## Performance

- **Duration:** ~34 min
- **Started:** 2026-04-25T06:27:42Z
- **Completed:** 2026-04-25T07:01:10Z
- **Tasks:** 4 (Tasks 1–4 from the plan, all TDD-tagged)
- **Files modified/created:** 22 (3 created + 19 modified + 1 deleted)
- **Commits:** 4 atomic commits (one per task)

## Accomplishments

- **RevealStreamingController landed (Task 1).** Buffers GPS fixes; flushes on count (`kRevealFlushMaxFixes` = 20) or interval (`kRevealFlushIntervalSeconds` = 2 s) trigger, first-to-fire wins. Per-fix reveal radius `kDefaultRevealRadiusMeters` = 25 m. `revealInitial(fix)` bypasses the buffer and writes a `kInitialRevealRadiusMeters` = 20 m disc immediately. `dispose()` flushes pending buffered fixes synchronously before returning. Per-tile `mergeMask` failure is logged and the batch continues (CLAUDE.md §Error handling level 2). 9 tests cover all 7 plan-declared behaviour items.

- **MirkStyleSessionController + SessionStore.updateMirkStyle (Task 2).** `select(sessionId, styleId)` persists `t_sessions.mirk_style_id` via the new narrow-column write path, then invokes the injected `invalidateRenderer` callback (production: `() => ref.invalidate(activeMirkRendererProvider)`). Same-style reselect is a no-op (no DB write, no invalidate). Defensive `MirkStyleNotFoundException` + `NoActiveSessionException` throws for missing rows. 6 controller tests; 5 SessionStore-fake test files extended with `updateMirkStyle` stub.

- **LocationStream.lastKnownFix port extension (Task 3 — resolves revision S1).** `Fix? get lastKnownFix` added to the abstract port. `GeolocatorLocationStream._lastKnownFix` cache populated on every accepted emission (after accuracy + stationary-dedup filters). Cache survives `dispose()` for short-reconnect scenarios — port doc explicitly notes this. `FakeLocationStream.emit()` updated to prime the cache; new `setLastKnownFix(fix)` helper for cache-before-listen test path. 4 new tests (null-before-emit, populate-on-accept, no-update-on-reject, survive-dispose).

- **ActiveSessionController wiring (Task 4 — Phase 05 LIVE FILE extension).** Three surgical edits in the existing production controller (NOT a Wave 0 scaffold rewrite):
  - **start() initial-reveal fast path** — if `locationStream.lastKnownFix` is non-null, fire `revealInitial` immediately on the cached fix. Otherwise the slow path defers to the first incoming fix.
  - **_onFix() forwarding + slow-path trigger** — every accepted fix is forwarded to `RevealStreamingController.onFix()` for batched 25 m writes. First fix on a slow-path start also fires `revealInitial`. Guarded by `_initialRevealDone` bool to prevent double-firing.
  - **stop() reveal-pipeline flush** — drains pending buffered fixes + invalidates the family-provider slot BEFORE the state transition to `Idle`, ensuring no data loss + clean disposal ordering before any next `start()`.

  4 new tests in `active_session_controller_initial_reveal_test.dart` cover both paths + multi-tile flush + stop-flushes. All 13 existing Phase 05 `active_session_controller_test.dart` tests still green.

- **Family-style provider refactor.** `revealStreamingControllerProvider` promoted to family-style (keyed by `SessionId`) so it no longer `watch`es `activeSessionControllerProvider` — that watch would create a circular dep since `ActiveSessionController` itself reads the reveal provider in `_onFix` and `stop()`. Callers now resolve the active session id from controller state at the call site.

## Provider wiring diagram

```
                                    +-----------------------------------+
                                    | activeSessionControllerProvider   |
                                    | (Phase 05 live)                   |
                                    +------+----------------------------+
                                           |
                          state -> Tracking(sessionId) | state -> Idle
                                           |
                                    .start(id)         .stop()
                                           |               |
                                           v               v
            +-------------------------------+    +-----------------------+
            | revealStreamingController     |    | revealStreamingCtrl   |
            | Provider(sessionId)           |    | (.flush() then        |
            | — family slot per session id  |    |  ref.invalidate(slot))|
            +---------------+---------------+    +-----------------------+
                            |
                            v (depends_on)
            +-------------------------------+
            | revealedTileStoreProvider     |
            | (Phase 03)                    |
            +-------------------------------+

  Style-swap path (orthogonal to the GPS fix flow):

            +-------------------------------+
            | mirkStyleSessionController    |
            | Provider                      |
            | (await both stores then build)|
            +---------------+---------------+
                            |
                            v select(sessionId, styleId)
            +-------------------------------+
            | sessionStore.updateMirkStyle  |   then
            | (Drift narrow column write)   | -------> ref.invalidate(activeMirkRendererProvider)
            +-------------------------------+
```

## Task Commits

1. **Task 1: RevealStreamingController + provider + 9 tests** — `3449bb9` (feat)
2. **Task 2: MirkStyleSessionController + SessionStore.updateMirkStyle** — `d09679f` (feat)
3. **Task 3: LocationStream.lastKnownFix port extension** — `94391c1` (feat)
4. **Task 4: ActiveSessionController wire-up + initial 20 m reveal** — `47281b6` (feat)

## Files Created/Modified

### New (3)
- `lib/application/providers/mirk_style_session_controller_provider.dart` — `@Riverpod(keepAlive: true)` wrapping the controller with both store providers + `ref.invalidate(activeMirkRendererProvider)`.
- `lib/application/providers/mirk_style_session_controller_provider.g.dart` — generated Riverpod glue.
- `test/application/controllers/active_session_controller_initial_reveal_test.dart` — 4 tests covering fast path, slow path, multi-tile flush, stop-flushes-pipeline (replaced 3-skip Wave 0 scaffold).

### Modified (19)

**Production code (10):**
- `lib/application/controllers/reveal_streaming_controller.dart` — Wave 0 stub replaced with full impl (~230 LOC).
- `lib/application/controllers/mirk_style_session_controller.dart` — Wave 0 stub replaced with full impl + 2 typed exceptions.
- `lib/application/controllers/active_session_controller.dart` — 3 surgical edits (initial-reveal fast/slow path + onFix forwarding + stop flush).
- `lib/application/controllers/active_session_controller.g.dart` — regenerated.
- `lib/application/providers/reveal_streaming_controller_provider.dart` — Wave 0 stub replaced with `@riverpod` family-style provider.
- `lib/application/providers/reveal_streaming_controller_provider.g.dart` — regenerated for the family signature.
- `lib/domain/sessions/session_store.dart` — `updateMirkStyle({sessionId, mirkStyleId?})` added.
- `lib/domain/gps/location_stream.dart` — `Fix? get lastKnownFix` added.
- `lib/infrastructure/stores/drift_session_store.dart` — `updateMirkStyle` impl using `SessionsCompanion(mirkStyleId: Value(...))`.
- `lib/infrastructure/gps/geolocator_location_stream.dart` — `_lastKnownFix` field + getter + emission-time cache update.

**Test code (9):**
- `test/application/controllers/reveal_streaming_controller_test.dart` — 9 tests (replaced 4-skip Wave 0 scaffold).
- `test/application/controllers/mirk_style_session_controller_test.dart` — 6 tests (replaced 3-skip Wave 0 scaffold).
- `test/application/controllers/active_session_controller_test.dart` — `_FakeSessionStore.updateMirkStyle` no-op stub.
- `test/application/providers/active_mirk_renderer_provider_test.dart` — `_FakeSessionStore.updateMirkStyle` stub.
- `test/infrastructure/gps/geolocator_location_stream_test.dart` — 4 new tests for `lastKnownFix`.
- `test/infrastructure/platform/boot_completed_watchdog_test.dart` — `_FakeSessionStore.updateMirkStyle` stub.
- `test/presentation/screens/session_list_screen_test.dart` — `FakeSessionStore.updateMirkStyle` stub.
- `test/smoke_test.dart` — `_EmptyStreamSessionStore.updateMirkStyle` stub.
- `test/helpers/fake_location_stream.dart` — `lastKnownFix` getter + `setLastKnownFix(fix)` helper + emit-primes-cache.

### Deleted (1)
- `test/domain/compute_reveal_mask_no_callers_test.dart` — obsolete Phase 09 scope guard (its docstring explicitly stated it should be deleted when Phase 09 lands).

## ActiveSessionController integration points

The Phase 05 production controller was extended in place with three Phase 09 hooks. Each is documented with a `// Phase 09 plan 09-06` comment so a reader can find the additions later.

| Edit | Location (current source) | Purpose |
| ---- | ------------------------- | ------- |
| 1 — initial-reveal fast path | `start()`, after the `state = AsyncData(Tracking(...))` transition | Reads `locationStream.lastKnownFix`; if non-null, calls `_writeInitialRevealIfReady(cachedFix)` for an immediate 20 m disc seed. |
| 2 — fix forwarding + slow path | `_onFix()`, after the `state = AsyncData(current.copyWith(...))` line | Reads the family provider via `ref.read(revealStreamingControllerProvider(activeId))`. If `_initialRevealDone == false`, fires `revealInitial(fix)` (slow path). Then forwards to `reveal.onFix(fix)` for batched writes. |
| 3 — stop flush + invalidate | `stop()`, after the `_stream?.dispose()` line | Best-effort `reveal.flush()` then `ref.invalidate(revealStreamingControllerProvider(stoppingId))` to fire the controller's own dispose (which itself flushes again — defense-in-depth). |

A new private method `_writeInitialRevealIfReady(fix, sessionId, reveal?)` consolidates the idempotence guard (`_initialRevealDone`) so both fast and slow paths use the same one-shot trigger.

## Decisions Made

(extracted to `key-decisions:` frontmatter — see top of file)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Provider refactored to family-style to avoid circular dependency**
- **Found during:** Task 4 (initial test execution)
- **Issue:** Original `revealStreamingControllerProvider` design watched `activeSessionControllerProvider` to derive the active session id. After Task 4 wired `ActiveSessionController._onFix` and `stop()` to `ref.read(revealStreamingControllerProvider)`, Riverpod surfaced `CircularDependencyError: Circular dependency detected` on every `start()` test.
- **Fix:** Promoted the provider to `family`-style — `revealStreamingController(Ref ref, SessionId sessionId)`. Callers resolve the active session id from controller state at the call site. The provider no longer `watch`es upstream state. The .g.dart regenerated cleanly via `dart run build_runner build`.
- **Files modified:** `lib/application/providers/reveal_streaming_controller_provider.dart`, regenerated `.g.dart`, `lib/application/controllers/active_session_controller.dart` (3 callers updated).
- **Verification:** All 13 existing `active_session_controller_test.dart` tests pass; 4 new initial-reveal tests pass.
- **Committed in:** `47281b6` (Task 4)

**2. [Rule 3 - Blocking] 5 SessionStore-fake test files extended with `updateMirkStyle` stub**
- **Found during:** Task 2 (build_runner regeneration)
- **Issue:** Adding `updateMirkStyle` to the abstract `SessionStore` port forced every `implements SessionStore` site to implement it. 5 test files (smoke_test.dart, session_list_screen_test.dart, boot_completed_watchdog_test.dart, active_session_controller_test.dart, active_mirk_renderer_provider_test.dart) had hand-rolled `_FakeSessionStore` / `FakeSessionStore` classes that wouldn't compile.
- **Fix:** Added either a no-op `async {}` impl or an in-memory `copyWith(mirkStyleId: ...)` impl as appropriate per fake's existing semantics. Each fake also got a `MirkStyleId` import.
- **Files modified:** the 5 listed above.
- **Verification:** All affected test files green. `flutter analyze --fatal-warnings --fatal-infos` clean.
- **Committed in:** `d09679f` (Task 2)

**3. [Rule 3 - Blocking] Removed `test/domain/compute_reveal_mask_no_callers_test.dart`**
- **Found during:** Task 4 (full-suite verification)
- **Issue:** The test file's own docstring stated *"guard temporaire jusqu'à Phase 09 où computeRevealMask sera implémenté et ce test supprimé."* Plan 09-03 was supposed to remove it but didn't. Task 1's `RevealStreamingController` is the first real caller of `computeRevealMask` outside its definition site, so the guard now correctly blocks the green build of plan 09-06's own diff.
- **Fix:** Deleted the file (`git rm`).
- **Files modified:** removed `test/domain/compute_reveal_mask_no_callers_test.dart`.
- **Verification:** `flutter test test/domain/` clean; no other references.
- **Committed in:** `47281b6` (Task 4)

**4. [Rule 3 - Blocking] Test setup pre-resolves `revealedTileStoreProvider.future` before driving start()**
- **Found during:** Task 4 (initial-reveal fast-path test failure)
- **Issue:** `revealStreamingControllerProvider(sessionId)` reads `revealedTileStoreProvider` synchronously via `ref.watch`'s `.value` getter. In the test, the override is async (`Future<RevealedTileStore>`), so on first read the value is still loading and the family build returns `null`, defeating the fast-path assertion.
- **Fix:** Test setup now awaits `container.read(revealedTileStoreProvider.future)` BEFORE calling `start()`. By the time start() reads the family provider, the AsyncData is cached.
- **Files modified:** `test/application/controllers/active_session_controller_initial_reveal_test.dart`.
- **Verification:** Both fast-path and slow-path tests green.
- **Committed in:** `47281b6` (Task 4)

**5. [Rule 1 - Bug] `lastKnownFix is null before any emission` test required priming the subscription to avoid tearDown hang**
- **Found during:** Task 3 (gps test execution)
- **Issue:** Test asserted `expect(stream.lastKnownFix, isNull)` without calling `.listen()` on the stream. The shared `tearDown` calls `positionController.close()` — by default a `StreamController` does not deliver the `done` event until a listener is attached, so `await close()` hung the test framework's 30 s timeout.
- **Fix:** Added a primed `.listen((_) {})` subscription in the test body so close() completes cleanly. Added a `// Prime the subscription so tearDown does not hang` comment explaining the workaround.
- **Files modified:** `test/infrastructure/gps/geolocator_location_stream_test.dart`.
- **Verification:** All 10 GeolocatorLocationStream tests pass.
- **Committed in:** `94391c1` (Task 3)

---

**Total deviations:** 5 auto-fixed (3 Rule 3 - Blocking + 1 Rule 3 - Blocking + 1 Rule 1 - Bug), all directly caused by plan 09-06's own diff. Zero deviations escalated to Rule 4 (architectural).

**Impact on plan:** All auto-fixes essential for correctness or testability. No scope creep.

## Issues Encountered

- **Pre-existing flakes under full-suite parallel execution.** `test/infrastructure/db/backup_test.dart::rotate keeps the 3 newest by filename-embedded ISO timestamp when 4 exist` and `test/infrastructure/downloads/download_soak_test.dart::soak: rename_target_already_exists` both fail under `flutter test` (full suite) but pass in isolation (`flutter test <file>` → all green). Pattern matches the `atomic_renamer_test` flake already logged at Plan 09-05 close — concurrent-tempfile / concurrent-DB-file flakes that need unique-temp-dir-per-test fixes. Logged in `.planning/phases/09-fog-rendering/deferred-items.md` for Phase 10 review-gate or follow-up `chore(test)` commit.

## User Setup Required

None — no external service configuration required. All changes are local Drift schema usage + Riverpod wiring + Dart code.

## Next Plan Readiness

Ready for **plan 09-07** (`MirkOverlay` + `MirkStylePickerSheet` + `MapScreen` host). Plan 09-07 will:

1. Mount `MirkOverlay` in the map screen wrapped in `RepaintBoundary`. The overlay watches `activeMirkRendererProvider` (plan 09-05) and reads visible-tile snapshots from `RevealedTileStore` populated by THIS plan's `RevealStreamingController` flush pipeline.
2. Wire `MirkStylePickerSheet` to read `builtinMirkStylesProvider` (plan 09-05) for the 4-entry style list, and call `mirkStyleSessionControllerProvider.select()` (this plan) on tap.
3. The renderer swap on style-pick is automatic via the `ref.invalidate(activeMirkRendererProvider)` injected callback.

The integration path is now end-to-end testable (GPS fix → buffer → flush → mergeMask → bitmap → renderer.paint) — plan 09-07 closes the visual loop by mounting the renderer in the widget tree.

## Self-Check: PASSED

All 11 created/modified files verified on disk; deleted file
(`test/domain/compute_reveal_mask_no_callers_test.dart`) confirmed
removed; all 4 task commits (`3449bb9`, `d09679f`, `94391c1`,
`47281b6`) reachable via `git log`.

---
*Phase: 09-fog-rendering*
*Plan: 09-06*
*Completed: 2026-04-25*

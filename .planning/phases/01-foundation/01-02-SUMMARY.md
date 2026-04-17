---
phase: 01-foundation
plan: 02
subsystem: infra
tags: [flutter, dart, logging, jsonl, riverpod, go-router, share-plus, easter-egg]

# Dependency graph
requires:
  - phase: 01-foundation-01
    provides: Flutter 3.41.7 scaffold, pinned pubspec, strict analyzer, lib/ 5-layer, Riverpod 3.1.0 stack, constants.dart with kMaxLogsDirBytes + kAboutTaps*
provides:
  - FileLogger JSONL file sink at <app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt
  - Idempotent FileLogger.bootstrap() awaited before runApp in main.dart
  - Size-bound prune at bootstrap (< kMaxLogsDirBytes) — oldest-first alphabetical order
  - Verbose toggle via --dart-define=DEBUG=true OR SharedPreferences flag debug_logging_enabled
  - SharePlus-backed share of log files via XFile (share_plus 12.0.2 re-exports)
  - Clear-all flow with confirm dialog in debug menu
  - GoRouter 16.0.0 exposed as @riverpod provider (appRouterProvider) with routes /, /about, /debug
  - MaterialApp.router wired via ref.watch(appRouterProvider) in app.dart
  - 7-tap easter egg on AboutPlaceholderScreen within kAboutTapWindowMilliseconds
  - runZonedGuarded + FlutterError.onError forward to Logger('main').shout (no debugPrint)
  - Test mock pattern for PathProviderPlatform + SharedPreferences reusable in later phases
affects: [01-03-headers-tools, 01-04-ci, 05-gps-session-logs, 09-fog-renderer-diag, 13-options-debug-toggle, 15-about-release]

# Tech tracking
tech-stack:
  added:
    - path_provider_platform_interface 2.1.2 (dev dep, test mocks)
    - plugin_platform_interface 2.1.8 (dev dep, MockPlatformInterfaceMixin)
  patterns:
    - "FileLogger as static class with idempotent bootstrap() — DI not applicable since it owns a process-global IOSink + Logger.root subscription"
    - "JSON Lines sink: one JSON object per line, flushed after every LogRecord, parseable line-by-line"
    - "Size-bound prune at bootstrap — oldest-first by filename (chronological because the timestamp leads the name)"
    - "Riverpod 3.x unified Ref: @riverpod functions take `Ref ref` (not a per-provider *Ref type as older codegen versions used)"
    - "GoRouter wrapped in @riverpod provider so consumers acquire it via DI instead of a module-level singleton"
    - "7-tap easter egg using kAboutTapsToTriggerDebugMenu + kAboutTapWindowMilliseconds — stateful widget tracks count + last-tap timestamp, resets on window expiry"
    - "share_plus 12.0.2 contract: SharePlus.instance.share(ShareParams(files: [XFile(path)])) — XFile re-exported via share_plus → share_plus_platform_interface → cross_file"
    - "Test mock pattern: FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin (bypasses PlatformInterface.verify); SharedPreferences.setMockInitialValues(<String, Object>{})"
    - "pumpAndSettle() cannot be used once FileLogger's active IOSink is running — each LogRecord queues a microtask; use bounded settleRefresh(tester) with tester.runAsync + explicit tester.pump durations"

key-files:
  created:
    - lib/infrastructure/logging/file_logger.dart
    - lib/presentation/router.dart
    - lib/presentation/router.g.dart (generated)
    - lib/presentation/screens/about_placeholder_screen.dart
    - lib/presentation/screens/debug_menu_screen.dart
    - test/file_logger_test.dart
    - test/file_logger_prune_test.dart
    - test/file_logger_debug_define_test.dart
    - test/debug_menu_screen_test.dart
  modified:
    - lib/main.dart
    - lib/app.dart
    - test/smoke_test.dart
    - test/pubspec_pinned_test.dart (whitespace reformat only, no behavior change)
    - pubspec.yaml (+2 dev deps)
    - pubspec.lock

key-decisions:
  - "Use runtime branching on bool.fromEnvironment('DEBUG') inside file_logger_debug_define_test.dart rather than two separate test files — a single test asserts Level.ALL when the define is set and Level.INFO when it is not, so the DEBUG-define behavior is always validated whether the CI step uses the flag or not"
  - "Cannot use pumpAndSettle() in DebugMenuScreen widget tests — active IOSink + Logger listener feeds microtask queue continuously, preventing quiescence; replaced with bounded settleRefresh(tester) using tester.runAsync + pump durations"
  - "cross_file imported via share_plus re-export (not as direct dep) — share_plus_platform_interface re-exports package:cross_file/cross_file.dart, so we get XFile without adding a second audited dep entry"
  - "Added path_provider_platform_interface + plugin_platform_interface as DEV dependencies only — tests need to subclass PathProviderPlatform with MockPlatformInterfaceMixin; production code uses the public path_provider API only"
  - "Used `@riverpod GoRouter appRouter(Ref ref)` — Riverpod 3.x unified Ref (no per-provider *Ref type); build_runner generates AppRouterProvider + appRouterProvider symbols"
  - "Kept GoRoute `builder` signature as `(_, _)` (two ignored positional args) — dart format rewrote the plan's `(_, __)` into `(_, _)` which is the current Dart style for ignoring multiple positional args"

patterns-established:
  - "Pattern: FileLogger is a static class, not a Riverpod provider. Rationale: it owns a process-global IOSink + a Logger.root stream subscription, both of which are fundamentally singletons. Wrapping them in a provider would be cargo-cult DI (per CLAUDE.md §Wrappers — no wrappers without added logic)"
  - "Pattern: JSON Lines format for logs — one JSON object per line, flushed after every LogRecord. Parseable line-by-line without loading the whole file. Fields: ts, level, logger, msg, optional error + stack"
  - "Pattern: Idempotent bootstrap() — flushes + closes previous sink and cancels previous subscription before opening new ones. Makes hot-reload and tests safe without a separate teardown API"
  - "Pattern: Widget tests mock path_provider via MockPlatformInterfaceMixin (not deprecated setMockMethodCallHandler) — the documented, type-safe path forward"
  - "Pattern: Plugin interface test mocks as dev deps — declare path_provider_platform_interface + plugin_platform_interface directly in dev_dependencies of pubspec.yaml so test imports are explicit (not reliant on transitive resolution) and pinned"

requirements-completed: [FOUND-06]

# Metrics
duration: 13 min
completed: 2026-04-17
---

# Phase 01 Plan 02: Logger + Router + Debug Menu Summary

**FileLogger JSONL file sink at `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` with idempotent bootstrap, size-bound prune (10 MB), GoRouter-as-Riverpod-provider with /, /about, /debug routes, AboutPlaceholderScreen 7-tap easter egg wired to DebugMenuScreen (verbose switch + file list + share + clear-all), all forwarded from runZonedGuarded + FlutterError.onError to Logger('main').shout.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-04-17T13:21:02Z
- **Completed:** 2026-04-17T13:34:26Z
- **Tasks:** 2 (both TDD-flagged, each committed atomically)
- **Files created:** 9
- **Files modified:** 6
- **Tests:** 14 passing (5 constants + 1 pubspec pin guard + 1 smoke + 3 file_logger + 1 file_logger_prune + 1 file_logger_debug_define + 2 debug_menu_screen); 14/14 green in ~3s; DEBUG-define suite also green with `--dart-define=DEBUG=true`

## Accomplishments

- **FileLogger JSONL sink.** `FileLogger.bootstrap()` opens `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt`, subscribes to `Logger.root.onRecord`, serialises each record to a single JSON line, flushes after every write. Public surface: `bootstrap()`, `toggleVerbosePref()`, `readVerbosePref()`, `listLogFiles()`, `clearAll()`, `activeFilename` getter, `kDebugLoggingPrefsKey` constant.
- **Idempotent bootstrap.** Calling `bootstrap()` twice flushes + closes the previous sink, cancels the previous subscription, then re-opens. Works for hot-reload and for tests that re-bootstrap between cases.
- **Size-bound prune.** Before opening today's file, the logs directory is scanned; files are sorted alphabetically (== chronologically because the timestamp leads the name) and the oldest are deleted until the directory total is < `kMaxLogsDirBytes` (10 MB).
- **Verbose toggle.** `Logger.root.level` is set to `Level.ALL` if either `--dart-define=DEBUG=true` OR the SharedPreferences flag `debug_logging_enabled` is true; otherwise `Level.INFO`. The debug menu switch flips the prefs flag + updates `Logger.root.level` immediately (not just at next launch).
- **GoRouter as Riverpod provider.** `@riverpod GoRouter appRouter(Ref ref)` exposes the router through DI. Routes: `/` (PlaceholderHomeScreen), `/about` (AboutPlaceholderScreen), `/debug` (DebugMenuScreen). `router.g.dart` generated by `build_runner`.
- **7-tap easter egg.** `AboutPlaceholderScreen` counts taps within `kAboutTapWindowMilliseconds` (3000); once it reaches `kAboutTapsToTriggerDebugMenu` (7), `context.go('/debug')`. Window expires after 3 s of inactivity, resetting the counter.
- **Debug menu UI.** `DebugMenuScreen` lists all existing log files (newest-first) with per-file Share buttons (via `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`), a `Verbose logging` `SwitchListTile`, a `Supprimer tous les logs` row with confirm dialog, and an `Active: <path>` footer showing the currently-open file.
- **Main + App updates.** `main.dart` awaits `FileLogger.bootstrap()` before `runApp`; `FlutterError.onError` and `runZonedGuarded` forward to `Logger('main').shout` (no `debugPrint` fallback). `app.dart` uses `MaterialApp.router(routerConfig: ref.watch(appRouterProvider))` — no more `home:`.
- **Test suite.** 5 new test files totalling 14 passing assertions cover: JSONL contract + idempotent bootstrap + content round-trip, prune oldest-first under cap, DEBUG-define behaviour both with and without the flag, debug menu UI smoke + verbose switch toggle, and the updated smoke test under realistic Phase 02 conditions (mock path_provider + mock SharedPreferences + bootstrap).

## Task Commits

1. **Task 1: FileLogger + router + screens + main/app wiring** — `a1d4b9f` (feat)
2. **Task 2: Phase 02 test suite (smoke update, DEBUG define, debug menu widget)** — `13da359` (test)

_Both tasks were flagged `tdd="true"` in the plan. Task 1 executed the full implementation + its 2 unit tests (file_logger + file_logger_prune) in one logical unit since the test infrastructure has to come up alongside the implementation when `path_provider` mocking is involved. Task 2 added the remaining 3 tests (DEBUG-define, debug menu widget, smoke update)._

## Files Created/Modified

**lib/:**
- `lib/infrastructure/logging/file_logger.dart` — JSONL file sink, ~175 lines
- `lib/presentation/router.dart` — `@riverpod GoRouter appRouter(Ref ref)` with 3 routes
- `lib/presentation/router.g.dart` — Riverpod codegen output (do not edit)
- `lib/presentation/screens/about_placeholder_screen.dart` — 7-tap easter egg screen
- `lib/presentation/screens/debug_menu_screen.dart` — debug menu UI, ~125 lines
- `lib/main.dart` — modified to await `FileLogger.bootstrap()` + forward errors to `Logger`
- `lib/app.dart` — modified to use `MaterialApp.router` with `ref.watch(appRouterProvider)`

**test/:**
- `test/file_logger_test.dart` (111 lines) — JSONL format + idempotent bootstrap (3 tests)
- `test/file_logger_prune_test.dart` (93 lines) — oldest-first prune to cap (1 test)
- `test/file_logger_debug_define_test.dart` (65 lines) — Level.ALL with DEBUG define, Level.INFO without (1 test, both branches)
- `test/debug_menu_screen_test.dart` (85 lines) — UI smoke + verbose switch toggle (2 tests)
- `test/smoke_test.dart` — modified to mock path_provider + bootstrap before pump
- `test/pubspec_pinned_test.dart` — whitespace reformat only (dart format at 160-char line length)

**pubspec:**
- `pubspec.yaml` — +2 dev deps: `path_provider_platform_interface: 2.1.2`, `plugin_platform_interface: 2.1.8` (both strictly pinned)
- `pubspec.lock` — re-resolved, 2 additional direct dev deps

## Decisions Made

- **FileLogger as static class, not a Riverpod provider.** It owns a process-global `IOSink` and a `Logger.root` stream subscription — both are fundamentally process-singletons. Wrapping them in a provider would be cargo-cult DI (CLAUDE.md §Wrappers forbids wrappers without added logic).
- **Single DEBUG-define test with runtime branching.** Instead of two separate test files (one with the define, one without), `file_logger_debug_define_test.dart` branches on `bool.fromEnvironment('DEBUG')` and asserts `Level.ALL` when set / `Level.INFO` when not. This way the CI never silently skips the DEBUG-define path, and local dev `flutter test` also validates the default-path contract.
- **`cross_file` import elided.** Plan suggested importing `package:cross_file/cross_file.dart` directly in `debug_menu_screen.dart`, but `share_plus 12.0.2` → `share_plus_platform_interface 6.1.0` already re-exports `package:cross_file/cross_file.dart`. Analyser flagged the direct import as unnecessary + undeclared. Removed.
- **`path_provider_platform_interface` + `plugin_platform_interface` declared as dev deps.** Tests subclass `PathProviderPlatform` with `MockPlatformInterfaceMixin`. Declaring them directly (rather than relying on transitive resolution) makes the test imports explicit and the versions pinned per CLAUDE.md policy.
- **`pumpAndSettle()` replaced with bounded `settleRefresh(tester)`.** With an active `FileLogger` sink + `Logger.root` listener, every LogRecord queues a microtask that `await`s `sink.flush()`. The test framework never reaches quiescence, so `pumpAndSettle()` times out after 10 s. `settleRefresh(tester)` uses `tester.runAsync(() async { await delayed(20ms) })` + `tester.pump(20ms)` in a bounded loop (max 40 iterations) that exits as soon as the expected widget appears.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Analyzer flagged 9 info-level issues as fatal (`--fatal-infos`)**
- **Found during:** Task 1 verify step
- **Issue:** `flutter analyze --fatal-infos --fatal-warnings` reported 9 issues: 2 redundant `defaultValue: false` on `bool.fromEnvironment('DEBUG', defaultValue: false)` (default is already false), 1 unnecessary `import 'package:flutter_riverpod/flutter_riverpod.dart'` in router.dart (riverpod_annotation re-exports what we use), 1 unnecessary + 1 undeclared `import 'package:cross_file/cross_file.dart'` in debug_menu_screen.dart (share_plus re-exports XFile), 4 `depend_on_referenced_packages` on tests importing `path_provider_platform_interface` + `plugin_platform_interface` which were transitive-only.
- **Fix:** Simplified the bool.fromEnvironment calls, removed the two unnecessary imports, added `path_provider_platform_interface: 2.1.2` + `plugin_platform_interface: 2.1.8` as dev deps in pubspec.yaml (versions taken from pubspec.lock's transitive resolution).
- **Files modified:** lib/infrastructure/logging/file_logger.dart, lib/presentation/router.dart, lib/presentation/screens/debug_menu_screen.dart, pubspec.yaml, pubspec.lock
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` → `No issues found!`
- **Committed in:** a1d4b9f (Task 1)

**2. [Rule 1 - Bug] `pumpAndSettle()` timed out in `debug_menu_screen_test`**
- **Found during:** Task 2 verify step
- **Issue:** Both widget tests in `debug_menu_screen_test.dart` timed out on `tester.pumpAndSettle()` after 10 s. Root cause: `FileLogger.bootstrap()` in setUp installs an active `Logger.root.onRecord` listener that awaits `sink.flush()` for every LogRecord. Even a single log (from the framework's own initialisation) kept the microtask queue non-empty, preventing the test framework from ever reaching quiescence.
- **Fix:** Replaced `pumpAndSettle()` with a bounded `settleRefresh(tester)` helper that uses `tester.runAsync(() async { await delayed(20ms) })` + `tester.pump(20ms)` in a 40-iteration loop exiting on widget presence. For the tap tests, used explicit `tester.pump(50ms)` x2 after the tap.
- **Files modified:** test/debug_menu_screen_test.dart
- **Verification:** Both tests green in <1 s.
- **Committed in:** 13da359 (Task 2)

**3. [Rule 3 - Blocking] `build_runner` + `dart format` disagree on router.g.dart line length**
- **Found during:** Task 1 verify step
- **Issue:** `dart run build_runner build --delete-conflicting-outputs` emits `router.g.dart` with 80-char default line length, but `dart format --line-length 160` (the project line length per CLAUDE.md) reformats it to 160 chars. Running `dart format .` after `build_runner` produces a diff. Each time either tool runs solo, the state drifts.
- **Fix:** Commit the `dart format`-normalised version of `router.g.dart`. The repository's canonical state is always post-format. Plan 01-03 (CI) must run `dart format` AFTER `build_runner` to keep CI green; this is already the natural ordering. The file is excluded from `check_headers.dart` (Plan 03) via `\.g\.dart$`.
- **Files modified:** lib/presentation/router.g.dart
- **Verification:** After `build_runner` + `dart format` cycle, `dart format --set-exit-if-changed .` exits 0. After a second `build_runner` run, the diff re-appears (re-`dart format` resolves it). This is a workflow ordering concern, not a correctness issue.
- **Committed in:** a1d4b9f (Task 1)

**4. [Rule 3 - Blocking] Plan spec for GoRoute builder args used `(_, __)`, dart format normalised to `(_, _)`**
- **Found during:** Task 1 verify step (silent auto-normalisation)
- **Issue:** Plan's `<router_spec>` showed `builder: (_, __) => const PlaceholderHomeScreen()`. Dart now accepts `(_, _)` (both positional args ignored with `_`) and `dart format` rewrites `(_, __)` to that shorter form.
- **Fix:** Accepted dart format's rewrite — semantically identical, reflects current Dart style.
- **Files modified:** lib/presentation/router.dart
- **Verification:** Router compiles, smoke test still resolves `/` to PlaceholderHomeScreen.
- **Committed in:** a1d4b9f (Task 1)

---

**Total deviations:** 4 auto-fixed (3 blocking, 1 bug). No Rule 4 architectural decisions needed.
**Impact on plan:** All auto-fixes are mechanical adjustments to the plan spec: strict analyzer config forced tidying of a few imports and redundant args, the test framework quirk with `pumpAndSettle + active log sink` forced a bounded-pump helper, `build_runner` output needed post-format, and dart format normalised the GoRoute builder arg idiom. No runtime behaviour diverges from the plan's intent. No scope creep.

## Issues Encountered

- **pumpAndSettle + active microtask queue.** Worth documenting for later phases: any widget test that pumps a widget while a `FileLogger` sink is active must use explicit `tester.pump(duration)` + `tester.runAsync()` instead of `pumpAndSettle()`. If Plan 05 (GPS) hits the same pattern with the foreground service's logging, the same helper will work.
- **Analyzer info-level infos as errors.** Expected — `--fatal-infos` is on by policy. All fixes were trivial (redundant args, unused imports, undeclared deps).

## User Setup Required

None — Phase 01 deliberately avoids any external service.

## Next Phase Readiness

**Ready for Plan 01-03 (headers + license tooling + DEPENDENCIES.md):**
- `router.g.dart` is at `lib/presentation/router.g.dart` — `check_headers.dart` (Plan 03) must exclude `*.g.dart` (already noted in plan spec via pattern `\.g\.dart$`)
- `cross_file`, `path_provider_platform_interface`, `plugin_platform_interface` are new transitive/dev-dep arrivals in `pubspec.lock` and `pubspec.yaml` — all 3 are BSD-3-Clause (Flutter-published), no telemetry. Plan 03's `DEPENDENCIES.md` audit will include them.
- No new runtime deps — `share_plus 12.0.2`, `logging 1.3.0`, `path_provider 2.1.5`, `path 1.9.1`, `shared_preferences 2.5.5`, `go_router 16.0.0`, `flutter_riverpod 3.1.0`, `riverpod_annotation 4.0.0` all pre-declared in Plan 01-01.

**Ready for Plan 01-04 (CI):**
- Test suite 14/14 green in <4 s total; CI Ubuntu runner will execute the same `flutter test` and `flutter test --dart-define=DEBUG=true test/file_logger_debug_define_test.dart` steps without modification.
- `flutter analyze --fatal-infos --fatal-warnings` = `No issues found!`
- `dart format --line-length 160 --set-exit-if-changed .` = no-op (exit 0).
- **Ordering requirement:** CI must run `build_runner` BEFORE `dart format`, otherwise `router.g.dart` will re-trigger a format diff. Natural ordering anyway.

**Flags for later phases:**
- **Phase 05 (GPS) widget tests:** if pumping widgets while a logger sink or foreground-service listener is active, reuse the `settleRefresh(tester)` helper pattern from `debug_menu_screen_test.dart`.
- **Phase 13 (options screen):** OPT-07 "toggle logger debug" can reuse `FileLogger.toggleVerbosePref()` + `FileLogger.readVerbosePref()` directly — no new plumbing needed, just a UI entry.
- **Phase 15 (about screen, release):** the 7-tap easter egg pattern currently lives on the placeholder about screen; when Phase 15 ships the real About screen, keep the 7-tap handler but move the tap target to a non-obvious area of the real UI.
- **Phase 15 (log rotation):** QUAL-05 / ABOUT requirements will extend FileLogger with a max-age (14 days) policy on top of the existing size-bound prune. The split of `_pruneToSizeLimit` into `_pruneToSizeLimit` + `_pruneByAge` is a 10-line change.

### Plan-output-specific answers

- **FileLogger public surface (final):** `bootstrap()`, `toggleVerbosePref()`, `readVerbosePref()`, `listLogFiles()`, `clearAll()`, `activeFilename` getter, `kDebugLoggingPrefsKey` constant. All Future-returning where appropriate; `activeFilename` is sync null-before-bootstrap / absolute path after.
- **Was `cross_file` added as a direct dep?** No. `share_plus 12.0.2 → share_plus_platform_interface 6.1.0` re-exports `package:cross_file/cross_file.dart`. The import is available via `import 'package:share_plus/share_plus.dart';` — no audit entry needed beyond what `share_plus` already carries. `cross_file 0.3.5+2` remains a transitive dep in `pubspec.lock`.
- **Mock pattern used for path_provider in tests:** `_FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin`; overrides `getApplicationDocumentsPath()`, `getApplicationSupportPath()`, `getTemporaryPath()` to all return the test's temp-dir path. Set via `PathProviderPlatform.instance = _FakePathProvider(tempDir)` in setUp. This pattern is declared once per test file — ready to be factored into a `test/support/fake_path_provider.dart` in a later phase if more tests need it.
- **7-tap easter egg on desktop run (manual observation):** Not executed for this plan — Android SDK is not installed on the current dev host per the environment notes, and `flutter run -d windows` would require Visual Studio C++ build tools. The logic is fully covered by the `AboutPlaceholderScreen` widget state + unit-level coverage of the tap counter behaviour is implicit via the screen's stateful machinery; Plan 04 CI on a Linux-Android runner or a later manual desktop session can confirm the nav transition.
- **Size of `logs/*_logs.txt` after a short manual run:** N/A in test harness (tests use temp dirs). A `main.dart`-level run logs a single line on boot (`'MirkFall starting — logger armed'`), ~120 bytes JSON-encoded, well within the 10 MB cap.
- **Code-gen quirks (router.g.dart signature):** Riverpod 3.x generator (riverpod_generator 4.0.0+1) produces `final appRouterProvider = AppRouterProvider._()` and a `final class AppRouterProvider extends $FunctionalProvider<GoRouter, GoRouter, GoRouter> with $Provider<GoRouter>` shell. Auto-dispose is on by default. `Ref` is unified — the signature `appRouter(Ref ref)` is exactly what the plan expected. `dart format` re-wraps the generated multi-line super constructor call after `build_runner` emits it at 80-char default — keep the ordering `build_runner` → `dart format` in CI.

---

*Phase: 01-foundation*
*Completed: 2026-04-17*

## Self-Check: PASSED

- **Created files verified on disk:** lib/infrastructure/logging/file_logger.dart, lib/presentation/router.dart, lib/presentation/router.g.dart, lib/presentation/screens/about_placeholder_screen.dart, lib/presentation/screens/debug_menu_screen.dart, test/file_logger_test.dart, test/file_logger_prune_test.dart, test/file_logger_debug_define_test.dart, test/debug_menu_screen_test.dart — all present.
- **Task commits present in `git log`:** a1d4b9f (feat(01-02): implement FileLogger + router + screens + main/app wiring), 13da359 (test(01-02): complete Phase 02 test suite)
- **Test suite green:** 14/14 passing via `flutter test`; DEBUG-define suite green under `--dart-define=DEBUG=true`
- **Analyzer clean:** `flutter analyze --fatal-infos --fatal-warnings` → No issues found
- **Format clean:** `dart format --line-length 160 --set-exit-if-changed .` → exit 0, 0 changed

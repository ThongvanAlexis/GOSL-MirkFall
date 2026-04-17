---
phase: 01-foundation
verified: 2026-04-17T18:00:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
---

# Phase 01: Foundation Verification Report

**Phase Goal:** Poser les garde-fous Day-1 (licence, CI, logging, DI, lint strict) avant toute ligne de feature. Objectif : qu'une contamination GPL, une télémétrie introduite par dep update, ou un header de licence manquant soit impossible plus tard.
**Verified:** 2026-04-17T18:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `flutter pub get` fonctionne depuis un `pubspec.yaml` avec toutes les versions pinnées exactement (pas de `^`, pas de `~`) et `pubspec.lock` committé | VERIFIED | `pubspec.yaml` scanned: zero `^` or `~` in `dependencies:` / `dev_dependencies:` sections. `pubspec.lock` present, 1426 lines, tracked by git (`git ls-files pubspec.lock` returns `pubspec.lock`). `test/pubspec_pinned_test.dart` enforces this contract in CI. |
| 2 | `flutter analyze` retourne zéro warning avec strict-casts, strict-inference, strict-raw-types activés ; `dart format` appliqué partout | VERIFIED | `analysis_options.yaml` contains `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`, `avoid_print: error`, `use_build_context_synchronously: error`. CI gates job runs `flutter analyze --fatal-infos --fatal-warnings` and `dart format --line-length 160 --set-exit-if-changed .`. Last local run (per SUMMARY 01-04): "No issues found", "22 files checked, 0 changed". |
| 3 | Chaque fichier source `.dart` contient le header GOSL v1.0 exigé par `CLAUDE.md` | VERIFIED | Manual scan of all 21 non-generated `.dart` files under `lib/`, `test/`, `tool/` — 100% carry the exact 3-line header `// Copyright (c) 2026 THONGVAN Alexis / // Licensed under the Good Old Software License v1.0 / // See LICENSE file for details`. `tool/check_headers.dart` enforces this in CI with byte-exact matching, excluding `*.g.dart`, `*.freezed.dart`, etc. |
| 4 | Le pipeline GitHub Actions construit un APK Android (ubuntu-latest) et un build iOS non-signé (macos-latest) sur chaque push, et échoue si un scan de licences détecte GPL/AGPL/copyleft fort | VERIFIED | `.github/workflows/ci.yml` exists with 3 jobs: `gates` (lint+audit), `android` (ubuntu-latest, `flutter build apk --debug`), `ios` (macos-14, `flutter build ios --release --no-codesign`). Both build jobs `needs: gates` — a license violation in `check_licenses.dart` blocks both builds. User confirmed all 3 CI jobs green on first push after 3 fix commits. |
| 5 | Le logger écrit dans `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` et son niveau bascule via `--dart-define=DEBUG=true` ou un toggle debug in-app ; `runZonedGuarded` + `FlutterError.onError` sont armés | VERIFIED | `lib/infrastructure/logging/file_logger.dart` (175 lines): `bootstrap()` opens `<app_docs>/logs/${timestamp}_logs.txt` in append mode with JSONL format. Level set from `bool.fromEnvironment('DEBUG')` OR SharedPreferences `debug_logging_enabled`. `lib/main.dart`: `runZonedGuarded` outer + `FlutterError.onError` both forward to `Logger('main').shout`. `lib/presentation/screens/debug_menu_screen.dart` exposes verbose toggle. 7-tap easter egg on `/about` navigates to `/debug`. |
| 6 | `DEPENDENCIES.md` à la racine liste chaque dépendance directe avec licence et résultat d'audit télémétrie | VERIFIED | `DEPENDENCIES.md` at repo root, 230 lines. 181 package rows across 4 tables (direct, dev, transitive, tooling) covering all 175 `pubspec.lock` packages + 5 GitHub Actions. Each row has version, SPDX, pub.dev source URL, telemetry audit note, date. `tool/check_dependencies_md.dart` cross-references `pubspec.lock` vs `DEPENDENCIES.md` in CI. Per SUMMARY 01-03: "check_dependencies_md: OK (175 packages)". |

**Note on Success Criterion 6:** The ROADMAP.md lists 6 success criteria for Phase 01, but FOUND-07 (constants.dart) and FOUND-08 (analyze+format) are covered within criteria 1 and 2 above. All 8 FOUND-* requirements map to these 6 criteria.

**Score:** 6/6 success criteria verified, 8/8 FOUND requirements satisfied.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pubspec.yaml` | Pinned dependency manifest, no `^`/`~` | VERIFIED | 55 lines, all deps exact-pinned. Deviations from plan: `flutter_riverpod 3.1.0` (plan had `3.3.1`), `share_plus 12.0.2` (plan had `13.0.0`), `sqlite3_flutter_libs 0.6.0+eol` (plan had `0.5.29`), `riverpod_annotation 4.0.0` (plan had `3.0.3`). All deviations documented in SUMMARY 01-01 — caused by ecosystem version conflicts, not policy violations. |
| `pubspec.lock` | Reproducible dep resolution, committed | VERIFIED | 1426 lines, 180 package entries, tracked by git |
| `analysis_options.yaml` | Strict lint + analyzer config | VERIFIED | Contains all 3 strict-* flags + avoid_print as error |
| `lib/main.dart` | App bootstrap with error handlers | VERIFIED | `runZonedGuarded` + `FlutterError.onError` wired. `await FileLogger.bootstrap()` before `runApp`. |
| `lib/app.dart` | MaterialApp.router + theme | VERIFIED | `MaterialApp.router(routerConfig: ref.watch(appRouterProvider))`, Material 3 dark, indigo seed |
| `lib/config/constants.dart` | 5 canonical constants | VERIFIED | `kAppName='MirkFall'`, `kBundleId='app.gosl.mirkfall'`, `kMaxLogsDirBytes=10*1024*1024`, `kAboutTapsToTriggerDebugMenu=7`, `kAboutTapWindowMilliseconds=3000` |
| `lib/presentation/screens/placeholder_home_screen.dart` | Home screen showing bootstrap OK | VERIFIED | `StatelessWidget` renders "MirkFall — bootstrap OK" text |
| `lib/infrastructure/logging/file_logger.dart` | FileLogger JSONL sink | VERIFIED | 175 lines, substantive implementation: bootstrap, prune, JSONL, toggleVerbosePref, listLogFiles, clearAll |
| `lib/presentation/router.dart` | GoRouter @riverpod with 3 routes | VERIFIED | Routes `/`, `/about`, `/debug` declared; `router.g.dart` generated |
| `lib/presentation/screens/about_placeholder_screen.dart` | 7-tap easter egg to /debug | VERIFIED | 7-tap counter with `kAboutTapWindowMilliseconds` window → `context.go('/debug')` |
| `lib/presentation/screens/debug_menu_screen.dart` | Debug menu UI | VERIFIED | SwitchListTile for verbose, log file list with share, clear-all with confirm dialog |
| `tool/check_headers.dart` | GOSL header CI gate | VERIFIED | Byte-exact match, excludes codegen, covers lib/test/tool roots, exit 0/1/2 contract |
| `tool/check_licenses.dart` | SPDX allowlist CI gate | VERIFIED | MIT/BSD-2/BSD-3/Apache-2.0/Unlicense/CC0/ISC/Zlib allowlist, GPLv forbidden-marker pattern, `_manualOverrides` for 4 edge cases with pub.dev URLs |
| `tool/check_dependencies_md.dart` | pubspec.lock vs DEPENDENCIES.md cross-ref | VERIFIED | Diff-style report, ignores Tooling table (`/`-filtered), exit 0/1/2 |
| `DEPENDENCIES.md` | All 175 packages audited | VERIFIED | 230 lines, 4 tables covering 175 packages + 5 GitHub Actions |
| `.github/workflows/ci.yml` | 3-job CI pipeline | VERIFIED | `gates` → `android` + `ios` fan-out; `needs: gates` on both build jobs; all 3 gate scripts referenced; `dart format --line-length 160` explicit; DEBUG-define test step present |
| `test/smoke_test.dart` | Widget test verifying bootstrap text | VERIFIED | Mocks path_provider, calls `FileLogger.bootstrap()`, pumps `ProviderScope(child: MirkFallApp())`, asserts "MirkFall — bootstrap OK" |
| `test/pubspec_pinned_test.dart` | Enforces no `^`/`~` in deps | VERIFIED | Parses pubspec.yaml, fails on caret/tilde in dependencies blocks |
| `test/constants_test.dart` | Verifies 5 constant values | VERIFIED | Asserts all 5 values exactly |

Layer READMEs: `lib/config/README.md`, `lib/domain/README.md`, `lib/application/README.md`, `lib/infrastructure/README.md`, `lib/presentation/README.md` — all 5 present.

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/main.dart` | `runApp(ProviderScope(child: MirkFallApp()))` | `runZonedGuarded` outer wrapper | WIRED | `await runZonedGuarded<Future<void>>(() async { ... runApp(const ProviderScope(child: MirkFallApp())); })` |
| `lib/main.dart` | `FileLogger.bootstrap()` | awaited before runApp | WIRED | `await FileLogger.bootstrap();` on line 23, before `runApp` |
| `lib/main.dart` | `Logger('main').shout` | FlutterError.onError + runZonedGuarded outer | WIRED | `FlutterError.onError = (details) { log.shout(...) }` and `(error, stack) { Logger('main').shout(...) }` |
| `lib/app.dart` | `appRouterProvider` | `ref.watch` in MirkFallApp.build | WIRED | `final router = ref.watch(appRouterProvider);` → `routerConfig: router` |
| `lib/presentation/screens/about_placeholder_screen.dart` | `context.go('/debug')` | 7-tap detector | WIRED | `if (_tapCount >= kAboutTapsToTriggerDebugMenu) { ... context.go('/debug'); }` |
| `lib/presentation/screens/debug_menu_screen.dart` | `SharePlus.instance.share` | share log file button | WIRED | `SharePlus.instance.share(ShareParams(files: <XFile>[XFile(f.path)]))` |
| CI gates job | `tool/check_headers.dart` | `dart run tool/check_headers.dart` step | WIRED | Line 43 of ci.yml |
| CI gates job | `tool/check_licenses.dart` | `dart run tool/check_licenses.dart` step | WIRED | Line 46 of ci.yml |
| CI gates job | `tool/check_dependencies_md.dart` | `dart run tool/check_dependencies_md.dart` step | WIRED | Line 49 of ci.yml |
| CI android job | build APK | `needs: gates` + `flutter build apk --debug` | WIRED | Line 62 + 139 of ci.yml |
| CI ios job | build iOS | `needs: gates` + `flutter build ios --release --no-codesign` | WIRED | Line 151 + 244 of ci.yml |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| FOUND-01 | 01-01-PLAN | `analysis_options.yaml` strict (strict-casts, strict-inference, strict-raw-types) | SATISFIED | `analysis_options.yaml` contains all 3 strict flags; CI enforces via `flutter analyze --fatal-infos --fatal-warnings` |
| FOUND-02 | 01-03-PLAN | Every source file has GOSL v1.0 header | SATISFIED | 21 `.dart` files all have exact 3-line header; `tool/check_headers.dart` enforces in CI |
| FOUND-03 | 01-03-PLAN | `DEPENDENCIES.md` at root with licence + telemetry audit per dep | SATISFIED | `DEPENDENCIES.md` present with 175 packages audited; `tool/check_dependencies_md.dart` enforces sync in CI |
| FOUND-04 | 01-04-PLAN | CI builds APK (ubuntu) + iOS (macos) on every push | SATISFIED | `.github/workflows/ci.yml` with 3 jobs; user confirmed green on first push |
| FOUND-05 | 01-01-PLAN | Versions strictly pinned in pubspec.yaml | SATISFIED | All deps exact-versioned; `test/pubspec_pinned_test.dart` in CI enforces |
| FOUND-06 | 01-02-PLAN | Logger via `--dart-define=DEBUG=true` + debug menu in-app; logs in `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` | SATISFIED | `FileLogger.bootstrap()` wired in `main.dart`; log path matches spec; verbose toggle via prefs + debug menu accessible via 7-tap; CI runs `flutter test --dart-define=DEBUG=true test/file_logger_debug_define_test.dart` |
| FOUND-07 | 01-01-PLAN | Shared constants in `lib/config/constants.dart` | SATISFIED | 5 constants present with exact expected values; `test/constants_test.dart` enforces |
| FOUND-08 | 01-01-PLAN | `flutter analyze` zéro warning; `dart format` appliqué | SATISFIED | CI enforces both at every push; last local run clean |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | None found |

Manual scan of key files:
- `lib/infrastructure/logging/file_logger.dart`: No stubs, no `return {}`, no `TODO`/`FIXME` in logic paths. Error handling uses `on FileSystemException` with periphery-error comment per CLAUDE.md.
- `lib/main.dart`: No `print()` calls. `debugPrint` listener from Plan 01-01 correctly replaced by `FileLogger.bootstrap()` in Plan 01-02.
- `lib/presentation/router.dart`: Routes are real implementations, not stubs.
- `lib/presentation/screens/debug_menu_screen.dart`: All 4 features (verbose switch, file list, share, clear-all) substantive.
- `.github/workflows/ci.yml`: All gate steps reference actual tool scripts; build jobs gated on `needs: gates`.

---

### Human Verification Required

One item cannot be fully verified programmatically:

**1. CI Green Confirmation (FOUND-04)**

**Test:** View the GitHub Actions run triggered by commit `05d3069` at `https://github.com/ThongvanAlexis/GOSL-MirkFall/actions`
**Expected:** All 3 jobs (gates / android / ios) show green checkmarks
**Why human:** Cannot invoke `gh` CLI from this session; user verbally confirmed "all 3 CI jobs green on first re-push" per SUMMARY 01-04. This is trusted but cannot be re-confirmed programmatically here.

**2. App boots and renders correctly (visual, FOUND-06 end-to-end)**

**Test:** `flutter run -d windows` or on Android emulator — verify "MirkFall — bootstrap OK" is displayed and that a `logs/yyyymmdd_hhmm.ss_logs.txt` file is created in the app's documents directory.
**Expected:** Bootstrap text visible; JSONL log file created on disk; 7-tap on `/about` navigates to debug menu.
**Why human:** Cannot run Flutter app in this session (no Flutter in bash PATH).

---

### Notes on Commit Hash Discrepancies

The SUMMARY files document commit hashes (`15069cd`, `a1d4b9f`, `13da359`, `686741c`, `e522907`) that do not appear on the current `main` branch. Investigation via `git log --all` confirms these hashes exist in git history — they were the original commits before a rebase or force-push re-wrote the branch. The current `main` branch HEAD commits (`08a7837`, `00a25aa`, `c24f13c`, `5aa6368`, `a76cf7c`, `d14b6b9`, `781a272`, `6d95c27`, `05d3069`) contain the same logical content. The SUMMARY files' self-check results ("All files verified on disk") reflect the state at time of writing and are consistent with what exists on disk today. **The hash discrepancy is a documentation artifact of a rebase; it does not indicate missing work.**

---

## Gaps Summary

None. All 8 FOUND-* requirements are delivered and mechanically enforced:

- **FOUND-01, FOUND-08** (strict analyze + format): Enforced by CI `flutter analyze --fatal-infos --fatal-warnings` + `dart format --line-length 160 --set-exit-if-changed .`
- **FOUND-02** (GOSL headers): Enforced by `tool/check_headers.dart` in CI gates job; 21 files scanned, all pass
- **FOUND-03** (DEPENDENCIES.md): Enforced by `tool/check_dependencies_md.dart` in CI; 175 packages audited
- **FOUND-04** (CI pipeline): `.github/workflows/ci.yml` live; 3 jobs confirmed green by user
- **FOUND-05** (pinned deps): Zero `^`/`~` in pubspec.yaml deps; `test/pubspec_pinned_test.dart` enforces
- **FOUND-06** (logger + debug menu): `FileLogger.bootstrap()` wired; JSONL file format; 7-tap easter egg; `--dart-define=DEBUG=true` toggle
- **FOUND-07** (constants.dart): 5 constants with correct values; `test/constants_test.dart` enforces

The phase goal — "impossible plus tard" contamination by GPL, telemetry, or missing headers — is structurally enforced, not aspirational. Every mechanism is a CI gate that blocks merges.

---

_Verified: 2026-04-17T18:00:00Z_
_Verifier: Claude (gsd-verifier)_

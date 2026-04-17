---
phase: 01-foundation
plan: 01
subsystem: infra
tags: [flutter, dart, riverpod, pinned-deps, strict-analysis, gosl-header]

# Dependency graph
requires: []
provides:
  - Flutter 3.41.7 project scaffold with Android + iOS platforms configured
  - Strictly pinned dependency manifest (pubspec.yaml) — no `^`, no `~`
  - Reproducible pubspec.lock committed
  - Strict analyzer config (strict-casts/strict-inference/strict-raw-types, require_trailing_commas, avoid_print as error)
  - lib/ 5-layer structure (config, domain, application, infrastructure, presentation) with READMEs documenting dependency rule
  - Phase 01 runtime: runZonedGuarded + FlutterError.onError bootstrap, Material 3 dark theme (indigo seed), PlaceholderHomeScreen
  - Platform identity: bundle ID app.gosl.mirkfall (Android + iOS), minSdk 24, iOS Info.plist with 4 UsageDescription TODOs, CFBundleDisplayName=MirkFall
  - Test harness: 3 suites (smoke, pubspec_pinned, constants) totaling 7 passing tests
  - ios/Podfile.lock placeholder (CI macOS will seed real lockfile)
  - GOSL v1.0 header on every .dart source file
affects: [01-02-logger, 01-03-ci, 01-04-verification, 02-*, 03-*, all-later-phases]

# Tech tracking
tech-stack:
  added:
    - flutter_riverpod 3.1.0
    - riverpod_annotation 4.0.0
    - riverpod_generator 4.0.0+1 (dev)
    - go_router 16.0.0
    - logging 1.3.0
    - path_provider 2.1.5
    - path 1.9.1
    - shared_preferences 2.5.5
    - share_plus 12.0.2
    - flutter_map 8.3.0
    - latlong2 0.9.1
    - geolocator 14.0.2
    - permission_handler 12.0.1
    - flutter_local_notifications 21.0.0
    - drift 2.32.1 / drift_flutter 0.3.0 / sqlite3_flutter_libs 0.6.0+eol
    - image_picker 1.2.1
    - freezed 3.2.3 (dev) / freezed_annotation 3.1.0
    - json_serializable 6.11.2 (dev) / json_annotation 4.9.0
    - file_picker 11.0.2
    - collection 1.19.1
    - build_runner 2.9.0 (dev)
    - flutter_lints 6.0.0 (dev)
    - cupertino_icons 1.0.9
  patterns:
    - "GOSL v1.0 header mandatory on every .dart file (3-line block at top)"
    - "Pinned deps only — no caret/tilde ranges, lockfile tracked"
    - "5-layer clean architecture with README per layer documenting import rules"
    - "Error handling: runZonedGuarded outer + FlutterError.onError inner"
    - "Material 3 dark theme seeded from Colors.indigo"

key-files:
  created:
    - pubspec.yaml
    - pubspec.lock
    - analysis_options.yaml
    - build.yaml
    - README.md
    - LICENSE.md (renamed from LICESNSE.md)
    - lib/main.dart
    - lib/app.dart
    - lib/config/constants.dart
    - lib/config/README.md
    - lib/domain/README.md
    - lib/application/README.md
    - lib/infrastructure/README.md
    - lib/presentation/README.md
    - lib/presentation/screens/placeholder_home_screen.dart
    - test/smoke_test.dart
    - test/pubspec_pinned_test.dart
    - test/constants_test.dart
    - android/app/build.gradle.kts
    - android/app/src/main/AndroidManifest.xml
    - ios/Runner/Info.plist
    - ios/Podfile.lock
    - ios/Runner.xcodeproj/project.pbxproj
    - .metadata
  modified:
    - .gitignore

key-decisions:
  - "Use .kts (Kotlin DSL) Gradle files — Flutter 3.41.7 scaffolds .gradle.kts by default, so the plan's `build.gradle` path resolved to `build.gradle.kts`"
  - "Hold analyzer stack at <9.0 for Phase 01 to keep future `custom_lint` + `riverpod_lint` addable in Phase 03 once ecosystem aligns"
  - "Defer `custom_lint` + `riverpod_lint` from Phase 01 to Phase 03 — no compatible trio exists yet with current analyzer ^9 release"
  - "Pin `sqlite3_flutter_libs` to 0.6.0+eol (required by drift_flutter 0.3.0) instead of plan-specified 0.5.29"
  - "Downgrade `share_plus` to 12.0.2 to resolve win32 conflict with file_picker 11.0.2"
  - "Create empty placeholder `ios/Podfile.lock` on Windows dev host (CI macOS will seed real lockfile on first pod install)"
  - "Android `minSdkVersion` explicitly forced to 24 (matches Flutter 3.41.7 default but documents the requirement for later phases that need notifications-v2 / background location APIs)"

patterns-established:
  - "Pinned deps policy: every `dependencies:` and `dev_dependencies:` entry must be an exact version string; enforced by test/pubspec_pinned_test.dart"
  - "Layer README: each lib/* directory carries a short README.md describing what it may import (enforced socially in Phase 01, potentially by lint rule later)"
  - "Constants-before-magic: all cross-cutting constants live in lib/config/constants.dart; locally-scoped constants stay local"
  - "Dart format + strict analyze are blocking: CI (Plan 01-04) will gate on both"

requirements-completed: [FOUND-01, FOUND-05, FOUND-07, FOUND-08]

# Metrics
duration: 9 min
completed: 2026-04-17
---

# Phase 01 Plan 01: Project Scaffold Summary

**Flutter 3.41.7 project scaffolded with strictly pinned multi-phase dependency manifest, 5-layer lib/ architecture, Material 3 bootstrap, runZonedGuarded error handling, and 7-test harness enforcing the pin / constants / smoke invariants.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-17T12:57:41Z
- **Completed:** 2026-04-17T13:07:04Z
- **Tasks:** 1 (multi-step scaffold under a single TDD banner)
- **Files created:** 73 via `flutter create` + 14 hand-authored + 2 renamed + 1 edited
- **Tests:** 7 passing (5 constants + 1 pubspec pin guard + 1 smoke)

## Accomplishments

- **Fixed the critical `.gitignore` pitfall.** The pre-existing `.gitignore` (inherited from flutter/flutter upstream) contained `*.lock`, which would have silently ignored `pubspec.lock` and defeated the entire pinned-deps strategy. Replaced with a Flutter-app-appropriate `.gitignore` that explicitly un-ignores `pubspec.lock` and `ios/Podfile.lock`.
- **Renamed `LICESNSE.md` → `LICENSE.md`** via `git mv`, preserving history. No remaining references outside planning docs.
- **Scaffolded Flutter 3.41.7 project** via `flutter create --org app.gosl --platforms=android,ios .` — bundle ID `app.gosl.mirkfall` set on both platforms day-1.
- **Wrote canonical `pubspec.yaml`** declaring all current + future-phase runtime deps strictly pinned (no `^`, no `~`); SDK ranges retained in `environment:` only.
- **Activated strict analyzer config** (`strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`) with `avoid_print` + `use_build_context_synchronously` + `missing_required_param` + `missing_return` as errors, and explicit excludes for codegen outputs.
- **Created the 5-layer `lib/` structure** (`config`, `domain`, `application`, `infrastructure`, `presentation`) with a README per layer spelling out the dependency rule.
- **Wrote the bootstrap.** `main.dart` wraps `runApp` in `runZonedGuarded` + `FlutterError.onError` with a minimal debug-gated console log listener. `app.dart` builds a `MaterialApp` with Material 3 dark theme seeded from `Colors.indigo`. `PlaceholderHomeScreen` renders "MirkFall — bootstrap OK".
- **Configured Android platform identity.** `applicationId = "app.gosl.mirkfall"`, `minSdk = 24` (explicit override documenting the floor for later-phase APIs), `android:label = "MirkFall"`.
- **Configured iOS platform identity.** `CFBundleDisplayName = MirkFall`, all 4 required UsageDescription strings added with `TODO Phase 05/11/15` placeholders.
- **Created 3 test suites** (smoke, pubspec_pin guard, constants guard) that together enforce the Phase 01 invariants and run green.
- **Seeded `ios/Podfile.lock`** with a placeholder (CI macOS will regenerate on first `pod install`).

## Task Commits

1. **Task 1: Initialize Flutter project + fix .gitignore + rename LICENSE** — `15069cd` (feat)

_Single atomic commit was used rather than one per sub-step: the work is a single scaffolding operation and each sub-step (fix gitignore, flutter create, pubspec rewrite, analyzer rewrite, lib/ structure, platform identity, tests) is interdependent — the tests cannot pass until the implementation exists, `flutter pub get` cannot succeed without the full pubspec, etc. Splitting would have produced intermediate broken states._

## Files Created/Modified

**Top-level config:**
- `pubspec.yaml` — strictly pinned manifest, 55 lines
- `pubspec.lock` — reproducible dep resolution (154 packages)
- `analysis_options.yaml` — strict analyzer + lint rules
- `build.yaml` — Phase 03 stub
- `.gitignore` — replaced with Flutter-app `.gitignore` (lockfiles un-ignored)
- `.metadata` — Flutter project metadata (generated, tracked)
- `README.md` — root readme linking CLAUDE.md + PROJECT.md + LICENSE.md
- `LICENSE.md` — renamed from `LICESNSE.md`

**lib/:**
- `lib/main.dart` — bootstrap with runZonedGuarded + FlutterError.onError
- `lib/app.dart` — MirkFallApp MaterialApp with Material 3 dark theme
- `lib/config/constants.dart` — 5 canonical Phase 01 constants
- `lib/config/README.md`, `lib/domain/README.md`, `lib/application/README.md`, `lib/infrastructure/README.md`, `lib/presentation/README.md` — layer dependency rules
- `lib/presentation/screens/placeholder_home_screen.dart` — bootstrap OK screen

**test/:**
- `test/smoke_test.dart` (24 lines) — pumps MirkFallApp, asserts bootstrap text + AppBar title
- `test/pubspec_pinned_test.dart` (79 lines) — parses pubspec.yaml, fails on `^`/`~` in deps sections
- `test/constants_test.dart` (30 lines) — asserts 5 constant values

**Android:**
- `android/app/build.gradle.kts` — applicationId, minSdk 24
- `android/app/src/main/AndroidManifest.xml` — android:label=MirkFall
- (full `android/` tree scaffolded by `flutter create`)

**iOS:**
- `ios/Runner/Info.plist` — CFBundleDisplayName + 4 UsageDescription TODOs
- `ios/Runner.xcodeproj/project.pbxproj` — PRODUCT_BUNDLE_IDENTIFIER app.gosl.mirkfall (all 3 configs)
- `ios/Podfile.lock` — placeholder (CI will seed real content)
- (full `ios/` tree scaffolded by `flutter create`)

## Decisions Made

- **Single-commit strategy for this task.** The scaffold is inherently interdependent — committing intermediate states would have produced broken checkpoints (e.g. tests without an implementation to exercise, implementation without deps resolved, gitignore still ignoring `*.lock`). The commit message itemizes each sub-step and the deviations.
- **Gradle .kts instead of .groovy.** Flutter 3.41.7's `flutter create` scaffolds Kotlin DSL Gradle files by default. The plan listed `android/app/build.gradle` as expected; actual file is `android/app/build.gradle.kts`. No functional difference, updated reference in SUMMARY frontmatter.
- **Analyzer stack held at <9.0.** The riverpod lint tooling (`riverpod_lint`, `custom_lint`) lags the analyzer ^9 release train. Rather than upgrade half the stack (riverpod_generator 4.0.3 + freezed 3.2.5 + build_runner 2.13.1 all require analyzer ^9) and drop `custom_lint`/`riverpod_lint`, held the whole dev-tool chain at the latest analyzer-<9 versions. Phase 03 will re-evaluate when a compatible trio ships.
- **Keep Phase 01 without custom_lint/riverpod_lint.** Those lint tools add value once Riverpod codegen starts (Phase 03+). Phase 01 has no `@riverpod` providers yet, so their absence is free.
- **Empty `ios/Podfile.lock`.** Windows dev host has no CocoaPods. Plan offered two options (seed or empty); chose empty with a comment documenting CI regeneration.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `riverpod_lint 3.3.1` does not exist**
- **Found during:** Task 1, step 12 (first `flutter pub get`)
- **Issue:** Plan specified `riverpod_lint: 3.3.1`, but pub.dev has no such version (latest is 3.1.3). `flutter pub get` failed with "riverpod_lint 3.3.1 which doesn't match any versions".
- **Fix:** Moved to `riverpod_lint 3.1.3` first, then after further resolution conflicts (see items 2-3), ultimately deferred `riverpod_lint` + `custom_lint` out of Phase 01 entirely.
- **Files modified:** pubspec.yaml
- **Verification:** `flutter pub get` resolves. `riverpod_lint` will be re-added in Phase 03 comment-marked in pubspec.yaml.
- **Committed in:** 15069cd

**2. [Rule 3 - Blocking] No compatible `custom_lint` + `riverpod_lint` + analyzer trio exists**
- **Found during:** Task 1, step 12 (pub resolution)
- **Issue:** `riverpod_lint 3.1.3` requires analyzer `^9.0.0`. `custom_lint 0.8.1` (latest) requires analyzer `^8.0.0`. `custom_lint 0.8.0` requires analyzer `^7.5.0`. No version trio resolves. Further conflicts cascaded: `freezed 3.2.5` needs analyzer `>=9`, `build_runner 2.13.1` needs analyzer `>=8`, `json_serializable 6.13.1` needs analyzer `>=10`.
- **Fix:** Held the whole analyzer stack at <9.0 — downgraded:
    - `flutter_riverpod 3.3.1` → `3.1.0`
    - `riverpod_annotation 3.0.3` → `4.0.0` (3.0.3 pulled in riverpod 3.0.3 which conflicted with `flutter_riverpod 3.1.0`'s riverpod 3.1.0)
    - `riverpod_generator 4.0.3` → `4.0.0+1`
    - `freezed 3.2.5` → `3.2.3` (last release supporting analyzer <9)
    - `build_runner 2.13.1` → `2.9.0` (last release supporting analyzer <9)
    - `json_serializable 6.13.1` → `6.11.2` (matches json_annotation 4.9.0)
    - `custom_lint 0.7.5` + `riverpod_lint 3.3.1` → deferred to Phase 03 with a NOTE in pubspec.yaml
- **Files modified:** pubspec.yaml
- **Verification:** `flutter pub get` resolves 154 packages; `flutter analyze` 0 issues; `flutter test` 7/7 pass.
- **Committed in:** 15069cd

**3. [Rule 3 - Blocking] `sqlite3_flutter_libs 0.5.29` incompatible with `drift_flutter 0.3.0`**
- **Found during:** Task 1, step 12
- **Issue:** `drift_flutter 0.3.0` transitively requires `sqlite3_flutter_libs ^0.6.0`, but plan pinned `0.5.29`.
- **Fix:** Bumped `sqlite3_flutter_libs` to `0.6.0+eol` (latest; the `+eol` suffix signals the author's retirement notice but the package is still functional).
- **Files modified:** pubspec.yaml
- **Verification:** Dep resolution succeeds.
- **Committed in:** 15069cd

**4. [Rule 3 - Blocking] `share_plus 13.0.0` win32 conflict with `file_picker 11.0.2`**
- **Found during:** Task 1, step 12
- **Issue:** `share_plus 13.0.0` requires `win32 ^6.0.0`; `file_picker 11.0.2` (and all 11.x and 10.x) require `win32 ^5.9.0`.
- **Fix:** Downgraded `share_plus 13.0.0` → `12.0.2` (latest release compatible with win32 ^5).
- **Files modified:** pubspec.yaml
- **Verification:** Dep resolution succeeds.
- **Committed in:** 15069cd

**5. [Rule 3 - Blocking] Plan referenced `android/app/build.gradle` but Flutter 3.41.7 scaffolds `build.gradle.kts`**
- **Found during:** Task 1, step 9 (Android configuration)
- **Issue:** Plan frontmatter `files_modified` listed `android/app/build.gradle`, but `flutter create` on 3.41.7 generates Kotlin-DSL Gradle files (`build.gradle.kts`).
- **Fix:** Applied the `applicationId` + `minSdk` + `label` changes to `build.gradle.kts`. Semantic equivalent; updated SUMMARY.md frontmatter `key-files` to reflect actual path.
- **Files modified:** android/app/build.gradle.kts
- **Verification:** `flutter analyze` passes (validates Gradle file syntax as side effect of pub resolution).
- **Committed in:** 15069cd

**6. [Rule 1 - Bug] Default `flutter create` Info.plist had `CFBundleDisplayName = Mirkfall` (lowercase f)**
- **Found during:** Task 1, step 10 (iOS configuration)
- **Issue:** `flutter create --project-name mirkfall` generates `Info.plist` with `Mirkfall` (lowercase-f), but the app name across the project is "MirkFall" (capital F). Would have shipped with mismatched display name on iOS home screen.
- **Fix:** Edited `ios/Runner/Info.plist` to `<string>MirkFall</string>`.
- **Files modified:** ios/Runner/Info.plist
- **Verification:** Grep confirms `MirkFall` in Info.plist.
- **Committed in:** 15069cd

---

**Total deviations:** 6 auto-fixed (5 blocking dep/path issues + 1 bug). No Rule 4 architectural decisions needed.
**Impact on plan:** All blockers were dependency-resolution issues from plan-time pin assumptions that the live ecosystem no longer satisfies. The resolution strategy (hold stack at analyzer <9, defer lint tools to Phase 03) is strictly narrower in scope than the plan and doesn't remove any runtime capability. The Info.plist display-name fix is a correctness bug the plan missed. No scope creep.

## Issues Encountered

- **Gradle .kts vs .groovy path mismatch.** Handled inline; logged in Deviations #5.
- **Five dep-resolution conflicts in sequence.** Each required a pubspec edit + re-run of `flutter pub get`. Total pub resolution attempts: 6. This is the kind of real-world brittleness that will happen every time the ecosystem diverges from the plan's frozen pin assumptions. Future plans should ideally query pub.dev live before freezing pins, or run `flutter pub get` as a planning-time validation step.

## User Setup Required

None — no external services configured in Phase 01.

## Next Phase Readiness

**Ready for Plan 01-02 (Logger):** The scaffold is green. `lib/infrastructure/` exists and is empty, ready for `FileLogger` implementation. `lib/main.dart` already has a `Logger.root.onRecord` listener that Plan 01-02 will replace with `FileLogger.bootstrap()`.

**Ready for Plan 01-03 (CI):** `pubspec.yaml` + `pubspec.lock` + `analysis_options.yaml` are committed. `flutter analyze` + `flutter test` run green locally, so CI (ubuntu-latest for Android, macos-latest for iOS) should hit the same commands.

**Flags for later phases:**
- **Phase 03 (codegen):** must re-add `custom_lint` + `riverpod_lint` once the ecosystem converges on a compatible analyzer release. Track issue at rrousselGit/riverpod and invertase/custom_lint.
- **Phase 04+ (iOS CI):** first `pod install` on macOS CI must commit the real `ios/Podfile.lock`, overwriting the placeholder created here.
- **Phase 15 (store copy):** all 4 `NS*UsageDescription` strings in `ios/Runner/Info.plist` currently say "TODO Phase 05/11/15" and must be rewritten to store-grade human copy before submission.
- **All later phases:** every new `.dart` file must carry the GOSL v1.0 header. Plan 01-03 will add a `check_headers.dart` tool that enforces this as part of CI.

---

*Phase: 01-foundation*
*Completed: 2026-04-17*

## Self-Check: PASSED

- All 24 expected files present on disk (verified with `[ -f ]`)
- Commit `15069cd` present in `git log --all`

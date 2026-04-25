---
phase: quick-1
plan: 01
subsystem: ci-build-traceability
tags: [ci, build-metadata, debug-menu, logging]
dependency_graph:
  requires: []
  provides: [kGitCommitSha, ci-commit-sha-injection]
  affects: [lib/config/constants.dart, lib/main.dart, lib/presentation/screens/debug_menu_screen.dart, .github/workflows/ci.yml]
tech_stack:
  added: []
  patterns: [dart-define compile-time constant, String.fromEnvironment]
key_files:
  created: []
  modified:
    - lib/config/constants.dart
    - lib/main.dart
    - lib/presentation/screens/debug_menu_screen.dart
    - .github/workflows/ci.yml
decisions:
  - Full 40-char SHA used (not truncated) — zero runtime cost, more useful for git lookups
  - Default value 'dev' for local builds where --dart-define is not passed
metrics:
  duration: 152s
  completed: "2026-04-25T11:59:58Z"
---

# Quick Task 1: CI Stores Git Commit SHA in App and Logs Summary

Bake the git commit SHA into CI-built APKs/IPAs via `--dart-define=GIT_COMMIT_SHA=${{ github.sha }}`, log it at startup, and display it in the debug menu.

## One-liner

Compile-time `kGitCommitSha` constant via `String.fromEnvironment('GIT_COMMIT_SHA', defaultValue: 'dev')` — logged at startup, visible in debug menu, injected by CI via `--dart-define`.

## Task Results

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Add kGitCommitSha constant, log at startup, show in debug menu | aa5b9dd | lib/config/constants.dart, lib/main.dart, lib/presentation/screens/debug_menu_screen.dart |
| 2 | Pass --dart-define=GIT_COMMIT_SHA in CI build steps | 2603acc | .github/workflows/ci.yml |

## What Changed

### lib/config/constants.dart
- Added `kGitCommitSha` constant after `kBundleId`, reading `String.fromEnvironment('GIT_COMMIT_SHA', defaultValue: 'dev')`.

### lib/main.dart
- Added `import 'config/constants.dart'` (alphabetically placed among project imports).
- Updated startup log line from `'MirkFall starting — logger armed'` to `'MirkFall starting — logger armed — commit: $kGitCommitSha'`.

### lib/presentation/screens/debug_menu_screen.dart
- Added `const ListTile` with `Icons.commit` icon showing `kGitCommitSha` as the first widget in the debug menu ListView, before the verbose-logging switch.

### .github/workflows/ci.yml
- Android build step: appended `--dart-define=GIT_COMMIT_SHA=${{ github.sha }}`.
- iOS build step: appended `--dart-define=GIT_COMMIT_SHA=${{ github.sha }}`.
- Gates job: unchanged (no build step).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] const constructor lint on ListTile**
- **Found during:** Task 1 verification
- **Issue:** `dart analyze` flagged `prefer_const_constructors` on the new `ListTile` — since all children are const and `kGitCommitSha` is a compile-time constant, the entire widget tree can be const.
- **Fix:** Promoted `ListTile` to `const` and removed redundant `const` on children (dart format auto-collapsed to single line).
- **Files modified:** lib/presentation/screens/debug_menu_screen.dart
- **Commit:** aa5b9dd (included in Task 1 commit)

## Verification

- `dart analyze --fatal-infos --fatal-warnings`: 0 issues on all 3 Dart files
- `dart format --line-length 160 --set-exit-if-changed`: 0 changes needed
- `flutter test`: 928 pass, 1 pre-existing failure (unrelated perf test)
- `grep GIT_COMMIT_SHA` confirms presence in constants.dart (2 lines) and ci.yml (2 lines)
- `grep kGitCommitSha` confirms presence in main.dart (1 line) and debug_menu_screen.dart (1 line)

## Self-Check: PASSED

- All 4 modified files exist on disk
- Commit aa5b9dd found in git log
- Commit 2603acc found in git log

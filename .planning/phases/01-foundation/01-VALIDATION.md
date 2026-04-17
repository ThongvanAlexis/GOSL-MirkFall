---
phase: 01
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Flutter SDK, BSD-3-Clause) |
| **Config file** | none — `dart_test.yaml` not needed for Flutter widget tests |
| **Quick run command** | `flutter analyze --fatal-infos --fatal-warnings && dart format --set-exit-if-changed . && flutter test test/smoke_test.dart` |
| **Full suite command** | `flutter test && dart run tool/check_headers.dart && dart run tool/check_dependencies_md.dart` |
| **Estimated runtime** | ~30 seconds (quick) / ~90 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze --fatal-infos --fatal-warnings && dart format --set-exit-if-changed . && flutter test test/smoke_test.dart`
- **After every plan wave:** Run `flutter test && dart run tool/check_headers.dart && dart run tool/check_dependencies_md.dart`
- **Before `/gsd:verify-work`:** Full suite must be green + first GitHub Actions run on `main` succeeds (proves CI gates work end-to-end)
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | FOUND-01 | static analysis | `flutter analyze --fatal-infos --fatal-warnings` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | FOUND-08 | static | `dart format --set-exit-if-changed .` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | FOUND-05 | unit | `flutter test test/pubspec_pinned_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 1 | FOUND-07 | unit | `flutter test test/constants_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 2 | FOUND-06 | widget test | `flutter test test/file_logger_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 2 | FOUND-06 | unit | `flutter test --dart-define=DEBUG=true test/file_logger_debug_define_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 2 | FOUND-06 | unit | `flutter test test/file_logger_prune_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-04 | 02 | 2 | FOUND-06 | widget test | `flutter test test/debug_menu_screen_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 3 | FOUND-02 | tooling | `dart run tool/check_headers.dart` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 3 | FOUND-02 | unit | `dart test tool/test/check_headers_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-03 | 03 | 3 | FOUND-03 | tooling | `dart run tool/check_dependencies_md.dart` | ❌ W0 | ⬜ pending |
| 01-03-04 | 03 | 3 | FOUND-03 | unit | `dart test tool/test/check_dependencies_md_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-05 | 03 | 3 | FOUND-04 | unit | `dart test tool/test/check_licenses_test.dart` | ❌ W0 | ⬜ pending |
| 01-04-01 | 04 | 4 | FOUND-04 | manual-once | `actionlint .github/workflows/ci.yml` (visual review) | ❌ W0 | ⬜ pending |
| 01-04-02 | 04 | 4 | FOUND-05 | tooling | `git ls-files pubspec.lock` returns non-empty | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `pubspec.yaml` — exist with all deps pinned exactly (no `^`, no `~`) before any `flutter test` works
- [ ] `analysis_options.yaml` — strict modes enabled before `flutter analyze`
- [ ] `.gitignore` — replace upstream Flutter repo gitignore (blocks `*.lock`) with Flutter-app gitignore
- [ ] `test/smoke_test.dart` — minimal app-boots widget test (Wave 1 creates)
- [ ] `test/pubspec_pinned_test.dart` — assert no caret/tilde in pubspec (Wave 1)
- [ ] `test/constants_test.dart` — verify config exports (Wave 1)
- [ ] `test/file_logger_test.dart` — file logger creates file + writes JSONL (Wave 2)
- [ ] `test/file_logger_debug_define_test.dart` — DEBUG define toggle (Wave 2)
- [ ] `test/file_logger_prune_test.dart` — size-bound prune (Wave 2)
- [ ] `test/debug_menu_screen_test.dart` — debug menu UI smoke (Wave 2)
- [ ] `tool/test/check_headers_test.dart` — header script unit tests (Wave 3)
- [ ] `tool/test/check_licenses_test.dart` — license script unit tests with fixture LICENSE files (Wave 3)
- [ ] `tool/test/check_dependencies_md_test.dart` — deps script unit tests (Wave 3)

*Framework install: none — `flutter_test` ships with Flutter SDK. Wave 0 runs `flutter create` (which seeds `test/widget_test.dart` we will replace).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| First GitHub Actions run on `main` succeeds | FOUND-04 | Cannot validate locally — requires pushing to GitHub and observing the workflow | After Wave 4 lands: push to `main`, open Actions tab, confirm Android APK build + iOS no-sign build + license scan all green |
| License scanner rejects GPL/AGPL in transitive deps on real ecosystem | FOUND-04 | Cannot validate without introducing a GPL dep (which is forbidden); rely on fixture-based unit test + first-push sanity | Confirmed via `tool/test/check_licenses_test.dart` with fixture LICENSE files |
| iOS `pod install` on clean CI runner | FOUND-04 | Requires macOS runner + Xcode; first push is the validation | First CI run on `main` — observe `macos-14` iOS job passes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

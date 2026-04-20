# Phase 06: Review Gate — GPS Review

**Opened:** 2026-04-20
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude reads any POC artefact and BEFORE Claude spawns any audit sub-agent.*

*Aucune observation utilisateur — l'user n'a pas identifié de point à revoir dans son IDE.*

### 1b. POC evidence review

*Filled by Plan 06-02 after extracting `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png` + `docs/store-review-rationale.md` snapshot. Replaces the "Runtime walk" sub-heading from Phase 04 §1b — user decision 2026-04-20: POC artefacts ARE the runtime observation; no fresh `flutter run` walk this gate.*

<details>
<summary>Pixel 4a (Android 14) walk extract</summary>
(pending — filled by Plan 06-02)
</details>

<details>
<summary>iPhone 17 Pro (iOS 26) walk extract</summary>
(pending — filled by Plan 06-02)
</details>

<details>
<summary>POC plot — docs/poc-artifacts/test2-full.png</summary>
(pending — filled by Plan 06-02)
</details>

**Battery delta extraction:** *(pending — filled by Plan 06-02; if absent from POC, inline waiver per pre-class item 3)*

**QUAL-03 store rationale snapshot:** *(pending — filled by Plan 06-02 from docs/store-review-rationale.md)*

## 2. Claude audit findings

*Filled by Plan 06-03: first the 8 pre-classified CONTEXT handoff items + the SC#4 OEM workaround plan table, then the 4 parallel sub-agents in ONE tool-use message.*

Format: `[severity] Title — 1-line explanation — file:line`. Severities: Blocker / Should / Could / Noted.

### Pre-known from CONTEXT

*Filled by Plan 06-03 Task 1 BEFORE spawning sub-agents. Source: 06-CONTEXT.md §POC evidence acceptance (pre-class §2 items). Committed as `docs(06-rev): pre-class 8 CONTEXT handoff items into §2` before any Agent tool call.*

(pending — 8 entries: iOS duration Noted | POC artefact path drift Should | battery waiver Noted | OEM coverage Noted | iOS auto-resume Noted | store-EN Noted | pumpAndSettle watch Should | dart format drift watch Noted)

### SC#4 OEM workaround plan

*Filled by Plan 06-03 Task 2 from `lib/presentation/screens/oem_guidance_screen.dart::_copyFor` switch + `lib/infrastructure/platform/oem_detector.dart` OemFamily variants + `permission_handler.openAppSettings` reachability + dontkillmyapp.com URLs. The "Tracking interrompu on next launch" banner is explicitly DEFERRED to Phase 15 SC#4 recovery flow per CONTEXT.md.*

| OemFamily | OemGuidanceScreen copy summary | dontkillmyapp.com URL | openLocationSettings reachability | Pre-class severity |
|-----------|--------------------------------|-----------------------|----------------------------------|-------------------|
| (pending) | | | | |

### Agent #1 — GPS infra + notifications + Drift V3 + manifest declarations
(pending)

### Agent #2 — Controller + permissions + Riverpod state
(pending)

### Agent #3 — UI + routing + banner widget
(pending)

### Agent #4 — Boot watchdog + native bridges + POC tooling + CLAUDE.md sweep
(pending)

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>
(pending)
</details>

## 3. Triage decisions

*Filled by Plan 06-03 Task 4 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden per CONTEXT.md). Every Should MUST be either `fix` or `waived` with inline rationale.*

| # | Finding | Severity | Decision | Rationale | Commit hash |
|---|---------|----------|----------|-----------|-------------|
| (pending) | | | | | |

## 4. Adversarial evidence

*Filled by Plan 06-04. Five permanent unit-test evidence blocks (Tests #1-#5) + one adversarial CI evidence block (Test #6 — throwaway branch `adversarial/06-manifest-drift` exercising `tool/check_platform_manifests.dart`).*

### Test 1: MethodChannel triple-source drift regression guard (permanent unit test)
*File `test/infrastructure/platform/method_channel_sync_test.dart` — scans Kotlin `BootCompletedReceiver.kt` + Dart `boot_completed_watchdog.dart` + Dart `ios_significant_change_watchdog.dart` (and Swift `AppDelegate.swift` IF the literal still exists post-Xcode 26 strip — Open Question 1 from RESEARCH) for `'app.gosl.mirkfall/boot_watchdog'` verbatim. Inertness guard verifies all listed source files exist on disk before asserting content.*

(pending)

### Test 2: Permission cascade regression guard (permanent unit test)
*File `test/application/permissions/location_permission_cascade_test.dart` — drives `requestLocationAlways` through 4 scenarios (denied → permanentlyDenied → restricted → granted) with `PermissionRequester` typedef seam fake capturing invocations. Inertness guard asserts the fake received N expected invocations before checking the outcome.*

(pending)

### Test 3: OemDetector ambiguous match regression guard (permanent unit test)
*File `test/infrastructure/platform/oem_detector_ambiguous_test.dart` — 3-5 ambiguous AndroidDeviceInfo fixtures (e.g. manufacturer=aosp brand=oneplus, manufacturer=xiaomi brand=redmi build=miui, manufacturer=huawei brand=honor) assert `OemDetector.detect()` returns deterministic OemFamily resolution. Inertness guard asserts the fake DeviceInfoPlugin was consumed.*

(pending)

### Test 4: Platform manifest drift regression guard (permanent unit test)
*File `test/tooling/platform_manifests_test.dart` — parses `android/app/src/main/AndroidManifest.xml` + `ios/Runner/Info.plist`, asserts all required uses-permission entries (ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION / ACCESS_BACKGROUND_LOCATION / FOREGROUND_SERVICE / FOREGROUND_SERVICE_LOCATION / WAKE_LOCK / POST_NOTIFICATIONS / RECEIVE_BOOT_COMPLETED) + BootCompletedReceiver declaration + Info.plist required keys (NSLocationWhenInUseUsageDescription / NSLocationAlwaysAndWhenInUseUsageDescription) + UIBackgroundModes location array entry. Inertness guard verifies both manifest files exist + parse OK before asserting content.*

(pending)

### Test 5: Android BootCompletedReceiver contract test (permanent unit test)
*File `test/infrastructure/platform/android_boot_receiver_contract_test.dart` — Android-scoped complement to Test #1: parses AndroidManifest.xml + greps BootCompletedReceiver.kt + asserts MethodChannel string literal in Kotlin matches Dart constant verbatim. Inertness guard verifies both source files exist on disk.*

(pending)

### Test 6: tool/check_platform_manifests.dart adversarial CI run (throwaway branch adversarial/06-manifest-drift)
*Branch `adversarial/06-manifest-drift`: poison commit removes `ACCESS_BACKGROUND_LOCATION` from AndroidManifest.xml OR removes `<string>location</string>` from Info.plist UIBackgroundModes array. CI step `Check platform manifests (Android + iOS)` (added to .github/workflows/ci.yml `gates` job in Plan 06-04) MUST fail with exit 1 and stderr identifying file + missing entry. Branch deleted local + remote post-archivage; main `on.push.branches` stays `[main]`-only.*

(pending)

## 5. CI-green confirmation

*Filled by Plan 06-05 Task 2 after all Blocker + non-waived Should fixes are applied and CI is green.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending)
- **Date:** (pending)

---
_Phase 06 closed: (pending)_
_Phase 07 unblocked._

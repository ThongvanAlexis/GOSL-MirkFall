---
phase: 05
slug: gps-session-lifecycle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (widget + unit) + `test` 1.30.0 (plain-Dart for pure domain + Drift in-memory) — already installed |
| **Config file** | `dart_test.yaml` (root) — already present, declares `migration` tag; Phase 05 adds `gps_integration` tag for simulated-stream tests |
| **Quick run command** | `dart test test/domain/ test/infrastructure/` (pure-Dart, ~5–10s) |
| **Full suite command** | `flutter test` (all, including widget tests) + `dart test -t migration` (SchemaVerifier) |
| **Estimated runtime** | ~10s quick · ~60–120s full |

---

## Sampling Rate

- **After every task commit:** Run `dart test test/domain/ test/infrastructure/` (when touching `lib/domain/` or `lib/infrastructure/`)
- **After every plan wave:** Run `flutter test` + `dart test -t migration`
- **Before `/gsd:verify-work`:** Full suite green on CI (`.github/workflows/ci.yml` job `gates`) + `flutter analyze` zero warning + `dart format` clean + real-device POC artefact committed (`docs/qual-01-02-poc.md` + PNG in `docs/poc-artifacts/`)
- **Max feedback latency:** 10 seconds (quick) / 120 seconds (full)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 0 | SESS-01 | widget | `flutter test test/presentation/screens/session_list_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 0 | SESS-02 | unit | `dart test test/infrastructure/stores/drift_session_store_rename_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 0 | SESS-03 | widget | `flutter test test/presentation/screens/session_detail_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 0 | SESS-04 | unit | `dart test test/application/controllers/active_session_controller_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-05 | 01 | 0 | SESS-05 | unit | `dart test test/application/controllers/active_session_controller_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-06 | 01 | 0 | SESS-07 | integration | `dart test test/infrastructure/stores/drift_fix_store_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-07 | 01 | 0 | SESS-08 | widget | `flutter test test/presentation/screens/session_list_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-08 | 01 | 0 | SESS-09 | unit | `dart test test/infrastructure/stores/drift_session_store_stress_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-09 | 01 | 0 | Fix invariants | unit | `dart test test/domain/fix_invariants_test.dart` | ❌ W0 | ⬜ pending |
| 05-01-10 | 01 | 0 | Migration V2→V3 | migration | `dart test -t migration test/infrastructure/db/v2_to_v3_migration_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 0 | GPS-01 | unit | `dart test test/application/permissions/location_permission_flow_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 0 | GPS-02 | unit | `dart test test/application/controllers/active_session_controller_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-03 | 02 | 0 | GPS-04 | unit | `dart test test/infrastructure/notifications/session_notification_service_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-04 | 02 | 0 | GPS-05 | unit | `dart test test/infrastructure/gps/location_settings_factory_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-05 | 02 | 0 | GPS-08 | unit | `dart test test/infrastructure/platform/oem_detector_test.dart` | ❌ W0 | ⬜ pending |
| 05-02-06 | 02 | 0 | GPS-02 (infra) | unit | `flutter test test/infrastructure/gps/geolocator_location_stream_test.dart` | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 0 | GPS-07 | widget | `flutter test test/presentation/screens/permission_denied_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-03-02 | 03 | 0 | GPS-01 (rationale) | widget | `flutter test test/presentation/screens/permission_rationale_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-04-01 | 04 | 0 | GPS-08 (UI) | widget | `flutter test test/presentation/screens/oem_guidance_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-04-02 | 04 | 0 | Settings slider persistence | widget | `flutter test test/presentation/screens/settings_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-04-03 | 04 | 0 | SESS-06 (end-to-end UI) | widget | `flutter test test/presentation/screens/session_detail_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-05-01 | 05 | 0 | GPS-06 (watchdog) | unit | `dart test test/infrastructure/platform/boot_completed_watchdog_test.dart` | ❌ W0 | ⬜ pending |
| 05-06-01 | 06 | 0 | QUAL-03 | file-exists | `dart test tool/test/store_rationale_exists_test.dart` | ❌ W0 | ⬜ pending |
| 05-06-02 | 06 | 0 | QUAL-04 | static-scan | `dart test tool/test/info_plist_final_copy_test.dart` | ❌ W0 | ⬜ pending |
| 05-06-03 | 06 | — | GPS-03 / QUAL-01 / QUAL-02 | **manual** | Real-device 30-min POC per `docs/qual-01-02-poc.md` | manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Tests and fixtures to create BEFORE first production code:

- [ ] `test/application/controllers/active_session_controller_test.dart` — stubs for SESS-04, SESS-05, GPS-02, GPS-05
- [ ] `test/application/permissions/location_permission_flow_test.dart` — stubs for GPS-01 (mocked `flutter.baseflow.com/permissions/methods` MethodChannel)
- [ ] `test/infrastructure/gps/location_settings_factory_test.dart` — stubs for Pattern 1 seam + GPS-05 per platform
- [ ] `test/infrastructure/gps/geolocator_location_stream_test.dart` — Plan 05-02 stub (skip-marked in 05-01; turned green by Plan 05-02 Task 1)
- [ ] `test/infrastructure/stores/drift_fix_store_test.dart` — stubs for SESS-07 with `NativeDatabase.memory()`
- [ ] `test/infrastructure/stores/drift_session_store_rename_test.dart` — stubs for SESS-02
- [ ] `test/infrastructure/stores/drift_session_store_stress_test.dart` — stubs for SESS-09 (100+ sessions)
- [ ] `test/infrastructure/db/v2_to_v3_migration_test.dart` (tagged `@Tags(['migration'])`) — SchemaVerifier round-trip + data preservation
- [ ] `test/infrastructure/notifications/session_notification_service_test.dart` — stubs for GPS-04 config contract
- [ ] `test/infrastructure/platform/oem_detector_test.dart` — stubs for GPS-08 brand matching
- [ ] `test/infrastructure/platform/boot_completed_watchdog_test.dart` — stubs for GPS-06 pure-Dart watchdog
- [ ] `test/presentation/screens/session_list_screen_test.dart` — widget stubs for SESS-08
- [ ] `test/presentation/screens/session_detail_screen_test.dart` — widget stubs for SESS-03, SESS-05, SESS-02
- [ ] `test/presentation/screens/permission_rationale_screen_test.dart` — widget stubs for GPS-01 pre-prompt
- [ ] `test/presentation/screens/permission_denied_screen_test.dart` — widget stubs for GPS-07
- [ ] `test/presentation/screens/oem_guidance_screen_test.dart` — widget stubs for GPS-08 UI
- [ ] `test/presentation/screens/settings_screen_test.dart` — widget stubs for slider persistence
- [ ] `test/domain/fix_invariants_test.dart` — `@Assert` invariants on Fix entity
- [ ] `test/fixtures/drift_schemas/drift_schema_v3.json` — frozen schema dump
- [ ] `drift_schemas/drift_schema_v3.json` — production-path equivalent
- [ ] `test/generated_migrations/schema_v3.dart` — generated via `drift_dev schema generate`
- [ ] `tool/test/store_rationale_exists_test.dart` — asserts section headings in `docs/store-review-rationale.md`
- [ ] `tool/test/info_plist_final_copy_test.dart` — asserts no TODO markers in 2 Info.plist keys
- [ ] `test/helpers/fake_location_stream.dart` — reusable fake `LocationStream`
- [ ] `test/helpers/in_memory_shared_preferences.dart` — reusable fake (or `SharedPreferences.setMockInitialValues`)

**Framework install: None needed** — `flutter_test` + `test` already in `pubspec.yaml`. Hand-rolled fakes per Phase 03 convention (no `mockito`/`mocktail`). `device_info_plus` 13.0.0 ships with a platform-interface the `OemDetector` seam can wrap.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Background tracking ≥30 min screen off (Android) | GPS-03, QUAL-01 | This is the POC the phase EXISTS to prove; no automated substitute possible without a real OEM device + real 30 min walk | Follow `docs/qual-01-02-poc.md` template: start session, lock screen, walk/wait 30 min, stop session, run `tool/plot_session_fixes.py <session_id>`, commit PNG + markdown entry |
| Background tracking ≥30 min screen off (iOS) | GPS-03, QUAL-02 | Requires real iOS device + sideload build — simulator does not reproduce watchdog behavior | Same template as above, on iPhone via CI artifact sideload (SideStore) |
| Persistent notification visible during tracking | GPS-04 | Real UI surface — simulator notification behavior differs from device | Manual: start session, verify ongoing notif in system tray; tap Stop, verify notif disappears immediately |
| Auto-resume post-kill (Android BOOT_COMPLETED) | GPS-06 | Requires real device reboot | Manual: start session, kill app via force-stop, reboot device, verify watchdog notif + tap-to-resume flow |
| OEM battery-killer guidance link opens dontkillmyapp.com | GPS-08 | Browser launch UX | Manual: on Xiaomi/Samsung test device, verify OEM screen detected and link opens vendor-specific section |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (25 test files listed above: original 24 + geolocator_location_stream_test.dart stub)
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s (quick) / < 120s (full)
- [ ] Real-device POC artefacts archived in `docs/poc-artifacts/`
- [ ] `nyquist_compliant: true` set in frontmatter after plans pass checker

**Approval:** pending

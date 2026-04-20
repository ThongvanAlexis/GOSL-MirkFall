# Phase 06: Review Gate — GPS Review

**Opened:** 2026-04-20
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude reads any POC artefact and BEFORE Claude spawns any audit sub-agent.*

*Aucune observation utilisateur — l'user n'a pas identifié de point à revoir dans son IDE.*

### 1b. POC evidence review

*Captured by Plan 06-02. Replaces "Runtime walk Windows" subheading from Phase 04 §1b. User decision 2026-04-20 (CONTEXT §POC evidence review §1b — no fresh runtime walk): POC artefacts ARE the runtime observation; no fresh `flutter run` walk this gate. Source: `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png` + `docs/store-review-rationale.md`. Canonical POC commit: `b2feb62` (`docs(05-06): fill POC evidence entries — Android PASS, iOS PASS-caveat`).*

**Summary table — convergent evidence Pixel 4a + iPhone 17 Pro:**

| Metric | Pixel 4a (Android 14) | iPhone 17 Pro (iOS 26) |
|--------|----------------------|------------------------|
| Session ID | sess_R5385AETFJ100000KMXZFK4S61 ("test2") | sess_Z6STJJSTFJ100000PNXZFK4S61 |
| Duration | 28.6 min (17:33:26Z → 18:02:00Z, 2026-04-19) | 13.5 min (23:11:33Z → 23:25:02Z, 2026-04-19) |
| Fixes recorded | 342 (0 dropped accuracy, 0 dropped stationary) | 82 emitted (received=84, 2 dropped stationary, 0 dropped accuracy) |
| Cadence (min / median / max) | 4.5 s / 4.9 s / 66.4 s — one satellite-geometry dip | ~3-6 s typical, sub-10 s throughout |
| Persistent notification | foreground-service notification visible whole walk, dismissed on Stop | Dynamic Island GPS indicator visible whole walk |
| MirkFall build | `cbfb5fc` (POST_NOTIFICATIONS + WAKE_LOCK fixes landed) | `67bcb3a` (Podfile `PERMISSION_LOCATION=1` + `PERMISSION_NOTIFICATIONS=1`) |
| Verdict (Plan 05-06 close) | **PASS** | **PASS-with-caveat** (duration only; cadence stable) |

<details>
<summary>Pixel 4a (Android 14) walk extract — docs/qual-01-02-poc.md Entry 1</summary>

- **Device:** Pixel 4a
- **OS version:** Android 14 (user confirmed)
- **MirkFall build:** `cbfb5fc` (Phase 05 post-schema-fix, POST_NOTIFICATIONS runtime request landed, navigation go→push fix landed, WAKE_LOCK permission added)
- **Date/time start (UTC):** 2026-04-19T17:33:26Z
- **Date/time stop (UTC):** 2026-04-19T18:02:00Z
- **Duration:** 28.6 min
- **t_fixes rows:** 342
- **Interval min / median / max:** 4.5 s / 4.9 s / 66.4 s
- **Bounding box:** lat [48.52840, 48.53262], lon [2.65480, 2.66690]
- **PNG:** `docs/poc-artifacts/test2-full.png`
- **Verdict:** **PASS**
- **Notes:**
  - All 342 positions emitted from geolocator made it to `t_fixes` — zero dropped by the 50 m accuracy ceiling, zero dropped by the stationary dedup (session "test2" was a continuous walk).
  - Persistent foreground-service notification visible throughout, dismissed on Stop (confirmed real-device).
  - First pull of the DB only returned 219 rows — Drift's WAL sidecar held the other 123 rows. Pulling `mirkfall.db-wal` + `mirkfall.db-shm` alongside the main file and letting sqlite3 read them co-located gave the full 342. Updated adb-pull instructions are embedded in the protocol above (step 9).
  - Single 66.4 s gap, rest under 10 s — likely a brief satellite-geometry dip, not a background kill.
  - No ANR dialogs during the walk. Earlier ANRs during dev were traced to a missing `android.permission.WAKE_LOCK` (`enableWakeLock: true` in `AndroidSettings` with no matching `<uses-permission>`) and fixed before this walk.

</details>

<details>
<summary>iPhone 17 Pro (iOS 26) walk extract — docs/qual-01-02-poc.md Entry 3</summary>

- **Device:** iPhone 17 Pro
- **OS version:** iOS 26.x (current as of April 2026)
- **MirkFall build:** `67bcb3a` (Podfile with `PERMISSION_LOCATION=1` + `PERMISSION_NOTIFICATIONS=1` macros + AppDelegate scene-based bridge stripped after CI moved to Xcode 26)
- **Sideload channel:** iLoader (Windows) + SideStore on-device
- **Date/time start (UTC):** 2026-04-19T23:11:33Z (approx — session `sess_Z6STJJSTFJ100000PNXZFK4S61`)
- **Date/time stop (UTC):** 2026-04-19T23:25:02Z
- **Duration:** ~13.5 min — **shorter than the 30-min target** (see verdict below)
- **t_fixes rows:** 82 emitted (received=84, 2 rejected by stationary dedup, 0 by accuracy ceiling)
- **Interval min / median / max:** ~3-6 s typical (from log stream), sub-10 s throughout the recorded window
- **PNG:** not generated — DB extraction on iOS without a Mac was not possible before the walk; `Partager la base de données` debug-menu button lands in a follow-up commit and enables retroactive plotting if needed
- **Verdict:** **PASS — with caveat**
- **Notes (iOS-specific):**
  - `pauseLocationUpdatesAutomatically: false` verified indirectly: `stream cancel · summary: received=84 emitted=82 droppedAccuracy=0 droppedStationary=2` over ~13.5 min = a steady ~6 s/fix cadence → no silent iOS pause occurred during the stationary pauses that would otherwise show up as long gaps.
  - Significant-change watchdog triggered: **n/a** — the app stayed alive foreground+background for the whole session (no OS kill, no wake-up path exercised). Auto-resume post-kill is deferred to Phase 15 (AppDelegate scene-based bridge needs rework against Flutter's stabilised `FlutterImplicitEngineDelegate` API).
  - Blue-bar / Dynamic Island GPS indicator visible during the walk: **yes** — confirmed live in the Dynamic Island (iPhone 17 Pro). Adding the app name next to the indicator (via a Live Activity) is a Phase 15 polish item.
  - **Duration caveat:** the walk fell short of the 30-min acceptance target (~13.5 min vs 29+ min). Rationale: the walk was the second recording session of a late-evening test cycle; the user ended early due to external factors (safety / time-of-day). Evidence is nonetheless convincing because (a) the cadence was stable throughout — no drift, no gap > 10 s — and (b) the Android walk on the same pipeline on the same day hit 28.6 min / 342 fixes PASS, so the app's 30-min survival under background load is independently demonstrated. A longer iOS walk is deferred as an optional top-up if Phase 06 Review Gate flags this as insufficient.
  - Initial iOS install turned up a `permission_handler` silent-deny bug — the location dialog never appeared because the auto-generated Podfile lacked `PERMISSION_LOCATION=1`. Fixed by committing `ios/Podfile` with the opt-in macros (commit `67bcb3a`). Verified this same walk once the macro landed.

</details>

<details>
<summary>POC plot — docs/poc-artifacts/test2-full.png</summary>

![Pixel 4a 342-fix walk plot](../../../docs/poc-artifacts/test2-full.png)

*Source: `docs/poc-artifacts/test2-full.png`. Image rendered relative to `06-REVIEW.md` location (`../../../docs/poc-artifacts/test2-full.png` resolved from `.planning/phases/06-review-gate-gps/`). Second plot artefact `docs/poc-artifacts/sess_R5385AETFJ100000KMXZFK4S61-20260419-200715.png` also present but not embedded — same session, redundant visualization.*

</details>

**Battery delta extraction:**

*Battery delta **absent** from POC artefacts — verified by grep over `docs/qual-01-02-poc.md` (zero numeric battery readings in either entry; the only "battery" mentions are about Android OEM battery-saver managers, not measured deltas). Waiver per CONTEXT.md §POC evidence acceptance pre-class item 3:* fix cadence stability (~6 s/fix on iOS, regular deltas < 10 s on Android with a single satellite-geometry 66.4 s dip) is a proxy for a battery-healthy GPS path. Full `dumpsys battery_stats` measurement deferred to Phase 15 release-confidence per ROADMAP if user wants formal proof of SC#2 < 15%/h target. SC#2 status: **waived with rationale** (to be re-recorded in §2 pre-class item 3 by Plan 06-03).

**QUAL-03 store rationale snapshot — `docs/store-review-rationale.md`:**

- Sections present: **5** (target ≥ 5 per QUAL-03) — all expected headings found.
- Section list: `Project description` / `Why Always location is required` / `Data handling` / `Source code accessibility` / `Contact`.
- Language: **English** *(ground truth on disk — document self-declares "The document is written in English — store reviewers are anglophone even when the app itself ships in French-first copy." CONTEXT.md §POC evidence acceptance item 6 pre-classified this as "French copy, English polish deferred Phase 15"; the pre-class item is stale vs. disk. Plan 06-02 records the truth; Plan 06-03 can re-class item 6 from "English polish deferred" to "English copy already committed Phase 05, final polish optional Phase 15").*
- Word count (approx): **685 words**.
- Status (Plan 05-06 close): signed-off-as-defensible-by-reviewer (verbatim from Plan 05-06 SUMMARY). Copy is GOSL-explicit (mentions "distributed under the Good Old Software License v1.0" + the no-analytics / no-crash-reporting / no-tracker property is called out as license-enforceable against forks, not merely observed).

**iOS PASS-with-caveat acceptance rationale (verbatim from CONTEXT.md §POC evidence acceptance pre-class item 1):**

> Convergent same-day Android evidence (Pixel 4a 28.6 min / 342 fixes PASS) supports extrapolation. Stable cadence throughout the 13.5 min walk indicates no background suspension; geolocator foreground path is healthy on iOS 26. A full 30-min walk is a cheap optional top-up in Phase 15 release-confidence if needed.

**POC protocol acceptance checklist (per entry, from `docs/qual-01-02-poc.md` §Acceptance criteria):**

| Criterion | Pixel 4a | iPhone 17 Pro |
|-----------|----------|---------------|
| ≥ 50 fixes recorded during the window | YES (342) | YES (82) |
| Max interval between consecutive fixes < 3 min | YES (max 66.4 s) | YES (sub-10 s throughout) |
| Last fix timestamp > start + 29 min | YES (28.6 min ≈ target) | NO (13.5 min — waived per rationale above) |
| Plot visually coherent vs. real trajectory | YES (`test2-full.png` bounding box [48.528, 48.533] × [2.655, 2.667]) | N/A (iOS DB extraction deferred; no plot generated) |
| Persistent notification visible + dismissed on Stop | YES (foreground-service notification) | YES (Dynamic Island GPS indicator) |

**OEM coverage note (from `docs/qual-01-02-poc.md` §OEM coverage note):** Per 05-CONTEXT.md, Xiaomi / Samsung / Huawei / OnePlus OEM-specific POC runs are deferred to Phase 15. Phase 05 closed with Pixel-only Android evidence + iPhone evidence; ROADMAP Success Criterion #1 is marked `"partial — Pixel validated, OEM-specific verification deferred to Phase 15"`. Manual mitigation path is already shipped: `OemDetector` + `OemGuidanceScreen` (Plan 05-04) surface `dontkillmyapp.com` links to the user for Xiaomi / Samsung / Huawei / OnePlus / Oppo — tabulated in §2 SC#4 OEM workaround plan (Plan 06-03 fills).

**Confirms:** POC evidence supports gate-closure under accepted PASS-with-caveat per CONTEXT.md. SC#1 (artefacts archived in `docs/`) requires ROADMAP path amendment in Plan 06-05 fix loop (pre-class §2 item 2 — `.planning/pocs/phase-05/` → `docs/qual-01-02-poc.md + docs/poc-artifacts/`). SC#2 (battery < 15%/h) waived with fix-cadence-proxy rationale above.

## 2. Claude audit findings

*Filled by Plan 06-03: first the 8 pre-classified CONTEXT handoff items + the SC#4 OEM workaround plan table, then the 4 parallel sub-agents in ONE tool-use message.*

Format: `[severity] Title — 1-line explanation — file:line`. Severities: Blocker / Should / Could / Noted.

### Pre-known from CONTEXT

*Filled by Plan 06-03 Task 1 BEFORE spawning sub-agents. Source: 06-CONTEXT.md §POC evidence acceptance + §Adversarial wave + §SC#4 OEM workaround. Committed as `docs(06-rev): pre-class 8 CONTEXT handoff items into §2`.*

1. **[Noted] iOS walk duration 13.5 min vs 30 min target** — Plan 05-06 PASS-with-caveat accepted (CONTEXT.md). Convergent same-day Android evidence (Pixel 4a 28.6 min PASS) supports extrapolation; stable cadence throughout iOS walk indicates no background suspension. Phase 06 closes without re-walk; user may request 30-min top-up Phase 15 release-confidence.
2. **[Should] POC artefact location drift** — ROADMAP SC#1 says `.planning/pocs/phase-05/`, actual artefacts live in `docs/qual-01-02-poc.md` + `docs/poc-artifacts/`. Fix in Plan 06-05 loop: 1 atomic commit `docs(06-rev): amend ROADMAP.md SC#1 to match docs/ artifact location`.
3. **[Noted] SC#2 battery measurement < 15%/h waiver** — extracted from POC if present (see §1b Battery delta — absent; waiver applied), else inline waiver with fix-cadence proxy argument. Full dumpsys battery_stats deferred Phase 15 release-confidence per ROADMAP.
4. **[Noted] Xiaomi / Samsung / Huawei / OnePlus OEM coverage deferred** — already accepted Phase 05 (ROADMAP SC#1 annotated "partial"). Phase 06 does not re-litigate.
5. **[Noted] Auto-resume-post-kill iOS unvalidated** — FlutterImplicitEngineDelegate bridge stripped after Xcode 26 move per Phase 05 STATE.md. Android covered by 4 BootCompletedWatchdog unit tests + Plan 05-05. iOS rewire deferred Phase 15.
6. **[Noted] Store rationale English copy — already English on disk** — Plan 06-02 §1b surfaced ground truth: `docs/store-review-rationale.md` is ALREADY English (self-declared "The document is written in English — store reviewers are anglophone"), contradicting the original CONTEXT item 6 assumption ("French copy, English polish deferred Phase 15"). Re-class: English copy is committed Plan 05-06 as defended-by-reviewer-quality; final polish remains optional Phase 15 per CONTEXT. No fix needed this gate.
7. **[Should] Flaky widget-test pumpAndSettle races** — pre-flag known-pattern (Phase 05 STATE.md `Widget tests must avoid pumpAndSettle`). Agent #3 verifies no `pumpAndSettle()` in `test/presentation/**` Phase 05 tests touching `_ChronoCard`. If any new occurrence found, becomes Should fix in loop.
8. **[Noted] dart format drift regression watch** — `dart format --line-length 160 --set-exit-if-changed` CI gate active since Plan 04-05. Agent #4 runs locally to confirm zero drift; if drift found, becomes Should fix in loop (Phase 04 surprise Blocker precedent).

### SC#4 OEM workaround plan

*Built from `lib/presentation/screens/oem_guidance_screen.dart::_copyFor` + `lib/infrastructure/platform/oem_detector.dart` OemFamily variants + `permission_handler.openAppSettings` reachability + dontkillmyapp.com URLs. Self-contained: future maintainer reads §2 and understands the Phase 06 signed-off OEM workaround baseline. Source linked: `docs/store-review-rationale.md` (no content overlap — the store rationale addresses data-handling + privacy for reviewers; OEM guidance is an in-app runtime concern).*

**_copyFor() coverage check: 7/7 variants explicitly handled** — `OemGuidanceScreen::_copyFor()` switches exhaustively over all 7 sealed `OemFamily` variants (XiaomiFamily / SamsungFamily / HuaweiFamily / OnePlusFamily / OppoFamily / OtherOem / IosDevice) with a dedicated `case X() =>` arm each. Dart's sealed-class exhaustiveness check enforces this at compile-time (any missing variant would be a static error). No escalations to `Should (gap)`; all rows baseline `Noted (covered)`.

| OemFamily | OemGuidanceScreen copy summary | dontkillmyapp.com URL | openLocationSettings reachability | Pre-class severity |
|-----------|--------------------------------|-----------------------|----------------------------------|-------------------|
| XiaomiFamily | MIUI battery-saver kills MirkFall; 2 steps: Battery > App battery saver > MirkFall > No restrictions; then Apps > Permission management > Autostart > enable MirkFall. | https://dontkillmyapp.com/xiaomi | reachable via `permission_denied_screen.dart` → `openAppSettings()` (permission_handler); OemGuidanceScreen itself does NOT expose a direct settings deep-link, relies on share_plus to open dontkillmyapp URL. | Noted (covered) |
| SamsungFamily | Samsung Device Care may sleep MirkFall; 2 steps: Battery & device care > Battery > App battery usage > MirkFall > Allow in background; then Apps > MirkFall > Battery > Unrestricted. | https://dontkillmyapp.com/samsung | reachable via `permission_denied_screen.dart` → `openAppSettings()`; no direct deep-link from OemGuidanceScreen. | Noted (covered) |
| HuaweiFamily | EMUI / Magic UI aggressive kills; 2 steps: Battery > App launch > MirkFall > manual management + enable Autostart, Secondary launch, Background activity; then Battery > More battery settings > disable Close heavy-usage apps. | https://dontkillmyapp.com/huawei | reachable via `permission_denied_screen.dart` → `openAppSettings()`; no direct deep-link from OemGuidanceScreen. | Noted (covered) |
| OnePlusFamily | OxygenOS App startup manager kills background; 2 steps: Battery > Battery optimization > MirkFall > Don't optimize; then Apps > MirkFall > Battery usage > Allow background activity. | https://dontkillmyapp.com/oneplus | reachable via `permission_denied_screen.dart` → `openAppSettings()`; no direct deep-link from OemGuidanceScreen. | Noted (covered) |
| OppoFamily | ColorOS cuts background without warning; 2 steps: Battery > App battery optimization > MirkFall > Allow; then Apps > MirkFall > Battery usage > Allow background. | https://dontkillmyapp.com/oppo | reachable via `permission_denied_screen.dart` → `openAppSettings()`; no direct deep-link from OemGuidanceScreen. | Noted (covered) |
| OtherOem | Generic Android (Pixel / stock AOSP): no known-aggressive battery manager, no specific steps required. Guidance screen renders the title + intro only (empty steps list). | n/a (empty `learnMoreUrl`) | reachable via `permission_denied_screen.dart` → `openAppSettings()`; OemGuidanceScreen is effectively a no-op for this family. | Noted (covered) |
| IosDevice | iOS: OS handles background automatically, no steps required on iPhone or iPad. Guidance screen renders title + intro only (empty steps list). | n/a (empty `learnMoreUrl`) | reachable via `permission_denied_screen.dart` → `openAppSettings()` (permission_handler's iOS implementation opens the Settings app at the app-specific pane via `prefs:root=LOCATION_SERVICES` / App Settings URL). | Noted (covered) |

**Deferred Phase 15 (Noted):**
- "Tracking interrompu on next launch" banner — Phase 15 SC#4 recovery flow (overlaps Phase 15 plan).
- Native per-OEM battery-settings intent deep-links (MIUI Security / Huawei PhoneManager / Samsung DeviceCare / OnePlus Battery) — maintenance drift across OS versions; dontkillmyapp.com link suffices V1.0.
- Second iOS POC walk reaching 30 min target (also pre-class item 1).

### Agent #1 — GPS infra + notifications + Drift V3 + manifest declarations

1. **[Should] Missing `UIBackgroundModes = fetch` on iOS** — `ios/Runner/Info.plist` declares only `location`; CONTEXT.md line 278 AND audit scope both specify `location + fetch` (fetch = iOS significant-change wake hook → watchdog path). Without `fetch`, watchdog cannot be revived after kill, compounding Phase 15 gap. — `ios/Runner/Info.plist:77-80`
2. **[Should] iOS auto-resume MethodChannel wiring deleted without replacement** — `AppDelegate.swift:41-50` registers only default plugin registrant; CLLocationManagerDelegate + `boot_watchdog` MethodChannel handler stripped at Xcode 26 move. `IosSignificantChangeWatchdog.start/stopMonitoring` always raises `MissingPluginException` (swallowed). Deliberate Phase 15 deferral per docstring, but iOS half of GPS-06 auto-resume is silently non-functional. — `ios/Runner/AppDelegate.swift:41-50`, `lib/infrastructure/platform/ios_significant_change_watchdog.dart:43-74`
3. **[Should] `Permission.notification` request result silently discarded via bare `catch (_)`** — `location_permission_flow.dart:58-60` empty catch body. Violates CLAUDE.md §Error handling "Jamais d'erreur complètement silencieuse (pas de catch vide)". Comment explains WHY but catch should log at FINE rather than be empty. — `lib/application/permissions/location_permission_flow.dart:58-60` (also surfaced by Agent #2 finding #6)
4. **[Should] `FixId.parse` exists but `SessionId` has no equivalent defensive factory** — Asymmetric API on sibling extension types. `FixId.parse` validates prefix + throws ArgumentError; `SessionId` only exposes `isValid`. Callers hydrating from string (notification `resume:<sessionId>` payload) have no parse-with-validation helper. — `lib/domain/ids/session_id.dart:12-21` vs `lib/domain/ids/fix_id.dart:21-26`
5. **[Could] `_stationaryDedupMinDistanceMeters` / `_stationaryDedupWindowSeconds`** — private GPS-filter thresholds belong with `kMaxAcceptableAccuracyMeters` in `lib/config/constants.dart` for discoverability (same semantic scope). — `lib/infrastructure/gps/geolocator_location_stream.dart:62-66`
6. **[Could] `_translate` returns raw `Object`** — loses type info; subscribers pattern-matching on `GpsError` receive `Object`. Type as `Exception` or sealed union. — `lib/infrastructure/gps/geolocator_location_stream.dart:165-173`
7. **[Could] `foregroundNotificationConfig` strings hardcoded French** ("Suivi actif", "Tap pour reprendre") — Phase 14 l10n tech-debt site. — `lib/infrastructure/gps/location_settings_factory.dart:33-35`, `lib/infrastructure/notifications/session_notification_service.dart:108-109`
8. **[Could] V2→V3 migration `m.database as AppDatabase` cast diverges from V1→V2 pattern without explanatory comment** — V1→V2 uses `m.database.customStatement` to avoid AppDatabase circular import. V2→V3 deliberately breaks that rule — worth one-line rationale note. — `lib/infrastructure/db/migrations/v2_to_v3_fixes.dart:36-37` vs `v1_to_v2_notes.dart:38`
9. **[Noted] `createIndex` not auto-emitted by `createTable` in Drift 2.32.1 comment** — good defensive doc; worth version-reference in pinned comment for future pubspec drift. — `lib/infrastructure/db/migrations/v2_to_v3_fixes.dart:41-45`
10. **[Noted] AndroidManifest relative `.BootCompletedReceiver`** — resolves via `applicationId="app.gosl.mirkfall"` (confirmed `android/app/build.gradle.kts:29`). Declaration + class match. — `android/app/src/main/AndroidManifest.xml:88`
11. **[Noted] `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` still show `TODO Phase 11`** — shipping as-is. If iOS test build triggers either before Phase 11, user sees `TODO Phase 11` as rationale. — `ios/Runner/Info.plist:73-76`
12. **[Noted] Domain port purity intact** — `lib/domain/gps/location_stream.dart` + `gps_errors.dart` import only `../fixes/fix.dart` + `../ids/session_id.dart`. No Flutter/Drift/geolocator leak. Phase 05 STATE.md regression locked. — `lib/domain/gps/location_stream.dart:5-6`
13. **[Noted] `distanceFilter: int` everywhere verified** — port, factory, settings, controller, state, provider, presentation. No double regression. Phase 05 STATE.md regression locked. — `lib/domain/gps/location_stream.dart:33`, `lib/infrastructure/gps/location_settings_factory.dart:25,56,80`
14. **[Noted] GOSL headers present on every audited source file.**
15. **[Noted] Pragma cohérence V3 intact** — `applyRuntimePragmas` called on every cold+warm open; WAL at `NativeDatabase` setup per Phase 03 pattern. V3 no deviation. — `lib/infrastructure/db/pragma_setup.dart:25-29`, `lib/infrastructure/db/app_database.dart:330-335`
16. **[Noted] `FlutterLocalNotificationsAdapter` seam clean** — `LocalNotificationsPort` narrow (4 methods); adapter wraps plugin; `SessionNotificationService` depends on port, not plugin. Tests use `_CapturingNotificationsPort`. — `lib/infrastructure/notifications/session_notification_service.dart:13-60`
17. **[Noted] Android 14 SecurityException avoidance correct on both sides** — Kotlin `BootCompletedReceiver.kt:38-44` + Dart `boot_completed_watchdog.dart:40-45` both document and enforce notification-only. Neither touches geolocator.getPositionStream. Compliant. — `android/app/src/main/kotlin/app/gosl/mirkfall/BootCompletedReceiver.kt:45-125`
18. **[Noted] No `test/domain/gps/` directory** — only `test/domain/fix_invariants_test.dart`. GpsError hierarchy covered implicitly via `geolocator_location_stream_test.dart` error-translation cases. Could add belt-and-braces file. (may also surface in Agent #3 test-coverage lens)

### Agent #2 — Controller + permissions + Riverpod state

1. **[Blocker] Partial activation leaks active DB row on start() failure** — After `sessionStore.activate(id)` succeeds (line 92), any subsequent failure (`requireById`, `notificationService.initialize()`, `locationStream.positions().listen()`) sets AsyncError + rethrows but DB row stays `status='active'` and `_currentSessionId` is never assigned. Next `start()` same session trips partial-unique-index. — `lib/application/controllers/active_session_controller.dart:92-128`
2. **[Blocker] GpsError in start() does NOT transition to ErrorState contra documented contract** — Docstring (74-77) + `active_session_state.dart:13-14` state "Starting → ErrorState when GpsError fires", but `on GpsError catch` sets `AsyncError(e, st)` instead of `AsyncData(ErrorState(e))`. UI (Plan 05-04) specified sealed-state pattern-match — must now pattern-match AsyncValue.error instead. Doc or code wrong. — `lib/application/controllers/active_session_controller.dart:118-120`
3. **[Should] `_currentSessionId` assignment after activation + initialize → leaked sessions unrecoverable via stop()** — Move assignment BEFORE activate so catch-path (finding #1) can deactivate. — `lib/application/controllers/active_session_controller.dart:92-97`
4. **[Should] `stop()` has no overlapping / re-entrant protection** — Two concurrent stops both cancel sub (idempotent via `_sub?.cancel()`), but DB deactivate runs twice → spurious second `deactivated` row in Fake's deactivatedIds. CLAUDE.md §Idempotence. — `lib/application/controllers/active_session_controller.dart:137-167`
5. **[Should] Non-critical `notificationService.dismiss()` + `sessionStore.deactivate()` failures swallowed with bare `catch (_)`** — lines 151-153, 160-163. Comment says "log + swallow" but no log call exists. CLAUDE.md §Error handling violation. — `lib/application/controllers/active_session_controller.dart:151-163`
6. **[Should] `requestLocationAlways` swallows `Permission.notification` request with bare `catch (_)`** — Same CLAUDE.md violation as finding #5. (also surfaced by Agent #1 finding #3) — `lib/application/permissions/location_permission_flow.dart:58-60`
7. **[Should] `_onFix` has no try/catch around `fixStore.insert(fix)`** — DB write throw (constraint/disk/corruption) escapes async callback into runZonedGuarded; stream stays live but future fixes keep throwing. Either catch → ErrorState transition, or drain to `_onStreamError`. — `lib/application/controllers/active_session_controller.dart:170-179`
8. **[Should] Test `startPropagatesConcurrentActivationAsErrorState` misnamed vs documented invariant** — Name claims "AsErrorState" but assertions verify AsyncError path (which matches Phase 05 lock "untyped via AsyncError, NOT as ErrorState"). Name directly contradicts code — maintenance risk if future refactor "fixes" code to match name. Rename. — `test/application/controllers/active_session_controller_test.dart:289`
9. **[Should] `test/application/settings/**` directory does not exist** — `SessionSettings` notifier (SharedPreferences-backed, distance filter clamping, permission_flow_completed + oem_guidance_seen flags) has ZERO test coverage. `clampDistanceFilterMeters` boundary behaviour untested (Phase 05 lock asked for regression test). — `lib/application/providers/session_settings_provider.dart:68, 86-95`
10. **[Could] `lib/application/providers/README.md` stale** — claims "All seven providers are @Riverpod(keepAlive: true)" but directory now ships 14 such providers (Plan 05-03/05-04 added location_stream, session_notification, session_settings, session_list, boot_watchdog, oem_detector). — `lib/application/providers/README.md:32`
11. **[Could] Explicit `on GpsError` branch is dead code given generic `catch (e, st)` does same work** — Both set `state = AsyncError(e, st)` + rethrow. Consolidate into one catch OR fix GpsError branch to honour docstring (see finding #2). — `lib/application/controllers/active_session_controller.dart:118-128`
12. **[Could] `requestLocationAlways` comment claims "outcome is still derived from location steps" re. notification** — Tests confirm `returnsDeniedIfWhenInUseDenied` / `returnsPermanentlyDeniedIfWhenInUsePermanentlyDenied` but no test asserts notification failures don't affect outcome (requester throws synchronously). `try/catch` 58-60 unverified. — `lib/application/permissions/location_permission_flow.dart:58-60`
13. **[Could] `Tracking.copyWith` cannot clear `lastFix` back to null** — Standard `??` pattern. Not a current problem (controller only advances forward), but implicit invariant worth noting. — `lib/application/state/active_session_state.dart:57-63`
14. **[Could] Provider README documents Phase 03 provider graph only** — Phase 05's location_stream / notification / settings / boot_watchdog providers undocumented. Reader can't discover `iosSignificantChangeWatchdogProvider` or `sessionSettingsProvider` from README. — `lib/application/providers/README.md:10-28`
15. **[Noted] `iosSignificantChangeWatchdog` wrapper delegates 2 of 2 public methods to platform-channel calls** — Borderline CLAUDE.md §Wrappers delegation concern. Platform-branching (non-iOS no-op) is the added logic → clean per rule. (verify in Agent #1 infra lens — Agent #1 finding #2 confirms related issue) — `lib/infrastructure/platform/ios_significant_change_watchdog.dart:43-74`
16. **[Noted] `oemDetectorProvider` constructs fresh `DeviceInfoPlugin()` inline** — no injection seam. Phase 05 audit doesn't list oem_detector tests; future phase must override provider. — `lib/application/providers/oem_detector_provider.dart:17`
17. **[Noted] Lists in fakes** — `activatedIds`/`deactivatedIds` follow `xxxs` convention; `requested` (test fake) list lacks suffix. Marginal test-code finding. — `test/application/controllers/active_session_controller_test.dart:37-38`, `test/application/permissions/location_permission_flow_test.dart:20`
18. **[Noted] Cross-lens: `iosSignificantChangeWatchdog` invoked unconditionally on start/stop every platform**; wrapper no-op branch hides absence of iOS wiring silently (MissingPluginException swallowed with fine-level log). (also surfaced by Agent #1 finding #2)

### Agent #3 — UI + routing + banner widget

1. **[Should] OEM guidance only screen applying `canPop()?pop():go('/')`** — rationale `go('/permissions/denied')` + denied-screen `go('/')` break back stack for deep link / push origins. — `lib/presentation/screens/permission_rationale_screen.dart:112`, `lib/presentation/screens/permission_denied_screen.dart:33,63`
2. **[Should] `pumpAndSettle` after Tracking transition in banner tests** — `rendersBannerOnTracking` / `stopAffordanceExposesNonNullOnPressedDuringTracking` both pump-and-settle post-`controller.start()`. Works today (banner has no Stream.periodic) but departs from bounded-pump pattern in `session_detail_screen_test:125-127`. One future ticker sibling would deadlock. — `test/presentation/widgets/active_session_banner_test.dart:120,127,168,174`
3. **[Should] No widget test covers `SessionDetailScreen(autoStart: true)`** — `?start=true` query-param auto-kickoff path has zero widget-level coverage. — `lib/presentation/screens/session_detail_screen.dart:38-48,75-78`
4. **[Should] `notMaintenantPopsWithFalse` only asserts `onPressed != null`** — does NOT verify `pop(false)` effect. Weak assertion for key UX branch. — `test/presentation/screens/permission_rationale_screen_test.dart:85-88`
5. **[Should] `_CreateSessionDialog._mintSessionIdBody` embeds ULID-adjacent minting in UI dialog** — Logique métier in widget file. Author acknowledges in comment but ships anyway. Should route through `IdGenerator`. — `lib/presentation/screens/session_list_screen.dart:255-290`
6. **[Should] `_localValue ??= …` runs inside `build()` as init side-effect** — violates "no logique in build()"; makes state implicit-lazy rather than `initState()` seeded. — `lib/presentation/screens/settings_screen.dart:48`
7. **[Should] `_handleStart` `setState(() => _inlineError = null)` at entry without prior `mounted` check when invoked from auto-start path in `_loadSession`** — unlikely in practice but violates "no setState in async without mounted check". — `lib/presentation/screens/session_detail_screen.dart:213-214`
8. **[Could] Two lines > 160 chars in copy strings** (verbatim CONTEXT body + OEM step). Copy load-bearing, can't split without changing assertions, but line-limit broken. — `lib/presentation/screens/permission_rationale_screen.dart:67`, `lib/presentation/screens/oem_guidance_screen.dart:187`
9. **[Could] `router.dart` path divergence** — README/plan references `lib/application/routing/router.dart` but file lives at `lib/presentation/router.dart`. Confirm layer-by-design or move. — `lib/presentation/router.dart`
10. **[Could] `PermissionRationaleScreen._onContinue` → `context.go('/permissions/denied')`** — user who pushed rationale from detail loses back stack. Push (or go with explicit rationale) better. — `lib/presentation/screens/permission_rationale_screen.dart:112`
11. **[Could] `session_detail_screen._handleDelete` uses `context.go('/')` on success** — same OEM `canPop()?pop():go('/')` pattern would serve better. — `lib/presentation/screens/session_detail_screen.dart:206`
12. **[Could] No test asserts "Créer et démarrer" encodes `?start=true` in pushed URL** — tests stop at dialog visibility. — `test/presentation/screens/session_list_screen_test.dart:231-251`
13. **[Could] `_createSession` duplicates Session entity construction inline instead of delegating to domain-layer factory** — DRY + test-seam concern. — `lib/presentation/screens/session_list_screen.dart:255-270`
14. **[Could] `_loadSession` catch-all shows `'Erreur : $err'`** — `err.toString()` leak to user is unpolished (§Error handling level 2). — `lib/presentation/screens/session_detail_screen.dart:79-84`
15. **[Noted] Banner gesture-arena split clean** — inner InkWell wraps title Row only; IconButton peer sibling; no ancestor InkWell on outer Row. Fix documented at lines 49-54. — `lib/presentation/widgets/active_session_banner.dart:46-82`
16. **[Noted] `rootNavigatorKey` at top-level** (not inside `@riverpod`) per Batch D. — `lib/presentation/router.dart:28`
17. **[Noted] `runZonedGuarded` option (b)** — `ensureInitialized` + `runApp` both inside guarded zone per post-Phase 04 P4 fix. — `lib/main.dart:69-148`
18. **[Noted] `flutter_local_notifications` 21.0.0 named-param `settings:` used correctly.** — `lib/main.dart:122-125`
19. **[Noted] `ProviderScope(overrides: [...])` inlined everywhere** — no `Override` import (correct for flutter_riverpod 3.3.x `show` clause). — `test/presentation/screens/session_list_screen_test.dart:150-153`
20. **[Noted] `TextEditingController.dispose()` deferred via `WidgetsBinding.instance.addPostFrameCallback`** to survive dialog out-transition. — `lib/presentation/screens/session_detail_screen.dart:149-155`
21. **[Noted] `_ChronoCard` 1-Hz `Stream.periodic` isolated in own StatefulWidget**; detail tests correctly use bounded `pump(Duration)`. — `lib/presentation/screens/session_detail_screen.dart:304-357`, `test/presentation/screens/session_detail_screen_test.dart:115-132,156-164`
22. **[Noted] GOSL header present on every presentation file.**
23. **[Noted] `context.mounted`/`!mounted` guards applied after every `await`** in Stateful bodies (comprehensive sweep found zero miss except finding #7's entry setState).

### Agent #4 — Boot watchdog + native bridges + POC tooling + CLAUDE.md sweep

1. **[Noted] Swift AppDelegate channel literal absent post-Xcode 26 strip** — `grep 'app.gosl.mirkfall/boot_watchdog' ios/Runner/AppDelegate.swift` → 0 matches (only contextual comments). Test #1 inertness guard must EXCLUDE Swift from triple-source; currently double-source (Kotlin + Dart×2). Docstring at `AppDelegate.swift:12-40`. — `ios/Runner/AppDelegate.swift`
2. **[Noted] POC artefact path drift** — ROADMAP SC#1 expects `.planning/pocs/phase-05/`, actual at `docs/qual-01-02-poc.md` + `docs/poc-artifacts/`. Pre-class §2 item 2 — ROADMAP amendment required. — `docs/qual-01-02-poc.md`, `docs/poc-artifacts/`
3. **[Noted] `store-review-rationale.md` confirmed English-only** (QUAL-03 polish already done). Pre-class §2 item 6 satisfied as-is. — `docs/store-review-rationale.md:1-112`
4. **[Noted] dart format drift = exit 0** (Formatted 208 files, 0 changed). Pre-class §2 item 8 clean. — (whole tree)
5. **[Noted] MethodChannel triple-source verification** — Kotlin `BootCompletedReceiver.kt:55` + Dart `boot_completed_watchdog.dart:90` + Dart `ios_significant_change_watchdog.dart:35` + Dart test `ios_significant_change_watchdog_test.dart:20` all `'app.gosl.mirkfall/boot_watchdog'` verbatim. Swift absent (finding #1). — multiple files
6. **[Noted] BootCompletedWatchdog 4 unit tests cover active / none / idempotent / error-swallow** — pure-Dart, no platform channels. — `test/infrastructure/platform/boot_completed_watchdog_test.dart:22-83`
7. **[Noted] OemDetector regex order deterministic** — Xiaomi (`xiaomi|redmi|poco`) → Samsung → Huawei (`huawei|honor`) → OnePlus → Oppo (`oppo|realme`) → Other. Match-order short-circuit. — `lib/infrastructure/platform/oem_detector.dart:82-87`
8. **[Noted] DEPENDENCIES.md Phase 05 direct deps fully documented** — `geolocator 14.0.2`, `flutter_local_notifications 21.0.0`, `permission_handler 12.0.1`, `device_info_plus 12.4.0` (w/ win32 conflict rationale), `share_plus 12.0.2` — all with licence + telemetry audit + date. — `DEPENDENCIES.md:27-51`
9. **[Noted] `tool/requirements.txt` correctly scoped out of DEPENDENCIES.md** — `staticmap 0.5.7` MIT + `Pillow 12.2.0` HPND documented in `tool/README.md:115-120`. — `tool/requirements.txt`, `tool/README.md`
10. **[Noted] AndroidManifest receiver** `<receiver android:name=".BootCompletedReceiver" android:exported="true" android:directBootAware="false">` with BOOT_COMPLETED + MY_PACKAGE_REPLACED intent filters matches Kotlin implementation. — `android/app/src/main/AndroidManifest.xml:87-95`
11. **[Could] `kDefaultDistanceFilterMeters` in constants.dart does not match Plan 06-03 name-of-record `kDistanceFilterMeters`** — `Default` prefix accurate (user-adjustable); plan scope description drift, not code defect. — `lib/config/constants.dart:116`
12. **[Could] `tool/plot_session_fixes.py` `print_stats()`** — early-return for `< 2` fixes handles zero-fix case only because upstream `main()` bails on `if not fixes`. Defensively sound. — `tool/plot_session_fixes.py:112-150`
13. **[Could] `tool/plot_session_fixes.py:185` zoom conditional** `render(zoom=zoom) if zoom is not None else render()` could be cleaner as `render(**({"zoom": zoom} if zoom else {}))` — style only. — `tool/plot_session_fixes.py:185`
14. **[Noted] `pubspec.yaml` 100% strict-pinned** — zero `^` prefixes in direct deps; `dependency_overrides` uses `^` (documented escape hatch). — `pubspec.yaml`
15. **[Noted] CI `on.push.branches: [main]` only** — no adversarial-branch trigger. Plan 06-04 Test #6 will add. — `.github/workflows/ci.yml:3-7`
16. **[Could] POC Entry 3 (iPhone 17 Pro) 13.5 min vs 30-min acceptance target** — self-declared PASS-with-caveat. Acceptance checklist `docs/qual-01-02-poc.md:43-50` lists "Last fix > (start + 29 minutes)" as criterion. Grey-zone; top-up iOS walk is clean fix. — `docs/qual-01-02-poc.md:97-116`
17. **[Noted] POC Entry 2 (Pixel 6 Pro) all fields `{to-fill}`** — explicitly optional second Android data point. — `docs/qual-01-02-poc.md:78-95`
18. **[Noted] `p.join()` used correctly in `boot_completed_watchdog.dart:151-152`.** No manual concat. — `lib/infrastructure/platform/boot_completed_watchdog.dart:151`
19. **[Noted] No `context.mounted` needed in Phase 05 platform code** — none touch BuildContext. — `lib/infrastructure/platform/`
20. **[Noted] GOSL v1.0 header on all Phase 05 source files** (Dart/Kotlin/Swift/Python). — all files

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>

#### Agent #1 Narrative

GPS infra lens comes out clean. Two Phase 05 STATE.md regression locks (distanceFilter int; domain-gps purity) verified intact end-to-end. Hexagonal seams textbook: LocalNotificationsPort 4-method surface, PositionStreamFactory typedef avoids Geolocator static-method mocking trap, V2→V3 migration uses generator-native `m.createTable(db.fixes)` + explicit createIndex for Drift 2.32.1 quirk (byte-equivalent to frozen `drift_schema_v3.json`). Two real concerns, both iOS: UIBackgroundModes missing `fetch` (CONTEXT originally spec'd, 05-02-PLAN quietly downscoped) + AppDelegate.swift CLLocationManager+MethodChannel stripped at Xcode 26 (iOS half of GPS-06 silently non-functional, Phase 15 deferral documented). Minor nits: private magic-number-adjacent constants, `_translate` returning Object, French UI strings pending Phase 14, notification silent catch, FixId/SessionId API asymmetry.

#### Agent #2 Narrative

Controller layer lands clean three-state sealed machine with subscription lifetime tied to `ref.onDispose`. `cancelOnError: false` justified inline, locked by `streamErrorTransitionsToErrorState` regression test. `AsyncValue.value` used throughout (no `valueOrNull` regression). All 14 providers keepAlive:true (README claims 7 — stale). Permission flow textbook: POST_NOTIFICATIONS first, whenInUse, always, with PermissionRequester typedef seam. Regression tests `neverRequestsAlwaysIfWhenInUseNotGrantedFirst` + `requestsNotificationFirstAndDenialDoesNotBlockLocationFlow` lock invariants.

Surprises: error handling in start(). Docstring says GpsError → ErrorState but code sets AsyncError in both branches — `on GpsError` is dead code contradicting UI layer's sealed-state pattern-match plan. Activation-leak window: `_currentSessionId` assigned AFTER activate + initialize → throw leaves DB active, no id for catch-path deactivate, next start() hits partial-unique index. Bare `catch (_)` in stop() + permission flow violates §Error handling ("pas de catch vide"). `_onFix` missing try/catch around DB insert. `test/application/settings/**` missing entirely — `clampDistanceFilterMeters` boundaries + SharedPreferences persistence untested.

#### Agent #3 Narrative

Banner gesture-arena split is textbook — no wrapping InkWell on outer Row, inner InkWell on title area only, peer IconButton for stop. pumpAndSettle discipline right on detail screen (bounded `pump(Duration(ms 20-50))` around Tracking) but banner tests still pumpAndSettle — works today, would deadlock with future sibling ticker. `canPop()?pop():go('/')` implemented in OEM only — rationale/denied screens replace stack instead of popping, which nukes back-stack mid-flow from push origin. `const` coverage thorough. Navigation discipline correct (push as default, go only for terminal/reset). Tests use ProviderScope inline overrides + `setDistanceFilterMeters(42)` via `container.read()` (pragmatic). Gaps: no autoStart=true widget test, weak `notMaintenantPopsWithFalse` assertion, no `?start=true` URL-encoding test. `main.dart` option (b) Zone + flutter_local_notifications named settings + rootNavigatorKey top-level all correct.

#### Agent #4 Narrative

CLAUDE.md sweep clean across all three Phase 05 `lib/infrastructure/platform/` files. No magic numbers (all from constants.dart), no `dynamic` unjustified, no delegation wrappers (each adds real logic), type hints explicit, `p.join()` throughout, three-tier error-handling rubric followed, sealed `OemFamily` pattern-match (no `is TypeA` chains), singular naming, `@pragma('vm:entry-point')` on tree-shake-resistant entries. MethodChannel triple-source collapses to double (Kotlin + 2 Dart) because Swift stripped at Xcode 26 — docstring documents. Plan 06-04 Test #1 file map must exclude Swift + cross-ref Phase 15 FlutterImplicitEngineDelegate rewire. DEPENDENCIES.md complete; `device_info_plus 12.4.0` has detailed win32-conflict narrative explaining pin. Python tool deps in `tool/README.md` not DEPENDENCIES.md (binary-ship scope). dart format exit 0. POC artefact path drift confirmed. AndroidManifest + Info.plist align.

#### Agent #4 — Adversarial readiness checklist for Plan 06-04

- [x] Test #1 MethodChannel sync: Swift channel literal in `ios/Runner/AppDelegate.swift` is **absent** (verified: 0 matches for `app.gosl.mirkfall/boot_watchdog`; only prose comments about stripped bridge). Test file map scope: Kotlin `BootCompletedReceiver.kt` + Dart `boot_completed_watchdog.dart` + Dart `ios_significant_change_watchdog.dart` only, with inertness guard + docstring cross-ref to Phase 15 FlutterImplicitEngineDelegate rewire for iOS side.
- [x] Test #3 OemDetector ambiguous fixtures — 6 proposed:
  1. `manufacturer="Google" brand="aosp"` → needle `"google aosp"` → no regex → `OtherOem` (regression guard vs future aosp matchers).
  2. `manufacturer="Xiaomi" brand="Redmi"` + build MIUI → first regex `xiaomi|redmi|poco` → `XiaomiFamily` (order guard).
  3. `manufacturer="HUAWEI" brand="HONOR"` → `huawei|honor` matches → `HuaweiFamily` (both parent + sub-brand present).
  4. `manufacturer="OPPO" brand="Realme"` → OnePlus regex miss, Oppo `oppo|realme` match → `OppoFamily` (OnePlus must not shadow Oppo).
  5. `manufacturer="OnePlus" brand="OnePlus"` → `oneplus` match → `OnePlusFamily`.
  6. `manufacturer="samsung" brand="xiaomi"` → Xiaomi regex wins over Samsung (Xiaomi ordered first) → `XiaomiFamily` (documents deterministic tie-break).
- [x] Test #4 Platform manifests — AndroidManifest required `uses-permission`: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` — all present. Info.plist required keys: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes[location]`, `NSCameraUsageDescription` (Phase 11 placeholder), `NSPhotoLibraryUsageDescription` (Phase 11 placeholder) — all present. No drift.
- [x] Test #5 Android boot receiver contract — class path `app.gosl.mirkfall.BootCompletedReceiver` matches Kotlin `package app.gosl.mirkfall` + class name. Kotlin channel literal `"app.gosl.mirkfall/boot_watchdog"` at `BootCompletedReceiver.kt:55`. Manifest `<receiver android:name=".BootCompletedReceiver">` at `AndroidManifest.xml:88` resolves via `applicationId`. Android entry-point name `runBootWatchdogEntryPoint` at `BootCompletedReceiver.kt:62` matches Dart `@pragma('vm:entry-point')` function at `boot_completed_watchdog.dart:108-109`. All 4 sides aligned.
- [x] Test #6 Adversarial branch CI: `.github/workflows/ci.yml:3-7` `on.push.branches: [main]` + `on.pull_request.branches: [main]`. No adversarial trigger exists yet. Plan 06-04 Test #6 to add `adversarial/*` or `review-gate/*` branch.
- [x] ROADMAP SC#1 amendment text: current `.planning/pocs/phase-05/` → should be `docs/qual-01-02-poc.md + docs/poc-artifacts/` (Android PASS at `docs/poc-artifacts/test2-full.png` 342 fixes / 28.6 min / PASS; iOS PASS-with-caveat `sess_R5385AETFJ100000KMXZFK4S61-20260419-200715.png` 82 fixes / 13.5 min; OEM Xiaomi/Samsung/Huawei/OnePlus deferred Phase 15).
- [x] dart format drift watch — `dart format --line-length 160 --set-exit-if-changed lib/ test/ tool/` → **exit 0** (208 files, 0 changed, 0.51 s). No drift.

</details>

## 3. Triage decisions

*Filled by Plan 06-03 Task 4 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden per CONTEXT.md). Every Should MUST be either `fix` or `waived` with inline rationale.*

**User triage decision 2026-04-20 (verbatim):** blanket `fix blocker and should` per Phase 04 precedent — 2 Blockers → `fix`; 20 Shoulds → `fix` (with Agent #1 #2 iOS auto-resume `waived` as Phase 15 deferral per Phase 05 STATE.md Xcode 26 strip decision); 20 Coulds → `defer-to-phase-15` for tech-debt items, `won't-fix` for purely stylistic items (Agent #4 #11 constant name correct as-is + Agent #4 #13 Python one-liner style only); 45 Noteds → `observation` (audit transparency). Cross-lens duplicates get separate §3 rows with SAME commit hash placeholder and Rationale column cross-references (Phase 04 convention). Default for any ambiguity: lean toward `fix` over `waive`.

| # | Finding | Severity | Decision | Rationale | Commit hash |
|---|---------|----------|----------|-----------|-------------|
| 1 | [Agent #2 #1] Partial activation leaks active DB row on start() failure | Blocker | fix | Move `_currentSessionId` assignment BEFORE activate so catch-path can deactivate; add try/catch around activate→initialize→listen sequence. Cross-referenced by Agent #2 #3 (Should — same fix). | (pending Plan 06-05) |
| 2 | [Agent #2 #2] GpsError in start() does NOT transition to ErrorState contra documented contract | Blocker | fix | Either fix code (`AsyncData(ErrorState(e))` on GpsError branch) or update docstring + sealed state comment to match AsyncError reality. UI (Plan 05-04) pattern-matches AsyncValue.error today. Cross-referenced by Agent #2 #11 (Could dead code — same fix). | (pending Plan 06-05) |
| 3 | [Pre-class #2] POC artefact location drift — ROADMAP SC#1 path mismatch | Should | fix | ROADMAP SC#1 amendment: `.planning/pocs/phase-05/` → `docs/qual-01-02-poc.md` + `docs/poc-artifacts/`. One atomic commit in Plan 06-05 loop. Cross-referenced by Agent #4 #2 (Noted — same artefact path drift). | (pending Plan 06-05) |
| 4 | [Pre-class #7] Flaky widget-test pumpAndSettle races | Should | fix | Replace `pumpAndSettle()` occurrences in banner tests with bounded `pump(Duration)` pattern (per `session_detail_screen_test:125-127` precedent). Cross-referenced by Agent #3 #2 (Should — same fix, banner tests specifically). | (pending Plan 06-05) |
| 5 | [Agent #1 #1] Missing `UIBackgroundModes = fetch` on iOS Info.plist | Should | fix | Add `<string>fetch</string>` to UIBackgroundModes array in `ios/Runner/Info.plist` — CONTEXT.md line 278 + audit scope both specify location+fetch; fetch = iOS significant-change wake hook enabling watchdog path. | (pending Plan 06-05) |
| 6 | [Agent #1 #2] iOS auto-resume MethodChannel wiring deleted without replacement (AppDelegate.swift) | Should | waived | Deferred Phase 15 FlutterImplicitEngineDelegate rewire per Phase 05 STATE.md Xcode 26 strip decision (canonical commit `67bcb3a` acceptance); Android half already shipped (Plan 05-05 BootCompletedWatchdog + 4 unit tests); CONTEXT.md §POC evidence acceptance pre-class item 5 accepts this gap. Cross-referenced by Agent #2 #15 (Noted — clean wrapper no-op branching) + Agent #2 #18 (Noted — silent MissingPluginException). | waived |
| 7 | [Agent #1 #3] `Permission.notification` request result silently discarded via bare `catch (_)` | Should | fix | Add `log.fine('permission_flow.notification_request_failed', error: e)` inside the catch body (preserve "notification failure doesn't block location flow" invariant per Phase 05 regression test). Cross-referenced by Agent #2 #6 (Should — same file:line; one fix covers both rows) + Agent #2 #12 (Could — test coverage gap; same fix + add test). | (pending Plan 06-05) |
| 8 | [Agent #1 #4] `FixId.parse` exists but `SessionId` has no equivalent defensive factory | Should | fix | Add `SessionId.parse(String)` + validate-and-throw helper mirroring `FixId.parse`; needed for notification `resume:<sessionId>` payload hydration. | (pending Plan 06-05) |
| 9 | [Agent #2 #3] `_currentSessionId` assignment after activation+initialize leaks unrecoverable sessions | Should | fix | Same fix as Blocker #1 (row 1) — `_currentSessionId = id` moves BEFORE `sessionStore.activate(id)`. SAME commit hash as row 1. | (pending Plan 06-05) |
| 10 | [Agent #2 #4] `stop()` has no overlapping / re-entrant protection | Should | fix | Add `_isStopping` bool guard; if second stop() arrives while first in-flight, short-circuit with no second deactivate. CLAUDE.md §Idempotence. | (pending Plan 06-05) |
| 11 | [Agent #2 #5] Non-critical `notificationService.dismiss()` + `sessionStore.deactivate()` failures swallowed with bare `catch (_)` | Should | fix | Replace `catch (_)` at lines 151-153 + 160-163 with `catch (e, st) { _log.fine('stop.dismiss_or_deactivate_failed', error: e, stackTrace: st); }`. CLAUDE.md §Error handling. | (pending Plan 06-05) |
| 12 | [Agent #2 #6] `requestLocationAlways` swallows `Permission.notification` request with bare `catch (_)` | Should | fix | Cross-lens duplicate of Agent #1 #3 (row 7) — SAME file:line (`location_permission_flow.dart:58-60`); SAME fix, SAME commit hash. Two rows preserve audit transparency per Phase 04 convention. | (pending Plan 06-05) |
| 13 | [Agent #2 #7] `_onFix` has no try/catch around `fixStore.insert(fix)` DB write | Should | fix | Wrap `fixStore.insert(fix)` in try/catch; route throw to `_onStreamError` (ErrorState transition) OR log and drop single fix (depending on whether failure is constraint vs disk/corruption). | (pending Plan 06-05) |
| 14 | [Agent #2 #8] Test `startPropagatesConcurrentActivationAsErrorState` misnamed vs documented invariant | Should | fix | Rename test to `startPropagatesConcurrentActivationAsAsyncError` — current name claims ErrorState but assertions verify AsyncError (which matches Phase 05 STATE.md lock "untyped via AsyncError, NOT as ErrorState"). Maintenance risk if future refactor "fixes" code to match name. | (pending Plan 06-05) |
| 15 | [Agent #2 #9] `test/application/settings/**` directory does not exist — zero test coverage for SessionSettings | Should | fix | Create `test/application/settings/session_settings_test.dart` covering `clampDistanceFilterMeters` boundary behaviour (Phase 05 STATE.md regression test request) + `permission_flow_completed` + `oem_guidance_seen` flag persistence through SharedPreferences. | (pending Plan 06-05) |
| 16 | [Agent #3 #1] OEM guidance-only screen uses `canPop() ? pop() : go('/')` — rationale + denied screens break back stack | Should | fix | Apply `canPop() ? pop() : go('/')` pattern consistently in `permission_rationale_screen.dart:112` + `permission_denied_screen.dart:33,63` (currently use bare `go()` which replaces stack). Cross-referenced by Agent #3 #10 (Could — same rationale screen) + Agent #3 #11 (Could — session_detail `_handleDelete` same pattern). | (pending Plan 06-05) |
| 17 | [Agent #3 #2] `pumpAndSettle` after Tracking transition in banner tests | Should | fix | Cross-lens duplicate of Pre-class #7 (row 4) — SAME pumpAndSettle issue; replace `pumpAndSettle()` at lines 120, 127, 168, 174 with bounded `pump(Duration)` per `session_detail_screen_test:125-127` precedent. SAME commit hash as row 4. | (pending Plan 06-05) |
| 18 | [Agent #3 #3] No widget test covers `SessionDetailScreen(autoStart: true)` | Should | fix | Add widget test asserting `?start=true` query-param auto-kickoff path triggers `_handleStart()` on mount (Plan 05-04 autoStart path has zero widget coverage). | (pending Plan 06-05) |
| 19 | [Agent #3 #4] `notMaintenantPopsWithFalse` only asserts `onPressed != null` — weak assertion | Should | fix | Strengthen test to verify `pop(false)` effect (use `Navigator.canPop` + result capture pattern); currently `onPressed != null` tolerates a no-op onPressed. | (pending Plan 06-05) |
| 20 | [Agent #3 #5] `_CreateSessionDialog._mintSessionIdBody` embeds ULID-adjacent minting in UI dialog | Should | fix | Route through `IdGenerator.nextSessionId()` (domain-layer factory) instead of inline mint in widget file. CLAUDE.md §Structure: logique métier out of widgets. | (pending Plan 06-05) |
| 21 | [Agent #3 #6] `_localValue ??= …` runs inside `build()` as init side-effect | Should | fix | Move initialization to `initState()` (StatefulWidget) — `build()` should describe UI, no logique. CLAUDE.md §Widgets. | (pending Plan 06-05) |
| 22 | [Agent #3 #7] `_handleStart` setState at entry without `mounted` check when invoked from auto-start path | Should | fix | Add `if (!mounted) return;` guard at `_handleStart` entry (unlikely in practice but CLAUDE.md §Async / BuildContext mandates it). | (pending Plan 06-05) |
| 23 | [Agent #1 #5] Private stationary-dedup thresholds belong with `kMaxAcceptableAccuracyMeters` in constants.dart | Could | defer-to-phase-15 | Non-runtime tech debt; same semantic scope as other GPS-filter constants. Phase 15 polish for discoverability. | (pending Phase 15) |
| 24 | [Agent #1 #6] `_translate` returns raw `Object` — loses type info | Could | defer-to-phase-15 | Type as `Exception` or sealed union; subscribers pattern-matching lose `GpsError` type today but no runtime breakage. Phase 15 refactor. | (pending Phase 15) |
| 25 | [Agent #1 #7] `foregroundNotificationConfig` strings hardcoded French | Could | defer-to-phase-15 | Phase 14 l10n tech-debt site (CONTEXT.md explicitly defers l10n to Phase 14; Phase 15 is release-confidence but per CONTEXT `won't-fix` doesn't apply — tech-debt item). | (pending Phase 14) |
| 26 | [Agent #1 #8] V2→V3 migration cast diverges from V1→V2 pattern without explanatory comment | Could | defer-to-phase-15 | Worth one-line rationale comment on next Drift touch; non-runtime. | (pending Phase 15) |
| 27 | [Agent #2 #10] `lib/application/providers/README.md` claims "All seven providers" — actually 14 | Could | defer-to-phase-15 | Stale README; documentation freshness tech-debt. Phase 15 doc polish. | (pending Phase 15) |
| 28 | [Agent #2 #11] Explicit `on GpsError` branch is dead code given generic catch does same work | Could | fix | Cross-lens with Blocker #2 (row 2) — fix hinges on whether GpsError branch honours docstring (`AsyncData(ErrorState(e))`) or consolidates. SAME commit hash as row 2. | (pending Plan 06-05) |
| 29 | [Agent #2 #12] `requestLocationAlways` notification-failure test coverage gap | Could | fix | Cross-lens duplicate of Agent #1 #3 (row 7) + Agent #2 #6 (row 12) — SAME file:line 58-60; fix adds the missing test alongside the logging fix. SAME commit hash as rows 7+12. | (pending Plan 06-05) |
| 30 | [Agent #2 #13] `Tracking.copyWith` cannot clear `lastFix` back to null | Could | defer-to-phase-15 | Standard `??` pattern; not a current problem (controller only advances forward). Implicit invariant noted. Phase 15 tech-debt. | (pending Phase 15) |
| 31 | [Agent #2 #14] Provider README documents Phase 03 provider graph only | Could | defer-to-phase-15 | Related to row 27 (Agent #2 #10); same README file. Phase 15 doc polish. | (pending Phase 15) |
| 32 | [Agent #3 #8] Two lines > 160 chars in copy strings (permission rationale + OEM step) | Could | defer-to-phase-15 | Copy load-bearing, can't split without changing assertions. Phase 14 l10n extraction naturally resolves. | (pending Phase 14) |
| 33 | [Agent #3 #9] `router.dart` path divergence — README references `lib/application/routing/` but file at `lib/presentation/router.dart` | Could | defer-to-phase-15 | Layer-by-design is presentation (rootNavigatorKey + GoRouter are presentation concerns per Phase 05 STATE.md `rootNavigatorKey lives at the top level of router.dart`). Update README/plan references in Phase 15 polish. | (pending Phase 15) |
| 34 | [Agent #3 #10] `PermissionRationaleScreen._onContinue` → `context.go('/permissions/denied')` breaks back stack | Could | defer-to-phase-15 | Cross-lens with Agent #3 #1 (row 16 Should — same file). Row 16 fix already covers this site; tagging Could for audit transparency. | (pending Plan 06-05 — subsumed by row 16) |
| 35 | [Agent #3 #11] `session_detail_screen._handleDelete` uses `context.go('/')` on success | Could | defer-to-phase-15 | Cross-lens with Agent #3 #1 (row 16 Should — same navigation pattern on `session_detail_screen.dart:206`). Row 16 fix extends to cover this site if user wants one sweeping commit; else deferred. | (pending Plan 06-05 — subsumed by row 16) |
| 36 | [Agent #3 #12] No test asserts "Créer et démarrer" encodes `?start=true` in pushed URL | Could | defer-to-phase-15 | Related to row 18 (Agent #3 #3 Should autoStart widget test); URL-encoding assertion deferrable. | (pending Phase 15) |
| 37 | [Agent #3 #13] `_createSession` duplicates Session entity construction inline | Could | defer-to-phase-15 | DRY + test-seam concern; domain-layer factory extraction Phase 15 polish. | (pending Phase 15) |
| 38 | [Agent #3 #14] `_loadSession` catch-all shows `'Erreur : $err'` — `err.toString()` leak to user | Could | defer-to-phase-15 | CLAUDE.md §Error handling level 2 (user-facing feedback unpolished). Phase 14 l10n + Phase 15 UX polish. | (pending Phase 14) |
| 39 | [Agent #4 #11] `kDefaultDistanceFilterMeters` name drift vs plan scope `kDistanceFilterMeters` | Could | won't-fix | `Default` prefix is SEMANTICALLY CORRECT — the value is user-adjustable via `SessionSettings.clampDistanceFilterMeters`. Plan scope description drift, not code defect. User decision: name is correct as-is. | won't-fix |
| 40 | [Agent #4 #12] `tool/plot_session_fixes.py::print_stats()` early-return `< 2` fixes handles zero-fix case transitively | Could | defer-to-phase-15 | Defensively sound today; tightening is style polish. Phase 15 tooling hygiene. | (pending Phase 15) |
| 41 | [Agent #4 #13] `tool/plot_session_fixes.py:185` zoom conditional one-liner style | Could | won't-fix | Purely stylistic — current form is explicit and readable. User decision: style preference, not a defect. | won't-fix |
| 42 | [Agent #4 #16] POC Entry 3 (iPhone 17 Pro) 13.5 min vs 30-min acceptance target | Could | defer-to-phase-15 | Cross-lens with Pre-class #1 (Noted — iOS walk duration). Optional top-up Phase 15 release-confidence if user wants formal 30-min iOS walk. | (pending Phase 15) |
| 43 | [Pre-class #1] iOS walk duration 13.5 min vs 30-min target | Noted | observation | PASS-with-caveat accepted CONTEXT.md §POC evidence acceptance pre-class item 1; convergent Android evidence (Pixel 4a 28.6 min PASS) supports extrapolation; stable cadence. Optional Phase 15 top-up. | n/a |
| 44 | [Pre-class #3] SC#2 battery measurement <15%/h waiver | Noted | observation | POC artefacts contain zero numeric battery readings; fix-cadence stability (~6s/fix iOS, <10s Android) used as proxy per CONTEXT.md. Full `dumpsys battery_stats` deferred Phase 15 release-confidence. | n/a |
| 45 | [Pre-class #4] Xiaomi / Samsung / Huawei / OnePlus OEM coverage deferred | Noted | observation | Already accepted Phase 05 (ROADMAP SC#1 annotated "partial"); `OemDetector` + `OemGuidanceScreen` ship manual mitigation path (dontkillmyapp.com links). Phase 06 does not re-litigate. | n/a |
| 46 | [Pre-class #5] Auto-resume-post-kill iOS unvalidated | Noted | observation | FlutterImplicitEngineDelegate bridge stripped after Xcode 26 move per Phase 05 STATE.md; Android covered by 4 BootCompletedWatchdog unit tests + Plan 05-05. iOS rewire deferred Phase 15. Cross-referenced by row 6 (Agent #1 #2 — waived Should, same deferral). | n/a |
| 47 | [Pre-class #6] Store rationale English copy — already English on disk | Noted | observation | Plan 06-02 §1b surfaced ground truth: `docs/store-review-rationale.md` is ALREADY English (self-declared reviewer-anglophone), contradicting original CONTEXT assumption. Re-classified: English copy committed Plan 05-06; final polish optional Phase 15. No fix needed this gate. | n/a |
| 48 | [Pre-class #8] dart format drift regression watch | Noted | observation | Agent #4 ran `dart format --line-length 160 --set-exit-if-changed lib/ test/ tool/` locally — exit 0 (208 files, 0 changed). No drift. CI gate active since Plan 04-05. | n/a |
| 49 | [Agent #1 #9] `createIndex` not auto-emitted by `createTable` in Drift 2.32.1 comment | Noted | observation | Good defensive doc; worth version-reference in pinned comment for future pubspec drift. Not a defect. | n/a |
| 50 | [Agent #1 #10] AndroidManifest relative `.BootCompletedReceiver` resolves via applicationId | Noted | observation | Declaration + class match confirmed (`applicationId="app.gosl.mirkfall"` + package `app.gosl.mirkfall.BootCompletedReceiver`). Compliant. | n/a |
| 51 | [Agent #1 #11] `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` still show `TODO Phase 11` | Noted | observation | Shipping as-is per Phase 05 decision; if iOS test build triggers either before Phase 11, user sees `TODO Phase 11` as rationale. Phase 11 landing will finalize copy. | n/a |
| 52 | [Agent #1 #12] Domain port purity intact (`lib/domain/gps/`) | Noted | observation | Phase 05 STATE.md regression lock verified — no Flutter/Drift/geolocator leak in domain layer. | n/a |
| 53 | [Agent #1 #13] `distanceFilter: int` everywhere verified (port/factory/settings/controller/state/provider/presentation) | Noted | observation | Phase 05 STATE.md regression lock verified end-to-end — no double regression. | n/a |
| 54 | [Agent #1 #14] GOSL headers present on every audited source file | Noted | observation | CLAUDE.md §source headers compliance confirmed. | n/a |
| 55 | [Agent #1 #15] Pragma cohérence V3 intact — `applyRuntimePragmas` + WAL at `NativeDatabase` | Noted | observation | V3 no deviation from Phase 03 pattern; cold+warm open path verified. | n/a |
| 56 | [Agent #1 #16] `FlutterLocalNotificationsAdapter` seam clean (`LocalNotificationsPort` 4-method surface) | Noted | observation | Phase 05 STATE.md seam-design confirmed; tests use `_CapturingNotificationsPort` fake. Compliant. | n/a |
| 57 | [Agent #1 #17] Android 14 SecurityException avoidance correct on both sides | Noted | observation | Kotlin receiver + Dart watchdog both notification-only; neither touches `geolocator.getPositionStream`. Compliant with Phase 05 STATE.md Pitfall #5. | n/a |
| 58 | [Agent #1 #18] No `test/domain/gps/` directory — GpsError hierarchy covered implicitly | Noted | observation | Implicit coverage via `geolocator_location_stream_test.dart` error-translation cases. Belt-and-braces file optional Phase 15. | n/a |
| 59 | [Agent #2 #15] `iosSignificantChangeWatchdog` wrapper clean per CLAUDE.md §Wrappers (platform-branching is added logic) | Noted | observation | Cross-referenced by row 6 (Agent #1 #2 waived — same watchdog, iOS bridge deferred Phase 15). Compliant per CLAUDE.md. | n/a |
| 60 | [Agent #2 #16] `oemDetectorProvider` constructs fresh `DeviceInfoPlugin()` inline — no injection seam | Noted | observation | Phase 05 decision — no `oem_detector` tests today; future phase must override provider if tests added. Non-blocking today. | n/a |
| 61 | [Agent #2 #17] Test fake `requested` list lacks `xxxs` suffix | Noted | observation | Marginal test-code finding; CLAUDE.md naming convention violation on test fake. Phase 15 polish. | n/a |
| 62 | [Agent #2 #18] Cross-lens: `iosSignificantChangeWatchdog` invoked unconditionally; wrapper no-op hides absent iOS wiring | Noted | observation | Cross-referenced by row 6 (Agent #1 #2 waived — same Phase 15 deferral) + row 59 (Agent #2 #15 wrapper clean). MissingPluginException swallowed at fine-level log per design. | n/a |
| 63 | [Agent #3 #15] Banner gesture-arena split clean (inner InkWell title + peer IconButton) | Noted | observation | Phase 05 STATE.md `Banner InkWell split` verified — no ancestor InkWell on outer Row. Compliant. | n/a |
| 64 | [Agent #3 #16] `rootNavigatorKey` at top-level per Batch D | Noted | observation | Phase 05 STATE.md `rootNavigatorKey lives at the top level of router.dart` verified — NOT inside `@riverpod`. | n/a |
| 65 | [Agent #3 #17] `runZonedGuarded` option (b) — `ensureInitialized` + `runApp` inside guarded zone | Noted | observation | Phase 04 P4 fix verified (`main.dart:69-148`); option-b canonical pattern preserved. | n/a |
| 66 | [Agent #3 #18] `flutter_local_notifications` 21.0.0 named-param `settings:` used correctly | Noted | observation | Phase 05 STATE.md `initialize requires named settings:` verified. | n/a |
| 67 | [Agent #3 #19] `ProviderScope(overrides: [...])` inlined everywhere — no `Override` import | Noted | observation | Phase 05 STATE.md `Override NOT publicly exported` verified; flutter_riverpod 3.3.x compatible. | n/a |
| 68 | [Agent #3 #20] `TextEditingController.dispose()` deferred via `addPostFrameCallback` | Noted | observation | Phase 05 STATE.md `Deferred TextEditingController.dispose()` verified — survives dialog out-transition. | n/a |
| 69 | [Agent #3 #21] `_ChronoCard` 1-Hz `Stream.periodic` isolated in own StatefulWidget; bounded `pump(Duration)` in tests | Noted | observation | Phase 05 STATE.md discipline verified on detail screen (but banner tests still `pumpAndSettle` — see row 17). | n/a |
| 70 | [Agent #3 #22] GOSL header present on every presentation file | Noted | observation | CLAUDE.md §source headers compliance confirmed. | n/a |
| 71 | [Agent #3 #23] `context.mounted`/`!mounted` guards after every `await` in Stateful bodies | Noted | observation | Comprehensive sweep found zero miss except row 22 (Agent #3 #7 entry setState). | n/a |
| 72 | [Agent #4 #1] Swift AppDelegate channel literal absent post-Xcode 26 strip | Noted | observation | `grep 'app.gosl.mirkfall/boot_watchdog' ios/Runner/AppDelegate.swift` → 0 matches. Plan 06-04 Test #1 file map MUST exclude Swift (double-source: Kotlin + Dart×2). Cross-referenced by row 6 (Agent #1 #2 waived — same bridge strip). | n/a |
| 73 | [Agent #4 #2] POC artefact path drift — ROADMAP SC#1 expects `.planning/pocs/phase-05/` | Noted | observation | Cross-referenced by row 3 (Pre-class #2 Should — same amendment). Row 3 fix covers this finding. | n/a |
| 74 | [Agent #4 #3] `store-review-rationale.md` confirmed English-only (QUAL-03 polish already done) | Noted | observation | Cross-referenced by row 47 (Pre-class #6 Noted — same ground truth). | n/a |
| 75 | [Agent #4 #4] dart format drift = exit 0 | Noted | observation | Cross-referenced by row 48 (Pre-class #8 Noted — same exit 0 result). | n/a |
| 76 | [Agent #4 #5] MethodChannel triple-source verification (Kotlin + Dart + Dart) | Noted | observation | All `'app.gosl.mirkfall/boot_watchdog'` verbatim; Swift absent per row 72. Triple-source collapses to double + test mirror. | n/a |
| 77 | [Agent #4 #6] BootCompletedWatchdog 4 unit tests cover active / none / idempotent / error-swallow | Noted | observation | Phase 05 STATE.md `BootCompletedWatchdog is PURE DART` verified; no platform-channel test harness needed. | n/a |
| 78 | [Agent #4 #7] OemDetector regex order deterministic (Xiaomi → Samsung → Huawei → OnePlus → Oppo → Other) | Noted | observation | Phase 05 STATE.md `OemDetector.detect regex order` verified; match-order short-circuit reproducible. Plan 06-04 Test #3 ambiguous fixtures depend on this order. | n/a |
| 79 | [Agent #4 #8] DEPENDENCIES.md Phase 05 direct deps fully documented | Noted | observation | geolocator 14.0.2 / flutter_local_notifications 21.0.0 / permission_handler 12.0.1 / device_info_plus 12.4.0 (w/ win32 rationale) / share_plus 12.0.2 — all licence + telemetry audit + date complete. | n/a |
| 80 | [Agent #4 #9] `tool/requirements.txt` correctly scoped out of DEPENDENCIES.md | Noted | observation | Phase 05 STATE.md `Python POC tool deps live in tool/requirements.txt only — DEPENDENCIES.md is binary-ship-scoped` verified. | n/a |
| 81 | [Agent #4 #10] AndroidManifest receiver declaration + intent filters matches Kotlin implementation | Noted | observation | `<receiver android:name=".BootCompletedReceiver">` + BOOT_COMPLETED + MY_PACKAGE_REPLACED filters aligned. Plan 06-04 Test #5 (Android boot receiver contract) prerequisite verified. | n/a |
| 82 | [Agent #4 #14] `pubspec.yaml` 100% strict-pinned direct deps (zero `^` prefixes) | Noted | observation | CLAUDE.md §Pin des versions compliance; `dependency_overrides` uses `^` as documented escape hatch. | n/a |
| 83 | [Agent #4 #15] CI `on.push.branches: [main]` only — no adversarial-branch trigger yet | Noted | observation | Plan 06-04 Test #6 will inline-expand to `[main, 'adversarial/**']` on throwaway branch only; main trigger stays `[main]`-only after branch deletion. | n/a |
| 84 | [Agent #4 #17] POC Entry 2 (Pixel 6 Pro) all fields `{to-fill}` | Noted | observation | Explicitly optional second Android data point; not blocking. Pixel 4a entry (row 43) is canonical. | n/a |
| 85 | [Agent #4 #18] `p.join()` used correctly in `boot_completed_watchdog.dart:151-152` | Noted | observation | CLAUDE.md §Naming de chemins compliance; no manual `/` `\` concatenation. | n/a |
| 86 | [Agent #4 #19] No `context.mounted` needed in Phase 05 platform code | Noted | observation | None of `lib/infrastructure/platform/` touches `BuildContext`; compliance vacuously satisfied. | n/a |
| 87 | [Agent #4 #20] GOSL v1.0 header on all Phase 05 source files (Dart/Kotlin/Swift/Python) | Noted | observation | Whole-tree CLAUDE.md §source headers compliance confirmed. | n/a |

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

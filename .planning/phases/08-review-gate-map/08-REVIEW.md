# Phase 08: Review Gate — Map Review

**Opened:** 2026-04-23
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude reads any POC artefact and BEFORE Claude spawns any audit sub-agent.*

*Aucune observation utilisateur — l'user n'a pas identifié de point à revoir dans son IDE.*

(User response 2026-04-23: "rien vu". Phase 04 + Phase 06 precedent applied : explicit no-findings marker committed before §1b / §2 / §3 / §4 / §5 unblock.)

### 1b. POC evidence review

*Filled by Plan 08-02 after extracting `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots at `docs/phase-07-smoke-screenshots/`. Replaces the "Runtime walk" sub-heading from Phase 04 §1b — user decision 2026-04-23 (CONTEXT §POC / runtime evidence review §1b — no fresh walk): smoke 2026-04-21 + fix iOS 2026-04-22 convergent, re-smoke rejected.*

<details>
<summary>Android Pixel 4a — PASS 2026-04-21</summary>

**Device:** Pixel 4a
**OS version:** Android 13 (4.14.302)
**MirkFall build:** `fbcbde6a2569baad84b3104eceed51b437e38ed4`
**APK source:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24834805699/artifacts/6601556400
**Date of walk (UTC):** 20260423 14h40
**Walk duration:** 2 minutes
**Status:** PASS
**Source:** `docs/phase-07-smoke.md` — Entry 1 (Android)

**Screenshots (inline):**

![Android — /map screen with world bundle + attribution + follow-me + burger menu open](../../../docs/phase-07-smoke-screenshots/android-01-map-screen.png)
![Android — airplane-mode launch still renders map](../../../docs/phase-07-smoke-screenshots/android-02-airplane-mode.png)
![Android — Aruba download in progress](../../../docs/phase-07-smoke-screenshots/android-03-download-progress.png)
![Android — Aruba in Manage screen](../../../docs/phase-07-smoke-screenshots/android-04-manage-installed.png)
![Android — post-delete Manage screen](../../../docs/phase-07-smoke-screenshots/android-05-post-delete.png)

**Cadence / observations table (extracted verbatim from `docs/phase-07-smoke.md` Entry 1 Step-by-step results):**

| #   | Step                                                | Result | Notes |
| --- | --------------------------------------------------- | ------ | ----- |
| 1   | Install + first launch                              | _PASS_ |       |
| 2   | "Préparation de la carte…" then SessionListScreen   | _PASS_ |       |
| 3   | Create + start session                              | _PASS_ |       |
| 4   | MapScreen: map renders + AppBar affordances visible | _PASS_ |       |
| 5   | Burger menu: 3 tiles + 3 live-data rows             | _PASS_ |       |
| 6   | Airplane mode cold-start: map still renders         | _PASS_ |       |
| 7   | Aruba download completes                            | _PASS_ |       |
| 8   | Aruba in Manage screen with correct size + version  | _PASS_ |       |
| 9   | Delete Aruba → disappears + world row stays         | _PASS_ |       |

**Airplane-mode evidence (Step 6 + Protocol §6 verbatim from `docs/phase-07-smoke.md`):**

> **Enable airplane mode on the device (OS-level).** Relaunch app from cold. Verify the map STILL RENDERS from the bundled world.pmtiles, session UX still works (MAP-01 code-path already verified by `test/phase_07_integration/airplane_mode_test.dart`; this step validates the code-path holds under real native MapLibre rendering).

Step 6 result: **PASS** — airplane-mode cold-start renders the bundled world, no tile HTTP requested.

**Verdict (verbatim):** **PASS**

</details>

<details>
<summary>iOS iPhone 17 Pro — PASS post-fix 2026-04-22</summary>

**Device:** iPhone 17 Pro
**iOS version:** 26.3.1 (build 23D771330a)
**MirkFall build:** `fbcbde6a2569baad84b3104eceed51b437e38ed4`
**Sideload method:** iLoader (SideStore)
**IPA source:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24834805699/artifacts/6601494748
**Date of walk (UTC):** 20260423 15h00 (final smoke, post-fix)
**Original crash investigation dates:** 2026-04-22 (commits landed 22:00 UTC — RÉSOLU)
**Walk duration:** 2 minutes
**Status:** PASS post-fix (with Xcode-container-inspection caveat on Step 10 — see below)
**Sources:** `docs/phase-07-smoke.md` — Entry 2 (iOS) + `docs/phase-07-ios-animate-camera-crash.md` (fix investigation)

**Screenshots (inline):**

![iOS — /map screen + attribution + burger menu](../../../docs/phase-07-smoke-screenshots/ios-01-map-screen.png)
![iOS — Aruba download completion](../../../docs/phase-07-smoke-screenshots/ios-02-download-complete.png)

**Fix commits (verbatim subjects via `git log --format="%h %s"`):**

- `81d30c7` — `fix(07): supply initialCamera via MapLibreMap prop, drop camera move from openForSession` — Tentative 2 : OK sur le SIGABRT (plus aucun method-channel touchant la caméra post-style-load)
- `ab497ab` — `fix(07): GeoJSON puck + initialCountry seed (puck survives setStyle, no transient world)` — Tentative 3 : puck GeoJSON OK, seed partial (keepAlive ne survit pas au kill iOS)
- `40b49d5` — `fix(07): stateless resolveForPoint seed for initialCountry (survive iOS kill)` — Tentative 4 : VALIDÉ device-smoke 2026-04-22 21:56-22:00 (zéro SIGABRT + zéro `sourceNotFound` + zéro transient world + zéro thrashing)

**Stack .ips extract (verbatim from `docs/phase-07-ios-animate-camera-crash.md` §Stack .ips, identique entre tous les crashs pré-fix):**

```
 0  libsystem_kernel.dylib    __pthread_kill
 1  libsystem_pthread.dylib   pthread_kill
 2  libsystem_c.dylib         abort
 3  libc++abi.dylib           __abort_message
 4  libc++abi.dylib           demangling_terminate_handler()
 5  libobjc.A.dylib           _objc_terminate()
 6  libc++abi.dylib           std::__terminate(void (*)())
 7  libc++abi.dylib           __cxxabiv1::failed_throw(...)
 8  libc++abi.dylib           __cxa_throw
 9  MapLibre                  off=104588    (unsymbolicated)
10  MapLibre                  off=1835160   (unsymbolicated)
11  MapLibre                  off=1810356   (unsymbolicated)
12  MapLibre                  off=1792800   (unsymbolicated)
13  MapLibre                  off=725176    (unsymbolicated)
14  maplibre_gl               MapLibreMapController.onMethodCall +18872
15  maplibre_gl               closure in init(withFrame:...)
16+ Flutter / libdispatch / UIKit / CoreFoundation …
```

Signal : `EXC_CRASH / SIGABRT`. Exception : C++ (`__cxa_throw`) non-catchée → `std::terminate` → `abort`.

**Bisection probes table (verbatim from `docs/phase-07-ios-animate-camera-crash.md` §TL;DR — 3 method-channel calls post-`onStyleLoadedCallback`):**

| Probe | Call unique laissé actif          | Résultat  |
|-------|-----------------------------------|-----------|
| 1     | `setUserLocation` → `addCircle`   | No crash  |
| 2     | `moveCameraTo` → `animateCamera`  | **Crash** |
| 3     | `setFollowMeEnabled`              | Non testé |

**4-tentatives fix bisection (extracted from `docs/phase-07-ios-animate-camera-crash.md` §Ce qu'on a shipé):**

| Tentative | Change | Result |
|-----------|--------|--------|
| 1 — `jumpCameraTo` (commit `3b23c8d`) | Port method `MapView.jumpCameraTo` routant vers le plugin `moveCamera` (no animator) | **KO** — nouvelle .ips révèle offsets `MapLibre.framework` rigoureusement identiques → ce n'est PAS `animateCamera` le coupable, c'est N'IMPORTE QUEL camera-op dans la fenêtre post-style-load |
| 2 — `initialCameraPosition` widget + pas de camera move dans `openForSession` (commit `81d30c7`) | Supplier la position initiale via `MapLibreMap.initialCameraPosition` au build, aucun method-channel camera-op post-style-load | **OK sur le SIGABRT** — carte s'ouvre, pas de crash, follow-me actif ; mais bugs résiduels `PlatformException(sourceNotFound)` + `showMap(fra) × 3` + transient world-zoom-13 |
| 3 — GeoJSON puck + `initialCountry` seed (commit `ab497ab`) | Puck GeoJSON géré côté app (bypass AnnotationManager) + seed `initialCountry` via `activeCountry` keepAlive | **partial** — plus de `sourceNotFound`, mais seed KO en scénario froid (iOS 26 kill l'app au minimize, keepAlive Riverpod ne survit pas → transient world 5-10s) |
| 4 — Stateless point-in-polygon lookup (commit `40b49d5`) | `CountryResolverController.resolveForPoint(lat, lon, zoom)` stateless via polygones assets rechargés à chaque app-start | **VALIDÉ** — device-smoke 2026-04-22 21:56-22:00 : zéro SIGABRT, zéro `sourceNotFound`, zéro transient world, zéro thrashing, puck lifecycle clean |

**TL;DR RÉSOLU statement (verbatim from `docs/phase-07-ios-animate-camera-crash.md` line 4):**

> _Statut 2026-04-22 22:00 — **RÉSOLU** (commits `81d30c7` + `ab497ab` + `40b49d5`)._

**User feedback post-fix (verbatim, Tentative 4 device-smoke):**

> "la carte charge instantanément, le point bleu ne clignote pas, pas de crash quand on ouvre la carte".

**Step-by-step results 2026-04-23 final smoke (verbatim from `docs/phase-07-smoke.md` Entry 2):**

| #   | Step                                                | Result | Notes |
| --- | --------------------------------------------------- | ------ | ----- |
| 1   | Sideload + first launch                             | _PASS_ |       |
| 2   | "Préparation de la carte…" then SessionListScreen   | _PASS_ |       |
| 3   | Create + start session                              | _PASS_ |       |
| 4   | MapScreen: map renders + AppBar affordances visible | _PASS_ |       |
| 5   | Burger menu: 3 tiles + 3 live-data rows             | _PASS_ |       |
| 6   | Airplane mode cold-start: map still renders         | _PASS_ |       |
| 7   | Aruba download completes                            | _PASS_ |       |
| 8   | Aruba in Manage screen with correct size + version  | _PASS_ |       |
| 9   | Delete Aruba → disappears + world row stays         | _PASS_ |       |
| 10  | Xcode container inspection: `NSURLIsExcludedFromBackupKey=1` on `world.pmtiles` + installed country `.pmtiles` | _N/A_ | No macOS available — degraded to PASS-with-caveat per rubric clause. Backup-exclude code-path covered by `test/infrastructure/platform/ios_backup_excluder_test.dart` + `test/phase_07_integration/map_end_to_end_test.dart`. |

**Verdict (verbatim from Entry 2):** **PASS-with-caveat** — every interactive step passed on the iPhone 17 Pro under iOS 26.3.1. The sole caveat is step 10 (Xcode container inspection of the `NSURLIsExcludedFromBackupKey` attribute) which this project cannot perform end-to-end: builds happen on GitHub Actions' `macos-latest` runners, the IPA is downloaded + sideloaded via SideStore, and there is no local macOS toolchain to mount the device's container and run `xattr -l`. The backup-exclude code-path is covered at the boundary by dedicated tests — operator will re-litigate at Phase 08 Review Gate if evidence of the on-device attribute is required.

</details>

**Airplane-mode evidence snapshot:**

Both device walks confirmed that airplane-mode = zero tile HTTP. This is the **SC#1 primary evidence** : the bundled world PMTiles renders without any outbound network request, and the Phase 07 lint gate `tool/check_avoid_remote_pmtiles.dart` statically forbids any non-local `pmtiles:///` URI in `lib/**/*.dart` + `test/**/*.dart` + `assets/**/*.json`. Combined runtime + static evidence = complete "zero tile HTTP" guarantee.

**Protocol §6 (verbatim from `docs/phase-07-smoke.md` Protocol step 6 — applied to both devices):**

> **Enable airplane mode on the device (OS-level).** Relaunch app from cold. Verify the map STILL RENDERS from the bundled world.pmtiles, session UX still works (MAP-01 code-path already verified by `test/phase_07_integration/airplane_mode_test.dart`; this step validates the code-path holds under real native MapLibre rendering).

**Android (Pixel 4a, Step 6 result from `docs/phase-07-smoke.md` Entry 1):**

| #   | Step                                                | Result | Notes |
| --- | --------------------------------------------------- | ------ | ----- |
| 6   | Airplane mode cold-start: map still renders         | _PASS_ |       |

**iOS (iPhone 17 Pro, Step 6 result from `docs/phase-07-smoke.md` Entry 2):**

| #   | Step                                                | Result | Notes |
| --- | --------------------------------------------------- | ------ | ----- |
| 6   | Airplane mode cold-start: map still renders         | _PASS_ |       |

**Gate corroboration (static):** `tool/check_avoid_remote_pmtiles.dart` wired into CI `gates` job (Phase 07) — exit 0 on the Phase 07 final commit `fbcbde6` (same SHA as both device-smoke builds). No `pmtiles://` URI references a remote URL anywhere in `lib/**/*.dart` + `test/**/*.dart` + `assets/**/*.json`. Combined with the two device walks above, runtime + static evidence converge on SC#1 "zero tile HTTP in airplane mode".

**Overall Phase 07 close verdict (verbatim from `docs/phase-07-smoke.md` §Overall Phase 07 close verdict):**

> - **Android smoke:** approved
> - **iOS smoke:** approved (PASS-with-caveat — step 10 not performable from the project's CI-only macOS setup; see Entry 2 Verdict for details)
> - **Ready for Phase 08 Review Gate:** approved

## 2. Claude audit findings

*Filled by Plan 08-03: first the 10 pre-classified CONTEXT handoff items + the Smell heuristics hot-spots table, then the 4 parallel sub-agents in ONE tool-use message (hybrid layer+risk slicing per CONTEXT).*

Format: `[severity] Title — 1-line explanation — file:line`. Severities: Blocker / Should / Could / Noted. Smell-tagged findings get an inline `[smell:fix-on-fix]` or `[smell:over-state-machine]` tag after severity.

### Pre-known from CONTEXT

*Filled by Plan 08-03 Task 1 BEFORE spawning sub-agents. Source: 08-CONTEXT.md §Implementation Decisions / §2 pre-class items (10 items). Committed as `docs(08-rev): pre-class 10 CONTEXT handoff items into §2` before any Agent tool call.*

| # | Item | Severity | Rationale |
|---|------|----------|-----------|
| 1 | Water filter Polygon/MultiPolygon only (rivers-as-LineString invisibles) | Noted | User-decided 2026-04-21 post-device-smoke. Water encodé LineString dans source-layer Protomaps n'est pas rendered ; enrichissement complet reporté phase V1.x. Ref `07-06-SUMMARY.md §Post-ship amendments` + `07-CONTEXT.md §<deferred>`. |
| 2 | Background downloads → V2 backlog (Android FGS + iOS URLSession.background) | Noted | User-decided 2026-04-21 post-device-smoke. Download suspendu au screen-lock V1.0 (resume Range-based au foreground) ; vrai background V2 per `PROJECT.md §V2 Backlog`. Agent #3 vérifie copy UX ne promet pas "background continues". |
| 3 | iOS animateCamera crash RÉSOLU 2026-04-22 | Noted | Commits `81d30c7` + `ab497ab` + `40b49d5`. Ref `docs/phase-07-ios-animate-camera-crash.md`. Agent #3 vérifie la fix tient + qu'aucun `// fix for edge case` n'est introduit. |
| 4 | Plan 07-07 absorbed → ROADMAP+REQUIREMENTS sync | Should | **Fix landed in Plan 08-01 Task 3** (MAP-05/06/07/08/10 Complete ; Plan 07-07 scope-reduced ; `07-07-SUMMARY.md` written). Row confirms done ; regression re-opens as fix-in-loop. |
| 5 | pmtiles-heal path in FirstLaunchBootstrap (mid-rename kill recovery) | Noted | Invariant shipped Plan 07-04. Agent #1 + Agent #2 vérifient heal path cohérent avec atomic rename + que soak scenario #6 est la couverture test. |
| 6 | Smell heuristics hot-spots (4 components) | category-inline | See `### Smell heuristics hot-spots` table below. Not a single finding row but a category anchor pointing agents at 4 pressure points. |
| 7 | ROADMAP/REQUIREMENTS sync obligatoire | Should | Dupliqué avec #4 volontairement (catch either lens). Agent #4 flag si drift ré-introduit ; fix en §5 closure checklist (Plan 08-05 Task 4). |
| 8 | `tool/simplify_polygons.dart` + `tool/generate_tiny_pmtiles.dart` audit | Could/Noted | Agent #4 lens : licences deps / output déterministe / paired tests / README. |
| 9 | CountryResolver edge cases (SC#2) | Should-if-findings-else-Noted | Agent #1 lens : frontier 2 pays / viewport beyond installed country → fallback world bundle / zoom world-only / polygon simplification lossy (bbox-only). Severity escalates to Should si gap tests surfaced. |
| 10 | DEPENDENCIES.md audit deltas Phase 07 | Noted | maplibre_gl 0.25.0 BSD-3 + crypto + shelf. Agent #4 confirm licence + télémétrie-zero + deps transitives rescan (no GPL/AGPL contamination), version pinning strict match `pubspec.yaml`. |

### Smell heuristics hot-spots

*Filled by Plan 08-03 Task 1 alongside pre-class items. Source: 08-CONTEXT.md §Cross-cutting smell-heuristics from CLAUDE.md §En review faire attention à (2026-04-23 delta).*

| Component | File path | Primary Agent | Smell pattern to look for |
|-----------|-----------|---------------|---------------------------|
| PmtilesDownloadController 7-step | `lib/infrastructure/downloads/pmtiles_download_controller.dart` | **#2** | **State machine tirée par les cheveux** — sealed states sync-only, dispatcher géant par step, transitions quasi-toutes-vers-toutes si échec. Q : est-ce qu'une fonction pure séquentielle + Result-type propagation ferait le même boulot que les 7 états nommés ? |
| MapCameraController follow/pan/iOS-fix | `lib/application/controllers/map_camera_controller.dart` | **#3** | **Code alambiqué par empilement de fix** — booleans accumulés (isFollowing / hasBeenInitialized / _pendingCamera), early returns post-fix iOS crash. Q : est-ce que la fix iOS animateCamera (commits 81d30c7/ab497ab/40b49d5) a introduit des guards défensifs qui révèlent un design sous-jacent à revoir ? |
| StyleRewriter + 2 validators | `lib/infrastructure/map/style_rewriter.dart` | **#1** | **Dispatcher duplication** — switch par validator type, logique répétée entre branches. Q : est-ce que les 2 validators partagent assez de surface pour fusionner en un validator-chain strategy ? |
| ActiveSessionController + ActiveSessionState Phase 05 legacy | `lib/application/controllers/active_session_controller.dart` | **#3** | **Sealed states intermediate-sync-only** — états Idle/Starting/Tracking/Stopping/ErrorState Phase 05 ; touché par 07-05 controllers wiring (MapCameraController hook). Q : est-ce que 07-05 a amplifié une state-machine sur-dimensionnée ? |

### Agent #1 — Map infra + seam purity
*Scope: `lib/domain/map/` + `lib/infrastructure/map/` + `tool/check_avoid_maplibre_leak.dart` + `tool/check_avoid_remote_pmtiles.dart` + paired tests. Hot-spot: StyleRewriter + 2 validators.*
(pending)

### Agent #2 — Download pipeline + atomicity
*Scope: `lib/infrastructure/downloads/` + 6 existing soak + shelf-backed FakeHttpServer. Hot-spot: PmtilesDownloadController 7-step sealed states.*
(pending)

### Agent #3 — Controllers + providers + presentation
*Scope: `lib/application/` map-related + `lib/presentation/` map screens/widgets + router deltas + Phase 05 ActiveSessionController legacy. Hot-spots: MapCameraController follow/pan/iOS-fix + ActiveSessionController.*
(pending)

### Agent #4 — Natives + assets + CI gates + DEPENDENCIES.md + CLAUDE.md sweep + smell transverses
*Scope: platform channels (Kotlin + Swift) + Android INTERNET + `assets/maps/` + 4 tool files + `DEPENDENCIES.md` deltas + CLAUDE.md anti-patterns sweep + transversal smell lens.*
(pending)

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>
(pending)
</details>

## 3. Triage decisions

*Filled by Plan 08-03 Task 5 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden per CONTEXT.md). Every Should MUST be either `fix` or `waived` with inline rationale. Smell-tagged findings get an explicit decision (fix / refactor / defer) visible in the table.*

| # | Finding | Severity | Smell tag | Decision | Rationale | Commit hash |
|---|---------|----------|-----------|----------|-----------|-------------|
| (pending) | | | | | | |

## 4. Adversarial evidence

*Filled by Plan 08-04. Seven permanent-test evidence blocks (Tests #1-#7: 4 integration tests MOVE+NEW + 3 permanent unit tests) + one adversarial CI evidence block (Test #8 — throwaway branch `adversarial/08-style-external-url` exercising `tool/check_style_no_external_url.dart`) + two soak edge case evidence blocks (Tests #9-#10 — corrupt chunk mid-stream + rename target already exists appended to existing `test/infrastructure/downloads/download_soak_test.dart`).*

### Test 1: integration_test/airplane_mode_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/airplane_mode_test.dart` → `integration_test/airplane_mode_test.dart`, add `@Tags(['integration'])`, add inertness guard (pre-assert `FakeMapView.showMapInvocations.isNotEmpty` before asserting `_FailAllHttpClient.invocationCount == 0`). Covers MAP-01 subset of QUAL-05.*

(pending)

### Test 2: integration_test/first_launch_world_copy_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/first_launch_world_copy_test.dart` → `integration_test/first_launch_world_copy_test.dart`, add inertness guards per §4 Test #2 contract. Covers MAP-07 + auto-heal (scenarios A/B/C).*

(pending)

### Test 3: integration_test/map_end_to_end_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/map_end_to_end_test.dart` → `integration_test/map_end_to_end_test.dart`, add inertness guards. Covers MAP-08/09/10 full user journey (download + display + delete + fallback).*

(pending)

### Test 4: integration_test/phase_07_navigation_test.dart (NEW)
*Brand-new file. Covers router 5 new routes + back-navigation + deep-links for Phase 07 screens (/map + /maps-download + /maps-manage + /style-import + /style-export). Inertness guard: pre-assert GoRouter received push/go events AND screens emitted a build().*

(pending)

### Test 5: test/infrastructure/assets/world_bundle_sha256_test.dart (NEW permanent unit test)
*Recompute sha256 of `assets/maps/world.pmtiles` via `crypto sha256.bind` streaming + assert equal to `kWorldBundleSha256` constant. Inertness guard: file exists + size > 0. Protects against asset-change-without-constant-update silent drift.*

(pending)

### Test 6: test/infrastructure/downloads/manifest_atomicity_contract_test.dart (NEW permanent unit test)
*Inject FS fake throwing at 4 points (before tempfile, during tempfile write, after tempfile write, during rename) + assert post-throw file state is either unchanged or totally updated. Inertness guard: fake FS received ≥ 1 write before throw. Complements the 6 soak scenarios with a narrow repo-level contract.*

(pending)

### Test 7: test/infrastructure/network/no_httpclient_in_unit_tests_test.dart (NEW permanent unit test)
*Pure-Dart scan `test/` (exclude `integration_test/` + files with `@Tags(['integration'])`) for `HttpClient()` / `http.Client()` / `Dio()` patterns. Inertness guard: scan visited ≥ N files. Protects against unit tests silently acquiring real network.*

(pending)

### Test 8: tool/check_style_no_external_url.dart adversarial CI run (throwaway branch adversarial/08-style-external-url)
*Branch `adversarial/08-style-external-url`: poison commit injects `"url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"` into `assets/maps/style.json`. CI step `Check style no external URL` (added to `.github/workflows/ci.yml` `gates` job in Plan 08-04) MUST fail with exit 1 and stderr identifying the file path + JSON path + offending URL. Branch deleted local + remote post-archivage; main `on.push.branches` stays `[main]`-only.*

(pending)

### Tests 9-10: 2 new soak edge cases (appended to existing download_soak_test.dart)
*Test #9: corrupt chunk mid-stream (chunk #3 of 5 returns sha256-mismatch payload — assert staging cleaned, state=failed-with-retry, `.pmtiles` cible absent). Test #10: rename target already exists (simulate retry where cible `.pmtiles` already present — assert AtomicRenamer gère correctement per contract, zero manifest leak). Both `@Tags(['soak'])`. Covers SC#3 extension beyond the 6 existing scenarios.*

(pending)

## 5. CI-green confirmation

*Filled by Plan 08-05 Task 3 after all Blocker + non-waived Should fixes are applied and CI is green.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending — all 3 jobs gates+android+ios green, optionally integration-tests)
- **Date:** (pending)

---
_Phase 08 closed: (pending)_
_Phase 09 unblocked._

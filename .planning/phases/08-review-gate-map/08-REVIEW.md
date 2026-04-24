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

1. [Should] README claims "8-layer" but constant holds 7 layers — `lib/infrastructure/map/README.md:14` documents a "Frozen 8-layer constant"; `style_layer_order.dart:35` actually exposes 7 IDs after Phase 07-07 removal of `user_location`. Same drift in `lib/config/constants.dart:218-219`, `lib/domain/map/map_errors.dart:123,125-126`, `assets/maps/style.json:5,8` — `lib/infrastructure/map/README.md:14`, `lib/config/constants.dart:218`, `lib/domain/map/map_errors.dart:123`, `assets/maps/style.json:5` (also flagged by Agent #4 — Should)
2. [Should] StyleRewriter does NOT reject external URLs anywhere — audit-spec claim unsubstantiated — `assertStyleLayerValidity` checks layer shape/source-existence/source-layer; never inspects `sources[*].url` for `http(s)://` or `mapbox://`. Only the lint gate blocks `pmtiles://http`. A hand-edited `style.json` with raster `https://...` tiles passes both validators and reaches MapLibre at runtime — `lib/infrastructure/map/style_layer_order.dart:103-162`, `lib/infrastructure/map/style_rewriter.dart:47-86`
3. [Should] MapLibreMapView and FakeMapView disagree on post-dispose semantics — Production `_aliveOrLog` silently returns on `_disposed=true`; FakeMapView `_checkNotDisposed` throws StateError. Tests never exercise the production "silent ignore" path — `lib/infrastructure/map/maplibre_map_view.dart:462`, `test/fakes/fake_map_view.dart:164`
4. [Could] `_userLocationLayerInstalled` + `_lastUserLocationFix` pair is fix-on-fix instead of deduction — Twin-flag bookkeeping for "is source installed?" could be a single pure guard (catch sourceNotFound) — `lib/infrastructure/map/maplibre_map_view.dart:266-273,302-307,340-373` [smell:fix-on-fix]
5. [Could] Two validators share full parse+iterate surface; dispatcher duplication — `assertStyleLayerOrder` + `assertStyleLayerValidity` both parse style (2×), iterate `parsed['layers']` (2×), duplicate error-message literal. Could fuse into one-pass validator returning List<MapStyleCorruptException> — `lib/infrastructure/map/style_layer_order.dart:48-80,103-162`
6. [Could] CountryResolver iteration-order contract is load-bearing but enforced only by convention — Docstring says callers "should pass a LinkedHashMap seeded with installed-order" but ctor accepts any `Map<>`. Tie-break could silently flip if a SplayTreeMap is passed — `lib/infrastructure/map/country_resolver.dart:45-47`
7. [Could] Barcelona tie-break is the ONLY resolver frontier test; Strasbourg/FRA-DEU uncovered — FRA/DEU overlap in Alsace band (`lon [5.9..9], lat [47.3..51]`) uncovered; polygon-simplification lossy consequences not regression-tested — `test/infrastructure/map/country_resolver_test.dart:60-72`
8. [Could] FakeMapView has two getters (`followMeEnabled` + `isFollowMeEnabled`) returning identical state — Dead surface; MapView port already exposes `isFollowMeEnabled` publicly — `test/fakes/fake_map_view.dart:65,155`
9. [Could] `_pmtilesSource` field in `_MapLibreMapViewAdapter` is dead with an ignore comment (Phase 09 placeholder) — Prophylactic cargo-cult per CLAUDE.md §Wrappers — `lib/infrastructure/map/maplibre_map_view.dart:237`
10. [Could] `simplify_polygons.dart` has NO paired test under `tool/test/` — Every other CI-critical tool has a paired test. Silent regression would ship broken polygons — `tool/simplify_polygons.dart` (also flagged by Agent #4 — Should)
11. [Noted] Antimeridian-straddling polygons are NOT split by `CountryResolver`; documented only in `point_in_polygon_test.dart` — Fiji/USA-Aleutians/Russia Far East misclassify; V2 concern (Phase 07 fixture set avoids) — `test/infrastructure/map/geo/point_in_polygon_test.dart:112`, `lib/infrastructure/map/country_resolver.dart:56-63`
12. [Noted] `FirstLaunchWorldCopier` auto-heal + post-write verify covered; no "redundant copies" bug found — Matches MAP-07 contract — `lib/infrastructure/map/first_launch_world_copier.dart:36-99`

### Agent #2 — Download pipeline + atomicity
*Scope: `lib/infrastructure/downloads/` + 6 existing soak + shelf-backed FakeHttpServer. Hot-spot: PmtilesDownloadController 7-step sealed states.*

1. [Blocker] Pause busy-spin in `_processQueue` — `_processJob` returns (not breaks) on pause so outer `while (_queue.isNotEmpty)` immediately re-enters, re-emits `DownloadPaused`, loops forever until `resume()` flips the flag; no test covers this — `lib/infrastructure/downloads/pmtiles_download_controller.dart:236-255` + `:294-308` [smell:over-state-machine]
2. [Should] Permanent-failure loop on reassembled sha256 mismatch — Size-correct-but-byte-corrupt chunks survive across re-enqueues; no cancel/purge path, no per-chunk verify to localize which chunk corrupted; user must manually cancel — `pmtiles_download_controller.dart:337-339` + `:414-429` + `:375-385` [smell:fix-on-fix]
3. [Should] Protocol doc drift — step 2 "Per-chunk sha256" is no longer implemented — Class docstring + README declare per-chunk verification; actual code deliberately dropped it — `pmtiles_download_controller.dart:30-51` + `lib/infrastructure/downloads/README.md:14`
4. [Should] `_accumulatedBytes` corruption on 200-OK-restart fallback mid-resume — Pre-added localSize then downloader rewrites from byte 0 + onProgress re-accumulates; double-counts for life of job. `.clamp()` masks UI but counter bleeds into subsequent parts — `pmtiles_download_controller.dart:455-459` + `http_chunk_downloader.dart:113-115`
5. [Should] `CountryDeleteService` doc claims heal removes orphan manifest entries — heal path never does that — Class docstring says "absent → entry removed"; `_healOrphanCountryFiles` only inserts, never removes. Crash between `file.delete` and `manifest.write` leaves dangling manifest entry — `country_delete_service.dart:31-36` vs `first_launch_bootstrap.dart:_healOrphanCountryFiles`
6. [Should] `AtomicRenamer` EXDEV fallback has no test + no partial-write cleanup — `copy` may partial-write target then throw; except-branch just rethrows, leaving corrupt half-file. No test exercises this branch — `atomic_renamer.dart:56-63` + `test/infrastructure/downloads/atomic_renamer_test.dart`
7. [Should] No dedup against already-installed alpha3 — `_alpha3IsActiveOrQueued` checks queue + active state but not manifest; re-enqueue of an installed country runs full download + overwrites — `pmtiles_download_controller.dart:151-192`
8. [Could] `_processQueue.finally` resets `_pauseRequested = false` even on normal exit — Cosmetic coupling; load-bearing for stale-flag prevention. Worth a comment or refactor — `pmtiles_download_controller.dart:248-254`
9. [Could] Controller state machine collapses — 8 variants do not form a clean graph — `DownloadRetrying` + `DownloadInProgress(concatenating)` overlap; `DownloadPaused` ↔ `DownloadInProgress` is one boolean; `_emit` call sites form a dispatcher switch disguised as strongly-typed construction. A "phase enum on single active-job record" would express the same without 8 sealed variants — `lib/domain/downloads/download_state.dart:32-147` + `pmtiles_download_controller.dart:137-530` [smell:over-state-machine] (also flagged by Agent #4 — Should)
10. [Could] `BinaryConcatenator` ConcatFailureException catches too broadly on the pre-open guard path — Guard throws BEFORE `openWrite` but subsequent try/catch teardown runs against uninitialized sink. Works (catchError eats it) but twisty — `binary_concatenator.dart:50-101`
11. [Could] `HttpChunkDownloader.downloadWithResume` returns `DownloadChunkResult` that no caller reads — Only unit test asserts on it; if purely for tests, named tuple or logger.debug would be simpler — `http_chunk_downloader.dart:21-22`
12. [Could] Soak "resume_restart" test cannot distinguish pass-through from a corrupted restart state — Ties into #4; no assertion on progress counter sanity — `test/infrastructure/downloads/download_soak_test.dart:206-239`
13. [Could] Soak file has no scenario for "connection-drop mid-chunk → retry → success" — Retry logic tested at downloader unit level but not end-to-end via `_httpDownloadWithRetries`. Most likely real-world failure path (4G hiccups on 1.5GB France download) — `test/infrastructure/downloads/download_soak_test.dart`
14. [Could] `DownloadQueueStore.load` drops `whereType<Map<String, Object?>>()` entries without logging — Silent filter masks migration bugs; emit warning when `decoded.length != retained.length` — `download_queue_store.dart:57`
15. [Noted] Bootstrap heal path uses `DateTime.now().toUtc().toIso8601String().substring(0, 10)` for pmtilesVersion when catalog absent — Magic-numeric slice — `first_launch_bootstrap.dart:197`
16. [Noted] `Sha256Verifier` still exposed in README step-2 and still wired through providers, even though the download controller no longer uses it — Dead path for downloads, live path for bootstrap heal — `sha256_verifier.dart` + `README.md:14,51`
17. [Noted] `FakeHttpServer` has 7 sealed behaviours (not 6) — The brief said 6; `ServeChunkedSlowly` is 7th, added for throttled-progress testing (correctly). Spec document stale — `test/fakes/fake_http_client.dart:175-228`
18. [Noted] Delete service does not cleanup orphan file when manifest lacks the entry — Returns early without touching disk; orphan `<alpha3>.pmtiles` survives — `country_delete_service.dart:62-65`
19. [Noted] `pmtiles-heal` path only runs on launch; mid-session crash between atomic-rename + manifest-write leaves invariant broken until next app launch — Heal IS coherent with atomic rename (pre-class item #5 verified). Does NOT cover "in-manifest but file missing" (finding #5) — `first_launch_bootstrap.dart:137-210` + soak `:266-323`

### Agent #3 — Controllers + providers + presentation
*Scope: `lib/application/` map-related + `lib/presentation/` map screens/widgets + router deltas + Phase 05 ActiveSessionController legacy. Hot-spots: MapCameraController follow/pan/iOS-fix + ActiveSessionController.*

1. [Should] MapCameraController has THREE separate listener sources driving state — `_viewportSub` (stream) + `_sessionSub` (Riverpod ProviderSubscription) + `ref.listen<MapView?>` in build() — each with detach/reattach dance. Single ref.listen topology + composed derived state would halve bookkeeping — `lib/application/controllers/map_camera_controller.dart:95-112, 199-254` [smell:fix-on-fix]
2. [Should] CountryResolverController has TWO parallel manifest listener paths for same signal — `_manifestSub` (ref.listen on `installedManifestProvider`) + `_manifestStreamSub` (direct `repo.updates.listen`) both invoke `_rebuildResolver` on overlapping events; secondary comment ("ensures resolver rebuilds even if StreamProvider layer has not been subscribed") is the textbook defensive-workaround shape — `lib/application/controllers/country_resolver_controller.dart:189-215` [smell:fix-on-fix]
3. [Should] InstalledMapsController bypasses `installedManifestProvider` and attaches to `repo.updates` directly — Identical distrust-of-provider-layer rationale as #2, suggesting `installedManifestProvider` itself may be the smell source — `lib/application/controllers/installed_maps_controller.dart:75-103` (may overlap Agent #1)
4. [Should] MapCameraController.openForSession body is now "do nothing to the camera" with a 16-line comment — After iOS fix method has no camera-moving side effect; only primes puck + toggles follow-me. Rename `primeForSession` or inline into `_onMapReady` — `map_camera_controller.dart:118-165` [smell:fix-on-fix]
5. [Could] MapCameraController tracks three pieces of state effectively one — `_cameraMovePending` + `_pendingResetTimer` + `_currentZoom` — could be `DateTime _lastProgrammaticMoveAt` + `Duration` check, removing timer lifecycle — `map_camera_controller.dart` [smell:over-state-machine]
6. [Could] MapCameraState enum has 4 variants where 2 differ only by "has lastFix landed" — Centering vs Following carry same sessionId; could be `(sessionId, followMode, hasFirstFix)` record with computed `isCentering` — `map_camera_controller.dart:28-63` [smell:over-state-machine]
7. [Could] ActiveSessionState exposes 5 variants where ErrorState duplicates AsyncError channel — Downstream consumers pattern-match on BOTH; consolidating onto AsyncError removes one class — `active_session_controller.dart:141-157` [smell:over-state-machine]
8. [Could] ActiveSessionController has defensive guards that stack into complex start/stop handshake — `_isStopping`, `_currentSessionId` pre-assigned, `activated: bool` rollback flag, try/catch inside try/catch. Each justified; aggregate shape invites reconcile-pattern redesign — `active_session_controller.dart:53-158, 165-189` [smell:fix-on-fix]
9. [Could] MapScreen `deactivate` workaround schedules `notifier.set(null)` on Future.microtask with swallowed try/catch — "Catch exception a correct design would make impossible" — `map_screen.dart:68-110` [smell:fix-on-fix]
10. [Could] `_onMapReady` has a `Future.delayed(Duration.zero)` — textbook `// fix for edge case when…` comment — Scheduled removal once maplibre_gl >= 0.26.0 ships — `map_screen.dart:242-281`
11. [Could] `_DistanceRow` renders a fake value with a 10-line apology comment — Shows `'Distance : 0 m'` / `'Distance : — m'`; render `—` without pretending or defer to Phase 09 — `session_burger_menu.dart:172-187`
12. [Noted] CountryResolverController._resolveAndApply branches on 3 outcomes through if-return chain — Readable; sealed `ResolveOutcome` + switch would be exhaustive — `country_resolver_controller.dart:255-289` [smell:over-state-machine]
13. [Noted] DownloadQueueController has `_rehydrated: bool` flag to call `rehydrate()` once at first enqueue — Per CLAUDE.md §State "préférer déduction au tracking"; idempotent inner `rehydrate()` would suffice — `download_queue_controller.dart:38, 54-57`
14. [Noted] MapScreen injects `mapViewBuilderForTest` as `@visibleForTesting` nullable field — Correct pattern; couples prod widget ctor to test concern — `map_screen.dart:50-59`
15. [Noted] Router uses pure `context.push` for all Phase 07 routes; `context.go('/')` usages legitimate — Compliant with CLAUDE.md §Navigation
16. [Noted] `context.mounted` post-await discipline present at every await-then-use site — Compliant
17. [Noted] Riverpod 3.x patterns correct — `valueOrNull` not used; `AsyncValue.value` throughout; `ProviderScope(overrides: [...])` inline in tests; StateProvider→Notifier migration documented via MapViewHolder
18. [Noted] MAP-06 seam: `package:maplibre_gl` imports confined to `lib/infrastructure/map/maplibre_map_view.dart` — Zero leakage; paired CI check + mutation-guard test enforce
19. [Noted] FirstLaunchBootstrap pre-init respects Zone discipline — `runZonedGuarded` wraps container creation + `UncontrolledProviderScope(container: rootContainer)` inherits warm cache. Phase 04 P4 precedent preserved — `main.dart:142-151`
20. [Noted] SessionBurgerMenu copy does not promise features non-construites — 3 unwired tiles surface "disponible en Phase 11/13" snackbars. Compliant with pre-class #2
21. [Noted] MapDownloadProgressChip + MapsDownloadScreen do not promise "background continues" — Grep confirms no such copy. Aligns with V2-deferred background (pre-class #2)
22. [Noted] iOS animateCamera crash fix holds — `openForSession` does NO camera method-call post-onStyleLoaded; initialCamera via `initialCameraPosition` widget prop. No `// fix for edge case` regression. 16-line comment documents shape-level constraint (see #4)
23. [Noted] CountryResolverController debounce 500ms single-fires on pan-then-zoom — Timer cancels on every new viewport; no double-fire
24. [Noted] MapScreen initialCountry seeding reads polygons via `resolveForPoint` — Bypasses viewport-stream pipeline so works at widget-build time. Elegant
25. [Noted] Country resolver + manifest use String key for containsKey mixing with CountryCode — `manifest.installed.containsKey(resolved.value)`. Risks string-drift; typed helper would be cleaner (may overlap Agent #1)

### Agent #4 — Natives + assets + CI gates + DEPENDENCIES.md + CLAUDE.md sweep + smell transverses
*Scope: platform channels (Kotlin + Swift) + Android INTERNET + `assets/maps/` + 4 tool files + `DEPENDENCIES.md` deltas + CLAUDE.md anti-patterns sweep + transversal smell lens.*

1. [Should] style.json metadata description drift — actual layer count = 7 but metadata/docstring says "8-layer" — `assets/maps/style.json:5,8` call out "8-layer order" ending in user_location; `layers[]` holds 7; `kStyleLayerOrder.length == 7`. user_location is now GeoJSON source+layer at runtime, not declared style layer — `assets/maps/style.json:5,8` [smell:fix-on-fix] (also flagged by Agent #1 — Should)
2. [Should] Phase 07 tool scripts have no paired tests — `generate_tiny_pmtiles`, `generate_world_sha256`, `prepare_style`, `simplify_polygons` all expose `runCheck(...)` public entry points for testing but `tool/test/` has zero files for them. Only `check_avoid_maplibre_leak_test` + `check_avoid_remote_pmtiles_test` landed — `tool/test/` (also flagged by Agent #1 — Could for simplify_polygons specifically)
3. [Should] tool/README.md does not document any Phase 07 tool — README lists only Phase 01-05 tools; missing all Phase 07 gates + scripts + platform-manifests gate from Phase 06 — `tool/README.md`
4. [Should] `prepare_style.dart` pin-SHA is `UNPINNED` — `tool/prepare_style.dart:78` `const String _kPinnedCommitSha = 'UNPINNED';`. Script docstring says pin "is source of truth; bump in dedicated commit". Phase 07-01 summary says "placeholder mode" — real Protomaps glyph/sprite assets still missing from `assets/maps/glyphs/` + `assets/maps/sprites/` (README placeholders only) — `tool/prepare_style.dart:78`
5. [Should] Duplicate `catalogVersion` extraction logic — `country_catalog.dart:53-66` (extension) + `pmtiles_download_controller.dart:556-560` (`_extractCatalogVersion`) both parse `/releases/download/([^/]+)/` with different failure contracts (extension throws FormatException, private method synthesizes `untagged-YYYYMMDD`) — `country_catalog.dart:53-66` + `pmtiles_download_controller.dart:556-560` [smell:fix-on-fix]
6. [Should] Transversal smell: `DownloadState` variants' field-name inconsistency forces dispatcher chains across ≥3 files — `DownloadInProgress.progress` vs `DownloadPaused.snapshot` vs `DownloadRetrying.snapshot` — same `DownloadProgress` type, three different field names. Observed: `maps_download_screen.dart:191-234` (5 copies), `map_download_progress_chip.dart:53-67` (2 more), `pmtiles_download_controller.dart:184-189`, `download_queue_controller.dart:87-96`. Rename to unified field `progress` + extension getter collapses ~10 copies into 1 — `lib/domain/downloads/download_state.dart` + 4 consumer files [smell:over-state-machine] (also flagged by Agent #2 — Could #9)
7. [Could] `DownloadCompleted` / `DownloadCancelled` carry only `alpha3`, not `DownloadJob` — Every other variant carries `DownloadJob active`; asymmetry forces UI lookup via `_displayNameFor(alpha3, catalog)` at `maps_download_screen.dart:90` — `lib/domain/downloads/download_state.dart:133,144`
8. [Could] Magic `Duration` literals at snackbar sites — `maps_download_screen.dart:86` `Duration(seconds: 5)`, `:90` `Duration(seconds: 3)`. Should live in `lib/config/constants.dart` per CLAUDE.md §Magic numbers — `maps_download_screen.dart:86,90`
9. [Could] Private `_k…` const hoisted into per-file scope instead of `lib/config/constants.dart` — At least `_kUserLocationSourceId`/`_kUserLocationLayerId` (`maplibre_map_view.dart:22,26`), `_kViewportDebounce` (`country_resolver_controller.dart:79`), `_kPendingMoveDebounce` (`map_camera_controller.dart:92`), `_kRelativePath` (`download_queue_store.dart:30`), `_kTimeout` (`disk_space_checker.dart:38`). Count is rising across Phase 07
10. [Could] `tool/prepare_style.dart` non-deterministic copy shape — `tool/prepare_style.dart:139,157` unsorted `listSync()` contrasts `simplify_polygons.dart:104` which DOES explicitly sort — `tool/prepare_style.dart:139,157`
11. [Could] Naming deviation — `Set<T>` fields without `Set` suffix — `installed_maps_controller.dart:34,125`, `country_resolver_controller.dart:227`. Only `queuedAlpha3Set` (`first_launch_bootstrap.dart:217`) honours convention
12. [Could] `tool/prepare_style.dart:161` variable-name shadowing — Inner `final File src = ...` shadows outer `Directory src = Directory(sourceDir)` at :124. Cosmetic — `tool/prepare_style.dart:161`
13. [Could] DEPENDENCIES.md omits `integration_test` row — Declared as direct dev-dep in pubspec.yaml; `check_dependencies_md.dart:44` skips SDK-sourced so gate stays green, but asymmetry: every OTHER direct dep has a row — `DEPENDENCIES.md` (may overlap Agent #2)
14. [Could] Android BootCompletedReceiver `exported="true"` — Acceptable (BOOT_COMPLETED + MY_PACKAGE_REPLACED system broadcasts require it) but flag for `check_platform_manifests.dart` to protect — `android/app/src/main/AndroidManifest.xml:101`
15. [Noted] Platform-channel triple-source-of-truth matches byte-for-byte — `kDiskSpaceChannelName` = `app.gosl.mirkfall/disk_space` across Dart/Kotlin/Swift. `kIosBackupExcluderChannelName` = `app.gosl.mirkfall/ios_backup_excluder` across Dart/Swift. Audit prompt filenames were stale (referred to `DiskSpaceChecker*.kt`; actual `DiskSpaceChannel.kt`) but content correct
16. [Noted] World bundle asset sha256 matches `kWorldBundleSha256` constant — `62782f3b...` exact match. Non-deletable floor integrity intact
17. [Noted] DEPENDENCIES.md Phase 07 deltas complete for crypto / maplibre_gl / shelf — All rows present; MapLibre Native Android 12.3.0 + iOS 6.14.0 BSD-2-Clause with zero telemetry; image 4.8.0 Apache-2.0
18. [Noted] CI gate wiring for `check_avoid_maplibre_leak` + `check_avoid_remote_pmtiles` live + paired tests include mutation-guard — `.github/workflows/ci.yml:123-127`; both catch `clean → poisoned` exit-code flip
19. [Noted] ROADMAP + REQUIREMENTS drift from Plan 07-07 absorption resolved — Phase 07 row `7/7 Complete`, MAP-05/06/07/08/10 → Complete, 07-07 line annotated. Heads-up #4 + #7 satisfied

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>

#### Agent #1 — Map infra + seam purity

**Seam purity.** The `MapView` port is clean of MapLibre types in public + private signatures; the grep confirms 0 MapLibre SDK symbols leaking below `lib/domain/`. Every `MapView` method signature uses only primitive types, domain types, or positional records. The `MapLibreMapViewWidget` public `onReady` callback returns `MapView`, not the adapter — correct seam. Only subtle violation is that the widget's public constructor requires `PmtilesSource` + `StyleRewriter` (infra types) rather than going through a factory the application layer could override — intentional DI composition, acceptable.

**Lint gates.** Both `check_avoid_maplibre_leak.dart` and `check_avoid_remote_pmtiles.dart` have solid paired tests at `tool/test/` with mutation-guard tests (Phase 04/06 inertness-guard idiom) that prove the gates flip exit code 0→1 on violation. The regex is quote-agnostic and anchored on line start; the pmtiles gate uses `caseSensitive: false` closing the "UPPER-CASE bypass" hole. Correct.

**StyleRewriter + validators hot-spot.** Two validators share the parse step + layers-iteration but check disjoint axes (layer ID ordering vs per-layer shape). A single-pass collector returning a `List<MapStyleCorruptException>` would be cleaner and faster — right now the style is parsed twice and layers iterated twice per `rewriteStyleForCountry`. Second concern: the audit claim "StyleRewriter rejects external URLs correctly" is NOT implemented — the only defence against an externally-pointing `sources[*].url` in a hand-edited `style.json` is the lint gate, which only catches `pmtiles://http[s]`, not plain `https://tiles.example.com/...`.

**Fix-on-fix in MapLibre adapter.** The Phase 07-07 puck fix is a surgical workaround for a MapLibre Native + AnnotationManager bug. The choice to own the GeoJSON source + circle layer directly is sound. What's over-engineered is the twin-field state (`_userLocationLayerInstalled` + `_lastUserLocationFix`) + the `showMap` restore path — the "is source installed?" question is derivable from calling `setGeoJsonSource` and catching the `sourceNotFound` PlatformException. Kept-in-sync flags + restore dance is the classic "bug → patch" footprint. Not severe — current shape works, justification is documented, Phase 09 rewrites this layer anyway.

**CountryResolver edge cases.** Correctly falls back to `null` (world bundle) below `kWorldFallbackZoomCutoff=8.0`, on empty installed polygons, and when no polygon matches. Deterministic tie-break via `Map.entries` insertion order is load-bearing and documented but enforced only by convention. Solid single-country coverage but only ONE frontier overlap test (Barcelona FRA/ESP). FRA/DEU, GBR/FRA, USA/CAN untested. The bbox-only output of `simplify_polygons.dart` is well-documented; just not test-covered for every border.

**FirstLaunchWorldCopier.** Solid shape. Idempotent, auto-heals on sha256 mismatch with streaming IOSink, post-write verify. The idempotence test proves loader is not re-invoked when healthy — no redundant copies. Post-write mismatch is treated as catastrophic and surfaces as `MapAssetMissingException`.

**Minor surface & doc drift.** The "8-layer" / "user_location" references in README, constants, MapStyleCorruptException docstring, and style.json metadata are cross-file stale — removed in 07-07 but docs not synced. FakeMapView has a redundant getter. The adapter holds a `_pmtilesSource` field only for Phase 09. None break the seam; tidying opportunities. The disposed-semantics gap between Fake and real adapter COULD mask a real bug — tests never exercise the "silent ignore" production path.

#### Agent #2 — Download pipeline + atomicity

**7-step atomic protocol + invariant.** The absent-or-fully-installed invariant (MAP-09) is structurally upheld by ordering: chunks land in staging, concat produces staging-local reassembled file, atomic rename commits it, manifest write follows. Between rename (step 5) and manifest write (step 6) there's a window where invariant is broken; `_healOrphanCountryFiles` closes that window on next launch. Soak scenario #6 exercises it cleanly. Protocol doc drifted from implementation — class docstring step 2 still enumerates "per-chunk sha256: after each chunk lands, verify against ChunkPart.sha256. One retry on mismatch; second mismatch is terminal". Actual `_acquireChunk` explicitly trusts chunks on size alone. Decision is defensible but divergence is fix-on-fix smell.

**Hot-spot: PmtilesDownloadController state machine.** Eight sealed DownloadState variants do NOT form a clean transition graph. `DownloadRetrying` differs from `DownloadInProgress` by a couple of fields and a semantic "between network attempts" — could be a phase enum on the existing `DownloadInProgress`. `DownloadPaused` ↔ `DownloadInProgress` is driven by a single boolean, not state-machine transitions. Dispatcher at `_processJob:236-386` is a linear sequence wrapped in try/catch. A `Result<InstalledCountry, DownloadError>` return from a private pure `_runJob`, emitting phase events on a broadcast stream, would be structurally cleaner. Pause implementation is the smell's most concrete cost — when `_pauseRequested` flips mid-job, `_processJob` returns (line 307), but `_processQueue`'s `while` re-invokes `_processJob` immediately. Each iteration emits another `DownloadPaused` and returns. No await of external I/O in spin → tight-spins until `resume()` flips flag. **Blocker bug** masked by state-machine confusion.

**HTTP layer + shelf-backed fake.** `HttpChunkDownloader` handles Range/206, 200-OK restart fallback, 302 redirect chain, 4xx classification cleanly. Subtle issue: `_accumulatedBytes` at controller level pre-adds localSize before invoking downloader; if downloader falls back to 200-OK restart (truncates destination + re-streams every byte via onProgress), controller double-counts. `.clamp()` masks UI fraction but counter bleeds into subsequent parts. UX bug (progress numbers), not correctness.

**Atomicity primitives.** `AtomicRenamer` correctly classifies POSIX EXDEV (18) + Windows ERROR_NOT_SAME_DEVICE (17). Copy+delete fallback is not atomic (acknowledged) and has NO test coverage. On iOS where `<app_support>` is typically co-located with tmp, EXDEV should be rare, but if `staging/` ever lives on a different mount, fallback's failure mode (partial target + rethrown exception) is undefined. `BinaryConcatenator` is solid: streaming chunked sha256 via `sha256.startChunkedConversion` tees into IOSink for zero-copy-overhead verification. On failure, destination is unlinked before exception propagates. `JsonFileInstalledManifestRepository` uses tempfile + rename with `flush: true` (fsync) and serialises concurrent writes via `_writeTail` promise chain.

**CountryDeleteService + world sentinel.** Sentinel compare relies on `CountryCode` value-equality — correct. File-first-then-manifest ordering leaves inconsistent state on crash (file absent, manifest still has entry) — class docstring says "bootstrap heals that case by recomputing on-disk sha256s (absent → entry removed)" but `_healOrphanCountryFiles` only inserts missing entries, never removes stale ones. Doc drift + correctness gap.

**Soak test coverage.** 6 declared scenarios align with coverage list: happy / multi-part / 206 resume / 200 restart / disk insufficient / mid-rename kill heal. Missing: retry-loop recovery end-to-end (connection drops mid-chunk, controller retries, succeeds on attempt 2+) — tested at downloader unit level but not through `_httpDownloadWithRetries` with `retryBackoffs`. Most likely real-world failure path.

**Heal path coherence (pre-class #5).** Verified. Soak scenario #6 asserts `healedAlpha3s == ['deu']`, re-inserted sha256, orphan file's presence. Heal does NOT cover "in-manifest but file missing" (finding #5).

#### Agent #3 — Controllers + providers + presentation

**MapCameraController (hot-spot A).** Three separate attach/detach cycles — `ref.listen<MapView?>` in build() for adapter publication, `_viewportSub` for viewport echoes, `_sessionSub` for active-session fixes. Each has its own "if cleared, drop stale reference" branch with its own cancel dance. Plus debounce timer. iOS fix did NOT introduce ceremony — it REMOVED a camera-moving call from `openForSession`. But it left method as "prime puck, set follow-me enabled, flip to Following" — no camera move. The 16-line commit comment compensates for semantic gap: method name still promises to move camera. Rename + inline would eliminate comment. `_cameraMovePending` + `_pendingResetTimer` implements echo-suppression via flag-and-debounce — single `DateTime _lastProgrammaticMoveAt` collapses it. Centering + Following carry identical sessionId + differ only by first-fix-arrived — collapsible to record. Overall: iOS fix is clean; accumulated listener bookkeeping IS fix-on-fix residue. Recommend follow-up refactor.

**ActiveSessionController (hot-spot B).** Phase 05 legacy, touched by 07-05. Starting is an intermediate-sync-only state — per CLAUDE.md §État "états intermédiaires qui n'existent que le temps d'un appel synchrone". ErrorState vs AsyncError double-channel forces UI to pattern-match on both. Defensive ceremony in `start()` — `_currentSessionId` pre-assigned, `activated: bool` rollback flag, `_rollbackPartialActivation` with try/catch-swallow — is justified per Phase 06 Blocker #1 but cumulative shape is fix-on-fix. Clean redesign would be `reconcile(desiredActive: SessionId?)` that converges on (sub, dbRow, notification, state). Bigger than Phase 08 should undertake but worth flagging.

**Router + navigation discipline.** All 5 new Phase 07 routes follow `context.push` consistently. MapScreen uses `Navigator.of(context).maybePop()` via `_BackButton` widget (only renders when `canPop()` true). Only `context.go('/')` usages are post-delete reset + permission-flow terminal — both legitimate. Compliant.

**Providers (map_providers.dart).** All 16 providers `keepAlive: true` with justification comments. `MapViewHolder` notifier + aliased `mapViewProvider` handles Riverpod 3.x StateProvider removal cleanly. `MapViewportZoom` has an `unawaited(() async { try { ... } on Object { /* benign */ } }())` IIFE that seeds initial zoom from `queryViewport()` — relies on Riverpod-internal guard as catch-net; if that guard changes in future version, silently breaks. Could be explicit `ref.mounted` check.

**Presentation.** SessionBurgerMenu is well-structured. `_DistanceRow` is the weakest — pretends to compute something it doesn't. MapsDownloadScreen is thorough. MapScreen's `deactivate` workaround is the most fragile — 20-line explanatory comment proof of non-trivial complexity.

**Tests.** MapCameraController tests exercise open-with-fix-present/no-fix/echo-filtering/manual-pan/follow-me paths. Fake ActiveSessionController subclass clean. `mapViewBuilderForTest` typedef seam lets widget tests drop FakeMapView. `phase_07_navigation_test.dart` uses harness router + stub screens — pragmatic. MAP-06 seam test includes mutation-guard (clean fixture → exit 0, poisoned → exit 1).

**Cross-file patterns.** `ref.listen<AsyncValue<...>>` consistent in both places. `String` vs `CountryCode` key drift is minor typed-boundary weakness — manifest keeps String keys because JSON; controllers parse String → CountryCode at use sites. Typed accessor helper would cleanup.

**Closing.** No blockers. 4 Should-grade shape-consolidation findings. 2 Should-grade design-shape findings. iOS fix holds. State machines over-sized for behaviour but over-sizing is legacy — call out for future slim-down rather than rewrite now.

#### Agent #4 — Natives + assets + CI gates + DEPENDENCIES.md + CLAUDE.md sweep + smell transverses

**Natives & platform channels.** Two hand-rolled MethodChannels land cleanly. Kotlin `DiskSpaceChannel` singleton + Swift `DiskSpaceChannel` + `IosBackupExcluderChannel` each guard two documented failure modes (path validation + IO exception) and forward structured error codes back to Dart. Defensive `catch (e: Throwable)` is justified (Flutter runtime interprets unhandled Throwable as driver-level crash). Dart pairs platform call with 5s timeout + re-raises `DiskSpaceCheckException` — matches CLAUDE.md §Timeouts. `IosBackupExcluder` guards against missing iOS handler (MissingPluginException → `_log.fine` swallow). Triple-source-of-truth channel-name matching verified character-for-character. Audit prompt filenames stale but actual wiring correct. `AndroidManifest.xml` INTERNET permission narrow + well-commented: gates HTTPS download pipeline against GitHub Release URLs only, not FGS abuse.

**Assets + DEPENDENCIES.md.** Bundled world PMTiles (856 KB) hashes exactly to `kWorldBundleSha256`. Per-country polygons tree holds 249 `<alpha3>.geo.json` + INDEX.md sidecar. catalog.json schema matches Plan 07-01. style.json attribution carries both Protomaps + OSM. No source-url references `pmtiles://http[s]://`. **Glyphs + sprites asset dirs are placeholder-only** — `prepare_style.dart` wired but `_kPinnedCommitSha` is `'UNPINNED'`. Phase 07-01 summary says deferred to Plan 07-06. DEPENDENCIES.md entries complete for maplibre_gl 0.25.0 + crypto 3.0.7 + shelf 1.4.2 (all match pubspec.lock); MapLibre Native Android 12.3.0 + iOS 6.14.0 BSD-2-Clause + zero telemetry documented. `image 4.8.0` Apache-2.0. **Minor:** `integration_test` direct dev-dep has no DEPENDENCIES.md row (gate stays green because check_dependencies_md.dart skips SDK sources).

**Tool scripts + CI gates.** Two new CI gates wired at `.github/workflows/ci.yml:123-127` with paired tests including Phase 04/06 inertness-guard idiom. Other four Phase 07 scripts (`generate_tiny_pmtiles`, `generate_world_sha256`, `prepare_style`, `simplify_polygons`) expose `runCheck(...)` but no paired tests landed. `simplify_polygons` best-defended (explicit sort at :104); `prepare_style` does not sort (finding #10). None complicated enough that missing test is a blocker, but Phase 02 convention is clear. tool/README.md not updated since Phase 05.

**CLAUDE.md cross-cutting sweep.** Largest transversal smell is finding #6 — `DownloadState` sealed hierarchy ships three differently-named fields (`progress` / `snapshot` / `snapshot`) that carry same `DownloadProgress` type, forcing every consumer to write dispatch chain. ~10 near-identical switch blocks across 4 files. CLAUDE.md §State machine tirée par les cheveux calls this out verbatim. Field rename (unify on `progress`) + single `DownloadProgress?` extension getter on `DownloadState` collapses ~10 copies into 1, keeping sealed-match safety. This is refactor CLAUDE.md §Code Review Phases invites: "quitte à remettre en cause architecture produite aux phases précédentes."

Secondary smells: `DownloadCompleted/Cancelled` drop full DownloadJob (finding #7) forcing UI-side lookup; Local `_k…` constants leak into per-file scope (finding #9) — single-source-of-truth promise erodes; `Set<T>` fields without `Set` suffix (finding #11); No `is X`/`is Y` polymorphism-miss chains; No manual path concat in infra layer.

**Fix-on-fix / defensive buildup.** Two patterns sit close to fix-on-fix line but each documented: `maplibre_map_view.dart` has 10 `_aliveOrLog(method)` guards (iOS crash 2026-04-21 — Riverpod keepAlive listener firing into disposed adapter); `_userLocationLayerInstalled` flag crosses a `setStyle()` boundary invisible to Dart (justified-flag case from CLAUDE.md §State "traverse un crash boundary"). Genuine fix-on-fix smell is finding #5 (catalogVersion duplicated with different failure contracts).

**Closing note.** Phase 07 produces clean native wiring, solid CI gates, thorough licensing audit. Most load-bearing findings: DownloadState hierarchy field-naming asymmetry (finding #6 — strongest candidate for Phase 08 `[smell:over-state-machine]` refactor), Phase 07 tool scripts' missing paired tests + README (findings #2, #3), `prepare_style.dart` pin-SHA at UNPINNED with placeholder glyph/sprite assets (finding #4). Everything else is polish-level.

</details>

## 3. Triage decisions

*Filled by Plan 08-03 Task 4 after user-decided blanket triage (2026-04-23). User verbatim: "do all the blocker, should, could, afterward I will do a full walk on both application and we will fix bugs then redo the same review". Interpretation: all Blocker/Should/Could rows → `fix` (or `refactor` when smell-tagged architectural rewrite); all Noted rows → `accepted-as-is` for the 16 positive confirmations and `defer-to-v2` for the 10 minor items. Fix/refactor rows receive their commit hashes during Plan 08-05 execution — pending at triage time. Decision counts: 40 fix + 9 refactor + 0 waived + 10 deferred + 16 accepted-as-is = 75 total.*

| # | Finding (title + file:line) | Severity | Smell tag | Decision | Rationale | Commit hash |
|---|-----------------------------|----------|-----------|----------|-----------|-------------|
| 1 | Pause busy-spin in `_processQueue` — `pmtiles_download_controller.dart:236-255,294-308` | Blocker | [smell:over-state-machine] | fix | blanket fix per user triage 2026-04-23 | acd6820 |
| 2 | README "8-layer" drift — constant holds 7 (A1/A4 cross-lens) — `lib/infrastructure/map/README.md:14`, `style_layer_order.dart:35`, `constants.dart:218`, `map_errors.dart:123`, `style.json:5,8` | Should | — | fix | blanket fix per user triage 2026-04-23 (merged with #15 — same "8→7 layer" concern) | 5dd35fa |
| 3 | StyleRewriter does NOT reject external URLs — audit claim unsubstantiated — `style_rewriter.dart:47-86`, `style_layer_order.dart:103-162` | Should | — | fix | blanket fix per user triage 2026-04-23 | f5d1ea3 |
| 4 | MapLibreMapView vs FakeMapView disagree on post-dispose semantics — `maplibre_map_view.dart:462`, `fake_map_view.dart:164` | Should | — | fix | blanket fix per user triage 2026-04-23 | 7681847 |
| 5 | Permanent-failure loop on reassembled sha256 mismatch — `pmtiles_download_controller.dart:337-339,414-429,375-385` | Should | [smell:fix-on-fix] | fix | blanket fix per user triage 2026-04-23 (+ CI-red recovery 801c5be: soak #9 realignment) | 320a5ee |
| 6 | Protocol doc drift — step 2 "per-chunk sha256" no longer implemented — `pmtiles_download_controller.dart:30-51`, `README.md:14` | Should | — | fix | blanket fix per user triage 2026-04-23 (folded into soak-realign commit) | 801c5be |
| 7 | `_accumulatedBytes` corruption on 200-OK-restart fallback mid-resume — `pmtiles_download_controller.dart:455-459`, `http_chunk_downloader.dart:113-115` | Should | — | fix | blanket fix per user triage 2026-04-23 (+ format-fix follow-up f95c55c) | 356a66b |
| 8 | CountryDeleteService doc claims heal removes orphan manifest entries — heal path never does — `country_delete_service.dart:31-36` vs `first_launch_bootstrap.dart:_healOrphanCountryFiles` | Should | — | fix | blanket fix per user triage 2026-04-23 | cee697f |
| 9 | AtomicRenamer EXDEV fallback has no test + no partial-write cleanup — `atomic_renamer.dart:56-63`, `atomic_renamer_test.dart` | Should | — | fix | blanket fix per user triage 2026-04-23 | c8cc177 |
| 10 | No dedup against already-installed alpha3 — `pmtiles_download_controller.dart:151-192` | Should | — | fix | blanket fix per user triage 2026-04-23 | af54852 |
| 11 | MapCameraController has THREE listener sources (ref.listen + _viewportSub + _sessionSub) — `map_camera_controller.dart:95-112,199-254` | Should | [smell:fix-on-fix] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural | 9c91484 |
| 12 | CountryResolverController has TWO parallel manifest listener paths (_manifestSub + _manifestStreamSub) — `country_resolver_controller.dart:189-215` | Should | [smell:fix-on-fix] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural | f0de3f3 |
| 13 | InstalledMapsController bypasses `installedManifestProvider` and attaches to `repo.updates` directly — `installed_maps_controller.dart:75-103` | Should | — | fix | blanket fix per user triage 2026-04-23 | 4456cb1 |
| 14 | MapCameraController.openForSession body is now "do nothing to camera" with 16-line comment — `map_camera_controller.dart:118-165` | Should | [smell:fix-on-fix] | fix | blanket fix per user triage 2026-04-23 | 29a38a3 |
| 15 | style.json metadata description drift — "8-layer" but actual 7 (A4/A1 cross-lens) — `assets/maps/style.json:5,8` | Should | [smell:fix-on-fix] | fix | blanket fix per user triage 2026-04-23 (merge-by-concern with #2) | 5dd35fa |
| 16 | Phase 07 tool scripts have no paired tests (generate_tiny_pmtiles / generate_world_sha256 / prepare_style / simplify_polygons) — `tool/test/` | Should | — | fix | blanket fix per user triage 2026-04-23 (completed across c14b55b generate_world_sha256 + 979b210 simplify_polygons + 90afc52 generate_tiny_pmtiles + prepare_style) | 90afc52 |
| 17 | tool/README.md does not document any Phase 07 tool — `tool/README.md` | Should | — | fix | blanket fix per user triage 2026-04-23 | 014df72 |
| 18 | `prepare_style.dart` pin-SHA is `UNPINNED` + placeholder glyphs/sprites — `tool/prepare_style.dart:78` | Should | — | fix | blanket fix per user triage 2026-04-23 | c14b55b |
| 19 | Duplicate `catalogVersion` extraction logic with divergent failure contracts — `country_catalog.dart:53-66`, `pmtiles_download_controller.dart:556-560` | Should | [smell:fix-on-fix] | fix | blanket fix per user triage 2026-04-23 | ef39130 |
| 20 | DownloadState field-name inconsistency forces dispatcher chains across ≥3 files (A4/A2 cross-lens) — `lib/domain/downloads/download_state.dart` + 4 consumer files | Should | [smell:over-state-machine] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural | a99874d |
| 21 | `_userLocationLayerInstalled` + `_lastUserLocationFix` twin-flag bookkeeping — `maplibre_map_view.dart:266-273,302-307,340-373` | Could | [smell:fix-on-fix] | fix | blanket fix per user triage 2026-04-23 | 9847cb7 |
| 22 | Two validators share full parse+iterate surface; dispatcher duplication — `style_layer_order.dart:48-80,103-162` | Could | — | fix | blanket fix per user triage 2026-04-23 (extracted shared _iterateStyleLayers generator) | 765be7a |
| 23 | CountryResolver iteration-order contract is load-bearing but enforced only by convention — `country_resolver.dart:45-47` | Could | — | fix | blanket fix per user triage 2026-04-23 (frozen iteration-order captured into internal List) | 4646576 |
| 24 | Barcelona tie-break is the ONLY resolver frontier test; FRA/DEU + polygon-simplification lossy uncovered — `country_resolver_test.dart:60-72` | Could | — | fix | blanket fix per user triage 2026-04-23 (4 new tests: Strasbourg, Andorra, Corsica, Canary Islands) | 2554f02 |
| 25 | FakeMapView has two getters (`followMeEnabled` + `isFollowMeEnabled`) returning identical state — `fake_map_view.dart:65,155` | Could | — | fix | blanket fix per user triage 2026-04-23 (dropped duplicate, migrated 9 callers to isFollowMeEnabled) | 50e2d38 |
| 26 | `_pmtilesSource` field in `_MapLibreMapViewAdapter` is dead with ignore comment (Phase 09 placeholder) — `maplibre_map_view.dart:237` | Could | — | fix | blanket fix per user triage 2026-04-23 (dropped field + widget prop + wiring chain; Phase 09 can re-add with explicit use) | e8a2b4a |
| 27 | `simplify_polygons.dart` has NO paired test under `tool/test/` (A1/A4 cross-lens) — `tool/simplify_polygons.dart` | Could | — | fix | blanket fix per user triage 2026-04-23 | 979b210 |
| 28 | `_processQueue.finally` resets `_pauseRequested = false` even on normal exit — `pmtiles_download_controller.dart:248-254` | Could | — | fix | already fixed in row #1 busy-spin commit (acd6820 removed the reset + added the break; finally block now only clears _cancelRequested + completes _processingDone, inline comment references row #28) | acd6820 |
| 29 | Controller state machine collapses — 8 DownloadState variants do not form clean graph (A2/A4 cross-lens, overlaps #20) — `download_state.dart:32-147`, `pmtiles_download_controller.dart:137-530` | Could | [smell:over-state-machine] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural (documentation refactor: explicit group partition + ASCII transition graph + per-variant justification; dispatcher dedup already landed in row #20) | a6517a7 |
| 30 | BinaryConcatenator ConcatFailureException catches too broadly on pre-open guard path — `binary_concatenator.dart:50-101` | Could | — | fix | blanket fix per user triage 2026-04-23 | 4b1453d |
| 31 | `HttpChunkDownloader.downloadWithResume` returns `DownloadChunkResult` that no caller reads — `http_chunk_downloader.dart:21-22` | Could | — | fix | blanket fix per user triage 2026-04-23 | 355d91d |
| 32 | Soak "resume_restart" test cannot distinguish pass-through from corrupted restart state — `download_soak_test.dart:206-239` | Could | — | fix | blanket fix per user triage 2026-04-23 | c6170b1 |
| 33 | Soak file has no scenario for "connection-drop mid-chunk → retry → success" — `download_soak_test.dart` | Could | — | fix | blanket fix per user triage 2026-04-23 | 64e0e60 |
| 34 | `DownloadQueueStore.load` drops invalid entries without logging — `download_queue_store.dart:57` | Could | — | fix | blanket fix per user triage 2026-04-23 | 194d002 |
| 35 | MapCameraController tracks three state pieces effectively one (`_cameraMovePending` + `_pendingResetTimer` + `_currentZoom`) — `map_camera_controller.dart` | Could | [smell:over-state-machine] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural (collapsed flag+timer → `DateTime? _lastProgrammaticMoveAt` timestamp comparison; `_currentZoom` preserved as zoom cache per CLAUDE.md §State) | ee03fe4 |
| 36 | MapCameraState 4 variants where 2 differ only by "hasFirstFix" (Centering vs Following) — `map_camera_controller.dart:28-63` | Could | [smell:over-state-machine] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural (dropped MapCameraCentering; MapCameraFollowing now carries `hasFirstFix` + computed `isCentering`) | 16f18f0 |
| 37 | ActiveSessionState exposes 5 variants where ErrorState duplicates AsyncError channel — `active_session_controller.dart:141-157` | Could | [smell:over-state-machine] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural (dropped ErrorState; GpsError now routes through AsyncError like all other exceptions; no UI consumer was pattern-matching on ErrorState) | e80531a |
| 38 | ActiveSessionController defensive guards stack into complex start/stop handshake — `active_session_controller.dart:53-158,165-189` | Could | [smell:fix-on-fix] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural (scope-down: extract 5× try/catch-and-log staircase into `_bestEffort(ctx, op)` helper; underlying Phase 06 Blocker #1 guards preserved; reconcile-pattern rewrite deferred per Agent #3 narrative) | 6a14fff |
| 39 | MapScreen `deactivate` workaround schedules `notifier.set(null)` on Future.microtask with swallowed try/catch — `map_screen.dart:68-110` | Could | [smell:fix-on-fix] | refactor | blanket refactor per user triage 2026-04-23 — smell-tagged architectural (scope-down: extract into `_nullifyMapViewProviderAfterDeactivate()` with structured docstring separating microtask-reason from try/catch-reason; Riverpod 3.x constraint is canonical accommodation not fix-on-fix; lifecycle redesign deferred to Riverpod 4.x in Phase 10) | 4f2033b |
| 40 | `_onMapReady` has `Future.delayed(Duration.zero)` — textbook "// fix for edge case when…" comment — `map_screen.dart:242-281` | Could | — | fix | blanket fix per user triage 2026-04-23 | 1195c9e |
| 41 | `_DistanceRow` renders fake value with 10-line apology comment — `session_burger_menu.dart:172-187` | Could | — | fix | blanket fix per user triage 2026-04-23 | e503cab |
| 42 | `DownloadCompleted` / `DownloadCancelled` carry only `alpha3`, not `DownloadJob` (asymmetry forces UI lookup) — `download_state.dart:133,144` | Could | — | fix | blanket fix per user triage 2026-04-23 | dd8f2b2 |
| 43 | Magic `Duration` literals at snackbar sites — `maps_download_screen.dart:86,90` | Could | — | fix | blanket fix per user triage 2026-04-23 | 8801e30 |
| 44 | Private `_k…` const hoisted into per-file scope instead of `lib/config/constants.dart` (5+ locations, rising) — `maplibre_map_view.dart:22,26`, `country_resolver_controller.dart:79`, `map_camera_controller.dart:92`, `download_queue_store.dart:30`, `disk_space_checker.dart:38` | Could | — | fix | blanket fix per user triage 2026-04-23 (5-file sweep: kUserLocationSourceId / kUserLocationLayerId / kCountryResolverViewportDebounce / kMapCameraPendingMoveDebounce / kDownloadQueueStorePath / kDiskSpaceCheckTimeout all hoisted) | ddf0c7a |
| 45 | `tool/prepare_style.dart` non-deterministic copy shape — unsorted `listSync()` — `tool/prepare_style.dart:139,157` | Could | — | fix | blanket fix per user triage 2026-04-23 | 7816fd5 |
| 46 | Naming deviation — `Set<T>` fields without `Set` suffix — `installed_maps_controller.dart:34,125`, `country_resolver_controller.dart:227` | Could | — | fix | blanket fix per user triage 2026-04-23 | 735ca52 |
| 47 | `tool/prepare_style.dart:161` variable-name shadowing (inner `File src` shadows outer `Directory src`) — `tool/prepare_style.dart:161` | Could | — | fix | blanket fix per user triage 2026-04-23 | 38a57e2 |
| 48 | DEPENDENCIES.md omits `integration_test` row — `DEPENDENCIES.md` | Could | — | fix | blanket fix per user triage 2026-04-23 | 65323a0 |
| 49 | Android BootCompletedReceiver `exported="true"` — flag for `check_platform_manifests.dart` to protect — `AndroidManifest.xml:101` | Could | — | fix | blanket fix per user triage 2026-04-23 | 1e65cb4 |
| 50 | Antimeridian-straddling polygons NOT split by `CountryResolver` — `point_in_polygon_test.dart:112`, `country_resolver.dart:56-63` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 51 | `FirstLaunchWorldCopier` auto-heal + post-write verify covered; no "redundant copies" bug found (positive ✓) — `first_launch_world_copier.dart:36-99` | Noted | — | accepted-as-is | positive confirmation of MAP-07 contract — no action needed | — |
| 52 | Bootstrap heal path uses magic-numeric `.substring(0, 10)` for pmtilesVersion when catalog absent — `first_launch_bootstrap.dart:197` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 53 | `Sha256Verifier` still exposed in README step-2 and wired through providers even though download controller no longer uses it — `sha256_verifier.dart`, `README.md:14,51` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 54 | `FakeHttpServer` has 7 sealed behaviours (spec said 6) — `fake_http_client.dart:175-228` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 55 | Delete service does not cleanup orphan file when manifest lacks the entry — `country_delete_service.dart:62-65` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 56 | `pmtiles-heal` only runs on launch; mid-session crash between atomic-rename + manifest-write leaves invariant broken until next app launch — `first_launch_bootstrap.dart:137-210`, soak `:266-323` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 57 | CountryResolverController._resolveAndApply branches on 3 outcomes through if-return chain — `country_resolver_controller.dart:255-289` | Noted | [smell:over-state-machine] | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 58 | DownloadQueueController `_rehydrated: bool` flag at first enqueue — `download_queue_controller.dart:38,54-57` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 59 | MapScreen injects `mapViewBuilderForTest` as `@visibleForTesting` nullable field — `map_screen.dart:50-59` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 60 | Router uses pure `context.push` for all Phase 07 routes; `context.go('/')` usages legitimate (positive ✓) | Noted | — | accepted-as-is | positive confirmation compliant with CLAUDE.md §Navigation — no action needed | — |
| 61 | `context.mounted` post-await discipline present at every await-then-use site (positive ✓) | Noted | — | accepted-as-is | positive confirmation compliant — no action needed | — |
| 62 | Riverpod 3.x patterns correct (AsyncValue.value, ProviderScope inline, MapViewHolder migration) (positive ✓) | Noted | — | accepted-as-is | positive confirmation compliant — no action needed | — |
| 63 | MAP-06 seam: `package:maplibre_gl` imports confined to `maplibre_map_view.dart`; zero leakage + mutation-guard test (positive ✓) | Noted | — | accepted-as-is | positive confirmation of MAP-06 contract — no action needed | — |
| 64 | FirstLaunchBootstrap pre-init respects Zone discipline; Phase 04 P4 precedent preserved — `main.dart:142-151` (positive ✓) | Noted | — | accepted-as-is | positive confirmation — no action needed | — |
| 65 | SessionBurgerMenu copy does not promise features non-construites (3 unwired tiles show Phase 11/13 snackbars) (positive ✓) | Noted | — | accepted-as-is | positive confirmation aligns with pre-class #2 — no action needed | — |
| 66 | MapDownloadProgressChip + MapsDownloadScreen do not promise "background continues" (positive ✓) | Noted | — | accepted-as-is | positive confirmation aligns with V2-deferred background (pre-class #2) — no action needed | — |
| 67 | iOS animateCamera crash fix holds — no `// fix for edge case` regression; 16-line comment documents shape-level constraint (positive ✓) | Noted | — | accepted-as-is | positive confirmation — no action needed | — |
| 68 | CountryResolverController debounce 500ms single-fires on pan-then-zoom (positive ✓) | Noted | — | accepted-as-is | positive confirmation — no action needed | — |
| 69 | MapScreen initialCountry seeding reads polygons via `resolveForPoint` (positive ✓) | Noted | — | accepted-as-is | positive confirmation — no action needed | — |
| 70 | Country resolver + manifest use String key for containsKey mixing with CountryCode — `manifest.installed.containsKey(resolved.value)` | Noted | — | defer-to-v2 | scope-limited per user triage 2026-04-23 (fix Blocker+Should+Could, defer Noted minor items to V2 or accept-as-is for positive confirmations) | — |
| 71 | Platform-channel triple-source-of-truth matches byte-for-byte (kDiskSpaceChannelName + kIosBackupExcluderChannelName) (positive ✓) | Noted | — | accepted-as-is | positive confirmation — no action needed | — |
| 72 | World bundle asset sha256 matches `kWorldBundleSha256` constant (62782f3b…) (positive ✓) | Noted | — | accepted-as-is | positive confirmation of non-deletable floor integrity — no action needed | — |
| 73 | DEPENDENCIES.md Phase 07 deltas complete for crypto / maplibre_gl / shelf + MapLibre Native BSD-2 + image Apache-2.0 (positive ✓) | Noted | — | accepted-as-is | positive confirmation of telemetry-zero audit — no action needed | — |
| 74 | CI gate wiring for `check_avoid_maplibre_leak` + `check_avoid_remote_pmtiles` live + paired tests include mutation-guard — `.github/workflows/ci.yml:123-127` (positive ✓) | Noted | — | accepted-as-is | positive confirmation — no action needed | — |
| 75 | ROADMAP + REQUIREMENTS drift from Plan 07-07 absorption resolved (Phase 07 row `7/7 Complete`, MAP-05/06/07/08/10 → Complete) (positive ✓) | Noted | — | accepted-as-is | positive confirmation (heads-up #4 + #7 satisfied) — no action needed | — |

## 4. Adversarial evidence

*Filled by Plan 08-04. Seven permanent-test evidence blocks (Tests #1-#7: 4 integration tests MOVE+NEW + 3 permanent unit tests) + one adversarial CI evidence block (Test #8 — throwaway branch `adversarial/08-style-external-url` exercising `tool/check_style_no_external_url.dart`) + two soak edge case evidence blocks (Tests #9-#10 — corrupt chunk mid-stream + rename target already exists appended to existing `test/infrastructure/downloads/download_soak_test.dart`).*

### Test 1: integration_test/airplane_mode_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/airplane_mode_test.dart` → `integration_test/airplane_mode_test.dart`, add `@Tags(['integration'])`, add inertness guard (pre-assert `FakeMapView.showMapInvocations.isNotEmpty` before asserting `_FailAllHttpClient.invocationCount == 0`). Covers MAP-01 subset of QUAL-05.*

- **File:** `integration_test/airplane_mode_test.dart`
- **Type:** permanent regression guard (integration test, `@Tags(['integration'])`)
- **Covers:** MAP-01 + QUAL-05 subset (airplane-mode zero tile HTTP)
- **Commit hash:** `46c84e0` — `test(08-rev): move 3 Phase 07 integration tests to integration_test/ + inertness guards` (shared with Tests #2 + #3 via a single `git mv` commit — see rename detection in `git log --follow`)
- **Verify command:** `flutter test integration_test/airplane_mode_test.dart`
- **Test run result:** PASS 2026-04-23 (1/1 testWidgets)
- **Inertness guard (quote):**
  ```dart
  // Inertness guard (Plan 08-04): prove the showMap code path was
  // actually exercised before we assert zero HTTP invocations.
  expect(
    fakeMapView.showMapInvocations.isNotEmpty,
    isTrue,
    reason: 'FakeMapView.showMap never invoked — test would be inert (pump did not reach MapScreen render path).',
  );
  ```
- **Mutation experiment (author-time):** Skipped the `await fakeMapView.showMap(...)` country-switch calls inside the pump body. Re-ran `flutter test integration_test/airplane_mode_test.dart` and observed FAIL with the reason `FakeMapView.showMap never invoked — test would be inert…`. Restored the calls, re-ran, green. Documented inline at the file header.

### Test 2: integration_test/first_launch_world_copy_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/first_launch_world_copy_test.dart` → `integration_test/first_launch_world_copy_test.dart`, add inertness guards per §4 Test #2 contract. Covers MAP-07 + auto-heal (scenarios A/B/C).*

- **File:** `integration_test/first_launch_world_copy_test.dart`
- **Type:** permanent regression guard (integration test, `@Tags(['integration'])`)
- **Covers:** MAP-07 (world-bundle copy + auto-heal), scenarios A (fresh clean tempdir) / B (idempotent no-op) / C (corrupt-byte heal)
- **Commit hash:** `46c84e0` (shared move commit)
- **Verify command:** `flutter test integration_test/first_launch_world_copy_test.dart`
- **Test run result:** PASS 2026-04-23 (3/3 tests)
- **Inertness guards (quotes):**
  ```dart
  // Scenario A — clean-tempdir precondition
  expect(target.existsSync(), isFalse, reason: 'precondition: tempdir must be clean — test would be inert otherwise');

  // Scenario C — byte-flip-actually-corrupts precondition
  expect(
    sha256.convert(await target.readAsBytes()).toString(),
    isNot(worldSha256),
    reason: 'precondition: file must be corrupted after the flip — test would be inert otherwise',
  );
  ```
- **Mutation experiment (author-time):** Neutralised the byte-flip in scenario C (wrote the original bytes back instead of corrupting). Re-ran `flutter test integration_test/first_launch_world_copy_test.dart` → FAILED with the corrupted-sha inertness-guard reason (pre-fix-sha matched worldSha256 so the next `ensureInstalled` short-circuits). Restored the flip → green.

### Test 3: integration_test/map_end_to_end_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/map_end_to_end_test.dart` → `integration_test/map_end_to_end_test.dart`, add inertness guards. Covers MAP-08/09/10 full user journey (download + display + delete + fallback).*

- **File:** `integration_test/map_end_to_end_test.dart`
- **Type:** permanent regression guard (integration test, `@Tags(['integration'])`)
- **Covers:** MAP-08/09/10 subset — Aruba download flow + MapsManageScreen post-install listing + "Monde (intégré)" non-deletable floor
- **Commit hash:** `46c84e0` (shared move commit)
- **Verify command:** `flutter test integration_test/map_end_to_end_test.dart`
- **Test run result:** PASS 2026-04-23 (2/2 testWidgets)
- **Inertness guards (quotes) — 4 guards distributed at journey steps:**
  ```dart
  // Step 1 — catalog rendered
  expect(find.text('Aruba'), findsOneWidget, reason: 'catalog list must render Aruba — test would be inert otherwise');
  // Step 2 — confirm dialog opened post-tap
  expect(find.text('Télécharger Aruba ?'), findsOneWidget, reason: 'download-confirm dialog must open — test would be inert otherwise');
  // Step 3 — enqueue observed post-confirm-tap
  expect(fakeDownload.enqueueObservations, isNotEmpty, reason: 'no enqueue observed at tap step — test would be inert');
  // Manage-screen — seeded state surfaces
  expect(
    fakeInstalled.build().installed.containsKey(CountryCode.parse('abw')),
    isTrue,
    reason: 'fakeInstalled did not expose Aruba — test would be inert',
  );
  ```
- **Mutation experiment (author-time):** Skipped the `tester.tap(find.text('Aruba'))` call — the enqueue observation would stay empty. Re-ran `flutter test integration_test/map_end_to_end_test.dart` → FAILED on the `enqueueObservations, isNotEmpty` guard with reason "no enqueue observed at tap step — test would be inert". Restored the tap → green.

### Test 4: integration_test/phase_07_navigation_test.dart (NEW)
*Brand-new file. Covers router 5 new routes + back-navigation + deep-links for Phase 07 screens (/map + /maps-download + /maps-manage + /style-import + /style-export). Inertness guard: pre-assert GoRouter received push/go events AND screens emitted a build().*

- **File:** `integration_test/phase_07_navigation_test.dart`
- **Type:** permanent regression guard (integration test, `@Tags(['integration'])`)
- **Covers:** Phase 07 router 5 new routes (/map + /maps/download + /maps/manage + /styles/import + /styles/export) + back-nav sanity (canPop=false after go + `go('/')` fallback) + 2 deep-link scenarios
- **Commit hash:** `8103312` — `test(08-rev): add integration_test/phase_07_navigation_test.dart`
- **Verify command:** `flutter test integration_test/phase_07_navigation_test.dart`
- **Test run result:** PASS 2026-04-23 (8/8 testWidgets)
- **Inertness guards (quotes) — per-scenario home-rendered + active-location match:**
  ```dart
  // Home button rendered before navigation driven
  expect(find.text('push /map'), findsOneWidget, reason: 'home screen did not render /map push button — test inert');
  // Navigation landed on target (not home '/')
  expect(_activeLocation(router), equals('/map'), reason: 'router did not navigate to /map — test inert');
  // Deep-link: initialLocation propagated
  expect(_activeLocation(router), equals('/styles/import'), reason: 'router initialLocation did not stick — test inert');
  ```
- **Mutation experiment (author-time):** Replaced `router.go('/map')` with a no-op call in the forward tests → each FAILED loudly with the active-location inertness-guard reason "router did not navigate to /map — test inert". Restored → green. Navigation API choice (`router.go` rather than `router.push`) documented inline: go_router's `push` routes through RouteInformationProvider + platform channels that do not deterministically flush under the integration_test binding.

### Test 5: test/infrastructure/assets/world_bundle_sha256_test.dart (NEW permanent unit test)
*Recompute sha256 of `assets/maps/world.pmtiles` via `crypto sha256.bind` streaming + assert equal to `kWorldBundleSha256` constant. Inertness guard: file exists + size > 0. Protects against asset-change-without-constant-update silent drift.*

- **File:** `test/infrastructure/assets/world_bundle_sha256_test.dart`
- **Type:** permanent regression guard (pure-Dart unit test)
- **Covers:** `kWorldBundleSha256` drift detection — catches `assets/maps/world.pmtiles` regeneration without matching `tool/generate_world_sha256.dart` re-run (would otherwise loop FirstLaunchWorldCopier auto-heal on every launch)
- **Commit hash:** `b28e25d` — `test(08-rev): add 3 permanent unit tests — world-bundle-sha256 + manifest-atomicity + no-httpclient-scan` (shared with Tests #6 + #7)
- **Verify command:** `dart test test/infrastructure/assets/world_bundle_sha256_test.dart`
- **Test run result:** PASS 2026-04-23 (1/1 test, current sha `62782f3bbc16bc3d3d005299007374d3e281dcdc97e5282ec04c027e867f38d6`)
- **Inertness guard (quote):**
  ```dart
  expect(
    bundleFile.existsSync(),
    isTrue,
    reason: 'assets/maps/world.pmtiles missing — test inert. A refactor that renames the asset without updating this path would silently pass on an empty-stream sha256 comparison.',
  );
  expect(bundleFile.lengthSync(), greaterThan(0), reason: 'assets/maps/world.pmtiles is empty — test inert (empty-stream sha256 would be compared).');
  ```
- **Mutation experiment (author-time):** Temporarily set `kWorldBundleSha256` to a hex-digit-flipped wrong constant. Ran `dart test test/infrastructure/assets/world_bundle_sha256_test.dart` → FAILED loudly with the "world.pmtiles asset drifted from kWorldBundleSha256 constant" message. Reverted → green.

### Test 6: test/infrastructure/downloads/manifest_atomicity_contract_test.dart (NEW permanent unit test)
*Inject FS fake throwing at 4 points (before tempfile, during tempfile write, after tempfile write, during rename) + assert post-throw file state is either unchanged or totally updated. Inertness guard: fake FS received ≥ 1 write before throw. Complements the 6 soak scenarios with a narrow repo-level contract.*

- **File:** `test/infrastructure/downloads/manifest_atomicity_contract_test.dart`
- **Type:** permanent regression guard (pure-Dart unit test)
- **Covers:** `JsonFileInstalledManifestRepository` atomicity contract — 4 scenarios over real tempdir I/O (no FS-injection seam; design note inline): happy write / stale `.tmp` sibling tolerance / concurrent-write mutex serialization / broadcast-stream ordering
- **Commit hash:** `b28e25d` (shared permanent-unit-test commit)
- **Verify command:** `dart test test/infrastructure/downloads/manifest_atomicity_contract_test.dart`
- **Test run result:** PASS 2026-04-23 (4/4 tests)
- **Inertness guards (quotes):**
  ```dart
  // Scenario 1: clean tempdir precondition
  expect(File(canonicalPath).existsSync(), isFalse, reason: 'tempdir not clean — test inert');
  // Scenario 2: initial write actually landed
  expect(initialContents.isNotEmpty, isTrue, reason: 'initial write did not materialise — test inert (later .tmp-sibling check would not discriminate)');
  // Scenario 3: concurrent writes produced a file
  expect(File(canonicalPath).existsSync(), isTrue, reason: 'concurrent writes produced no canonical file — test inert');
  // Scenario 4: broadcast stream actually emitted
  expect(observed, isNotEmpty, reason: 'broadcast stream emitted no events — test inert');
  ```
- **Mutation experiment (author-time):** Locally replaced `await tmp.rename(_filename)` with `await tmp.copy(_filename)` (breaks atomicity: copy is non-atomic on Windows + leaves the `.tmp` hanging). Ran the suite → scenario 2 (stale `.tmp` tolerance) diverged on the `.tmp`-cleanup observation. Noted inline that this test is necessary but not sufficient — the soak scenarios cover end-to-end kill-mid-rename paths. Reverted → green.
- **Design note (documented inline):** The repo deliberately has no FS-injection seam per CLAUDE.md §Wrappers. The test exercises atomicity via real I/O + tempdir snapshots rather than a mock FS, which is both more faithful + less cargo-cult than a delegation-wrapper + FakeFileSystem interface.

### Test 7: test/infrastructure/network/no_httpclient_in_unit_tests_test.dart (NEW permanent unit test)
*Pure-Dart scan `test/` (exclude `integration_test/` + files with `@Tags(['integration'])`) for `HttpClient()` / `http.Client()` / `Dio()` patterns. Inertness guard: scan visited ≥ N files. Protects against unit tests silently acquiring real network.*

- **File:** `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart`
- **Type:** permanent regression guard (pure-Dart unit test, meta-scan)
- **Covers:** static-level network isolation — complements `integration_test/airplane_mode_test.dart` runtime-level isolation (a unit test that instantiates `HttpClient()` directly would sneak past the runtime HttpOverrides scope)
- **Commit hash:** `b28e25d` (shared permanent-unit-test commit)
- **Verify command:** `dart test test/infrastructure/network/no_httpclient_in_unit_tests_test.dart`
- **Test run result:** PASS 2026-04-23 (1/1 test; scan visited ~110 `.dart` files under `test/` with zero violations)
- **Inertness guard (quote):**
  ```dart
  expect(
    dartFiles.length,
    greaterThan(50),
    reason: 'test/ scan visited only ${dartFiles.length} Dart files — test inert. A refactor renaming or emptying test/ without updating this test would silently pass the "no violations" check on an empty set.',
  );
  ```
- **Mutation experiment (author-time):** Temporarily added `final _c = HttpClient();` to `test/infrastructure/db/app_database_test.dart`. Ran `dart test test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` → FAILED loudly listing the violating file + line. Removed the line → green.
- **Exclusions (documented inline):** files with `@Tags(['integration'])` or `@Tags(['soak'])` are skipped (integration tests legitimately spin up shelf servers; soak tests use `_RealHttpOverrides`). Lines containing `fake` / `Fake` (case-insensitive) + lines with `implements HttpClient` / `extends HttpClient` are treated as fake-class definitions, not instantiations.

### Test 8: tool/check_style_no_external_url.dart adversarial CI run (throwaway branch adversarial/08-style-external-url)
*Branch `adversarial/08-style-external-url`: poison commit injects `"url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"` into `assets/maps/style.json`. CI step `Check style no external URL` (added to `.github/workflows/ci.yml` `gates` job in Plan 08-04) MUST fail with exit 1 and stderr identifying the file path + JSON path + offending URL. Branch deleted local + remote post-archivage; main `on.push.branches` stays `[main]`-only.*

- **Type:** throwaway adversarial branch → real CI red
- **Branch:** `adversarial/08-style-external-url` (deleted local + remote post-archive)
- **Poison commit hash:** `5a4610d` — `poison(adversarial/08): inject https tile URL in style.json to exercise check_style_no_external_url` (injected `"tiles": ["https://tile.openstreetmap.org/{z}/{x}/{y}.pbf"]` into `sources.mirkfall_map`)
- **CI trigger expansion commit hash:** `06b19e5` — `ci(adversarial/08): expand on.push.branches to include adversarial/**` (inline expansion on THIS branch only; main's trigger stays `[main]`-only)
- **CI run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24855188920
- **CI run conclusion:** `failure` (gates job) — Build Android + iOS `skipped` (proper `needs: gates` dependency)
- **Failed step:** step #12 `Tool scripts unit tests` — fired before step #17 `Check style no external URL` because the paired test's scenario 1 runs against the REAL production style.json path (now poisoned on the branch) and expected exit 0, got exit 1. BOTH code paths proven in one run: (a) the scanner itself emits exit 1 with correct stderr, (b) the paired test catches the drift via the same library entry point. The scanner stderr was also printed in-log ahead of the test failure — double-coverage evidence.
- **Exit code:** 1 (policy violation, matches `runCheck()` contract)
- **Stderr excerpt (verbatim from CI log):**
  ```
  check_style_no_external_url: 1 external URL(s) detected in assets/maps/style.json:
    assets/maps/style.json: sources.mirkfall_map.tiles[0] = https://tile.openstreetmap.org/{z}/{x}/{y}.pbf

  Rule (MAP-05 / MAP-09): MirkFall renders offline-only. Any http[s]:// URL in
  the style would let MapLibre stream tiles from a hosted endpoint, breaking
  airplane-mode UX + the Phase 08 review-gate QUAL-05 contract. Use
  `pmtiles://file:///…`, `file:///…`, `asset:///…`, or relative asset paths.
  ```
- **Paired-test failure excerpt (verbatim from CI log):**
  ```
  ❌ tool/test/check_style_no_external_url_test.dart: check_style_no_external_url.runCheck scenario 1: clean production style.json (at its real path) → exit 0 (failed)
  Expected: <0>
    Actual: <1>
  ```
- **Deletion confirmed:**
  - `git branch --list 'adversarial/08-style-external-url'` → empty
  - `git ls-remote --heads origin 'adversarial/08-style-external-url'` → empty
  - main's `.github/workflows/ci.yml` still triggers on `[main]` only (`grep -c 'adversarial/\*\*' .github/workflows/ci.yml` → 0)
- **Gate behaviour proof:** CI correctly blocks external URL injection at policy layer. The violation is reported with actionable stderr (file path + JSON path + offending URL + rule reference + remediation guidance) — matching the Phase 06 `check_platform_manifests` adversarial evidence quality bar.
- **Production CI green on main post-archive:** commit `33f8692` — [CI run 24854744018](https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24854744018) — all 3 jobs (gates / android / ios) green.

### Tests 9-10: 2 new soak edge cases (appended to existing download_soak_test.dart)
*Test #9: corrupt chunk mid-stream (chunk #3 of 5 returns sha256-mismatch payload — assert staging cleaned, state=failed-with-retry, `.pmtiles` cible absent). Test #10: rename target already exists (simulate retry where cible `.pmtiles` already present — assert AtomicRenamer gère correctement per contract, zero manifest leak). Both `@Tags(['soak'])`. Covers SC#3 extension beyond the 6 existing scenarios.*

- **File:** `test/infrastructure/downloads/download_soak_test.dart` (appended 2 new groups after the existing 6)
- **Type:** permanent regression guards (`@Tags(['soak'])`, CI-gated before merge)
- **Covers:** SC#3 extension — 6 existing + 2 new = 8 soak scenarios
- **Commit hash:** `33f8692` — `test(08-rev): add 2 soak edge cases + dart format normalization` (also includes the CI-driven dart format re-normalization of the 6 prior files touched in Tasks 1-5)
- **Verify command:** `flutter test --tags soak test/infrastructure/downloads/download_soak_test.dart`
- **Test run result:** PASS 2026-04-23 (8/8 scenarios, ≈ 11 s wall-clock)

**Test #9 — corrupt_chunk_mid_stream:**

- **Behaviour proven:** 5-part download with chunk #3 returning sha256-mismatch payload → controller emits `DownloadError` whose `cause` references `sha256` (matches `Sha256MismatchException`). Final `countries/afg.pmtiles` is absent — no partial install. Staging PRESERVED per controller design (`pmtiles_download_controller.dart:378` "Keep staging intact for a future resume"). Manifest does NOT contain `afg`.
- **Design-reality alignment:** per-chunk sha256 is NOT verified before concat; the correctness gate is the reassembled sha256 at concat time (step 4 of the 7-step protocol). So the staging's reassembled `afg.pmtiles` MAY exist post-failure with mismatched bytes — rename (step 5) never runs, so this is not a partial install at the canonical-path level. Test scenario adapted to match this reality during author-time mutation (see below).
- **Inertness guard:** `servers[2].recordedRequests.isNotEmpty` — proves the corrupted chunk server was actually hit before the failure path triggered. Without it, a refactor that short-circuits before chunk 3 would leave the target-absent assertion trivially true.
- **Mutation experiment (author-time):** Replaced chunk #3's advertised sha256 with the ACTUAL served-payload sha (so the mismatch disappears). Ran the suite → scenario 9 FAILED with "state is DownloadCompleted, not DownloadError". Restored the corruption → green.

**Test #10 — rename_target_already_exists:**

- **Behaviour proven:** pre-seeded canonical `countries/vnm.pmtiles` with 512 stale bytes → retry downloads 8 KB new payload → AtomicRenamer overwrites cleanly (target bytes match new payload, NOT stale). Manifest has exactly ONE entry for `vnm` (no duplicate leak). Staging cleaned post-completion.
- **Inertness guards (two):** `staleSize > 0` + `staleSize != newPayload.length` — proves the pre-seed actually landed AND the post-overwrite equality assertion can genuinely discriminate overwrite-vs-kept-stale.
- **Mutation experiment (author-time):** Changed the pre-seeded payload size to match the new payload size. Ran scenario 10 → FAILED with "pre-seeded target size matches new payload — post-overwrite equality assertion cannot discriminate (test inert)" — confirming the discriminator guard catches the inertness. Restored distinct sizes → green.

**Cross-reference:** both scenarios documented in full at `test/infrastructure/downloads/download_soak_test.dart:374-526` (including mutation-experiment comments inline). Plan 08-04 spec acceptance: the plan called for "staging cleaned" on scenario 9, but Task 8 executor aligned the test with the actual `pmtiles_download_controller.dart:378` design invariant ("Keep staging intact for a future resume"); the spirit of the plan — "atomic install or absent, never partial at the canonical level" — is verified.

## 5. CI-green confirmation

*Filled by Plan 08-05 Task 3 after all Blocker + non-waived Should fixes are applied and CI is green.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending — all 3 jobs gates+android+ios green, optionally integration-tests)
- **Date:** (pending)

---
_Phase 08 closed: (pending)_
_Phase 09 unblocked._

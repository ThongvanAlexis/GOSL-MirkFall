# Project Research Summary

**Project:** MirkFall
**Domain:** Flutter mobile app - real-world fog-of-war map with background GPS, markers+photos, versioned JSON I/O, GOSL v1.0 license
**Researched:** 2026-04-17
**Confidence:** HIGH

## Executive Summary

MirkFall is a local-first Flutter app that lifts a fog-of-war overlay as the user physically moves through the world. The research confirms the product occupies a real gap in the market: the genre-defining competitor (Fog of World) has an undocumented proprietary data format that users had to reverse-engineer, lost Google Drive sync support due to a $9,000/year audit requirement, and has no marker or photo system at all. MirkFall positioning is durable data portability (versioned human-readable JSON), a full travel-journal layer (markers, photos, RPG icons), and a living atmospheric fog renderer - none of which exist together in any shipping alternative.

The recommended approach is a deliberate mainstream stack: flutter_map (BSD-3-Clause) for the map, geolocator (MIT) for background GPS via a standard Android foreground service and iOS Core Location background mode, Drift (MIT) for typed SQLite persistence, Riverpod 3 (MIT) for state management and DI, and Freezed (MIT) for immutable domain models. Every dependency has been license-audited; GPL-licensed flutter_map_tile_caching and the paid-license-key flutter_background_geolocation are explicitly rejected. The architecture is structured around five decoupling seams (MirkRenderer, TileSource, MarkerIconPack, SessionStateStore, LocationSource) that allow visual styles and offline tile providers to be swapped in V1.1 without touching application or presentation code.

The top risks are: (1) background GPS reliability - on Android this is a foreground-service + OEM battery-killer problem affecting 70% of the market; on iOS it requires precise-accuracy settings and allowsBackgroundLocationUpdates. Both must be validated in a POC in the first GPS phase before any downstream feature is built. (2) Data integrity - the revealed-tile bitmap model must be decided before the export schema is frozen; migration must be tested with fixture databases; every import must run inside a single transaction. (3) License hygiene - a CI transitive-license scan must be in place from day one, as a single GPL transitive dependency contaminates the entire GOSL project.

---

## Key Findings

### Recommended Stack

The stack is mainstream Flutter with permissive licenses throughout. flutter_map 8.3.0 (BSD-3-Clause) is the only serious map library that avoids commercial SDKs. geolocator 14.0.2 (MIT, Baseflow) combined with a platform-native Android foreground service and iOS UIBackgroundModes: location is the cleanest-license background-tracking path - the commonly recommended alternative (flutter_background_geolocation) requires a paid per-app license key for Android release builds, incompatible with a GitHub-distributed GOSL app. Drift 2.32.1 (MIT) over raw sqflite is mandated by CLAUDE.md strict-casts: true - Drift generates typed DAOs and validates SQL at build time. Riverpod 3.3.1 (MIT) doubles as the DI container, satisfying the CLAUDE.md no-global-singletons requirement while being the single project-wide state management system.

**Core technologies:**
- flutter_map 8.3.0 (BSD-3-Clause): map widget + pluggable tile/layer system - vendor-free, no telemetry, no commercial SDK
- geolocator 14.0.2 (MIT): GPS stream + Android foreground service - official Baseflow plugin, no license key required
- flutter_local_notifications 21.0.0 (BSD-3-Clause): persistent notification during tracking - required for Android FOREGROUND_SERVICE_LOCATION transparency
- flutter_riverpod 3.3.1 (MIT): single state management system + DI container - compile-time safe, no hidden globals
- drift 2.32.1 (MIT): typed SQLite for sessions, markers, revealed tiles - build-time SQL validation, explicit migrations
- freezed 3.2.5 (MIT): immutable domain models with sealed unions
- shared_preferences 2.5.5 (BSD-3-Clause): simple key-value for app options - official flutter.dev
- logging 1.3.0 (BSD-3-Clause): structured file logger - dart.dev, replaces print() per CLAUDE.md
- image_picker 1.2.1 (Apache-2.0 + BSD-3-Clause): native camera/gallery picker - flutter.dev
- share_plus 13.0.0 (BSD-3-Clause): OS share sheet for session export
- file_picker 11.0.2 (MIT): user-initiated JSON import

**V1.1 only (architecture ready in V1.0):**
- flutter_map_mbtiles 1.0.4 (MIT): offline tile provider reading user-supplied MBTiles files
- OSM tiles explicitly forbidden for bulk/offline download - V1.1 must use user-supplied MBTiles or a permissive provider

**Hard rejections:**
- flutter_map_tile_caching - GPL-3.0, forbidden by GOSL
- flutter_background_geolocation - requires paid per-app license key for Android release
- firebase_*, sentry_flutter, any analytics/crash SDK - forbidden by CLAUDE.md and GOSL v1.0

### Expected Features

**Must have (table stakes):**
- Real-time fog reveal around current GPS position - the core mechanic
- Background GPS tracking with persistent notification
- Persistent local storage across launches
- Session CRUD with start/stop exclusivity (one active at a time)
- Standard pan/zoom interactive map beneath the mirk
- Configurable reveal radius
- GPS permission flow with human-readable rationale strings

**Should have (differentiators):**
- Versioned human-readable JSON export/import - number one market differentiator; Fog of World format had to be reverse-engineered by the community
- Full marker system: position, title, notes, photo gallery, RPG-style category icons - Fog of World has no markers at all
- Atmospheric/animated mirk rendering - competitors ship static grey/black overlays
- Importable mirk style JSON files
- Import markers-only JSON (pre-seed a trip before you go - unique in the market)
- Export all sessions as a ZIP archive with bundled photos
- Local-first, no account, no server, zero telemetry - enforced by GOSL

**Anti-features (deliberately rejected):**
- Cloud sync - would recreate the dependency that burned Fog of World ($9k/year Google audit)
- Badges/levels/gamification - the level 296 to 240 after update Fog of World incident is the cautionary tale
- Analytics, crash reporting, ads, subscriptions - forbidden by GOSL v1.0
- Proprietary binary mirk format - Fog of World did this; MirkFall publishes the schema

**Defer to V1.1:**
- Offline tile download UI (TileSource abstraction present in V1.0)
- Simple exploration stats
- Per-session mirk style override
- GPX import

### Architecture Approach

MirkFall uses a four-layer clean architecture (Presentation, Application, Domain, Infrastructure) enforced by import rules: lib/domain must never import Flutter, Drift, geolocator, or flutter_map. Five interface seams carry extensibility. The revealed-area data model is the most consequential design decision: instead of storing raw GPS fixes (gigabytes), the app stores a hierarchical sparse bitmap - slippy XYZ parent tiles at zoom 14 each holding a 64x64 packed bit grid representing roughly 38m x 28m cells. This stays under 10 KB/year for a typical local user and under 1 MB/year for a road-tripper, well inside the 100 MB/year ceiling from PROJECT.md. The session state machine enforces at-most-one-active via a partial unique DB index, not caller discipline. The fog layer is a RepaintBoundary-wrapped CustomPaint that subscribes directly to the renderer Listenable, avoiding 60 fps widget-tree rebuilds.

**Major components:**
1. MirkRenderer interface - fog paint strategy; swap to shader style in V1.x without touching any other code
2. TileSource interface - map tile origin; V1.0 online OSM, V1.1 MBTiles offline
3. SessionStateStore interface (Drift impl) - single source of truth, enforces exclusivity at DB level
4. RevealedTileStore interface (Drift impl) - 64x64 bitmap-per-parent-tile, idempotent INSERT OR IGNORE from GPS fixes
5. LocationSource interface (geolocator impl) - GPS stream + foreground service lifecycle, isolated from app
6. ActiveSessionController (Riverpod AsyncNotifier) - wires LocationSource to RevealCalculator to RevealedTileStore to ForegroundService
7. ImportExportController (Riverpod AsyncNotifier) - all-or-nothing transactional import, pre-export integrity check, post-export round-trip verification
8. MarkerIconPack interface - bundled RPG icon set V1.0; importable packs V1.x
9. RevealCalculator (pure Dart) - converts (position, radius) to the set of sub-tile cells to reveal; no I/O
10. JsonMigrator (pure Dart) - envelope version chain migration; built on day 1, not V1.1

### Critical Pitfalls

1. **OEM battery killers silently stop tracking** - affects ~70% of Android market (Xiaomi, Huawei, Samsung, OnePlus). Foreground service and notification is necessary but not sufficient. Must also request REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, detect OEM via Build.MANUFACTURER, deep-link to manufacturer-specific settings, and surface a tracking-interrupted banner on next launch.

2. **GPS fix storage blowing up to gigabytes** - explicitly called out in PROJECT.md. Prevention is the architectural decision itself: no gps_fixes table, only revealed_tiles with the 64x64 bitmap model. Must be decided before the persistence schema is written.

3. **Catastrophic data loss on schema migration** - the Fog of World level 296 to 240 incident is the exact differentiator MirkFall promises to avoid. Prevention: Drift fixture-based migration tests from every prior schema version, DB backup before every migration, sanity row-count check after migration, never catch migration failure silently.

4. **SQLite corruption from process kill during write** - WAL mode, synchronous=NORMAL, busy_timeout=5000 on DB open. Small bounded write transactions per GPS fix. Single-writer invariant enforced in the tracking service.

5. **Partial JSON import leaving DB in inconsistent state** - entire import inside a single Drift transaction. Full validation pass before any DB write. Photo extraction to staging dir, atomic rename after transaction commit.

6. **OSM tile ban from missing User-Agent** - set MirkFall/{version} in constants. Never bulk-prefetch tiles. Show attribution. A ban produces grey squares with no obvious error.

7. **GPL transitive dependency contaminating GOSL** - CI license scan on every PR, pin all versions, commit pubspec.lock. flutter_map_tile_caching is the known GPL offender already excluded.

---

## Implications for Roadmap

The dependency DAG from FEATURES.md is clear: persistence and domain models first (nothing runs without them), background GPS second (the project number one risk), map integration third, fog rendering fourth, markers fifth, import/export last. There is no pure UI phase decoupled from service work - each phase delivers both the service and its UI.

### Phase 1: Foundation
**Rationale:** License headers, analyzer config, logging, DI bootstrap, and CI must exist before any feature code is written. GPL transitive dep contamination, telemetry via dep update, and missing license headers compound invisibly if deferred.
**Delivers:** Flutter project skeleton with strict analysis, GOSL license headers in all files, Riverpod ProviderScope, file logging, runZonedGuarded error handler, CI pipeline (Android + iOS unsigned), DEPENDENCIES.md stub, pre-commit license-header check.
**Avoids:** GPL transitive contamination (9), telemetry via dep update (10), missing license headers (11), use_build_context_synchronously lint (21).
**Research flag:** Standard patterns. No research phase needed.

### Phase 2: Persistence and Domain Models
**Rationale:** The revealed-tile bitmap model and the versioned JSON envelope schema must be committed to before any GPS or export code is written. Changing either retroactively forces rewrites across multiple downstream phases.
**Delivers:** Drift AppDatabase with sessions, markers, categories, revealed_tiles (64x64 bitmap), and mirk_styles tables; all Freezed domain models; all Store ports and Drift implementations; JsonMigrator framework (identity migration for v1); RevealCalculator and TileMath pure-Dart utilities; DB-level at-most-one-active-session partial unique index; WAL mode DB setup; pre-migration DB backup logic; Drift schema snapshot fixtures.
**Avoids:** Data loss on migration (3), SQLite corruption (4), orphaned photos - relative path storage established here (5), GPS point explosion - bitmap model established here (6).
**Research flag:** Standard patterns. No research phase needed.

### Phase 3: GPS and Session Lifecycle
**Rationale:** This is the number one project risk. If background GPS does not work reliably, the entire product premise is invalid. PROJECT.md explicitly flags this as a POC to validate early. Must be proven before any map or fog code is built on top of it.
**Delivers:** LocationSource port and GeolocatorLocationSource; Android foreground service with FOREGROUND_SERVICE_LOCATION; iOS UIBackgroundModes location with correct settings (allowsBackgroundLocationUpdates, pauseLocationUpdatesAutomatically false, accuracy best); staged permission flow (WhenInUse first, AlwaysAllow on first background event, not on startup); OEM detection and REQUEST_IGNORE_BATTERY_OPTIMIZATIONS opt-in; distanceFilter tuned to reveal radius; stationary-detection low-power mode; tracking-interrupted detection on launch; ActiveSessionController state machine; persistent notification; session CRUD UI.
**Avoids:** Play Store background location rejection (1), App Store Guideline 2.5.4 (2), OEM battery killing (7), permission UX before rationale (12), 1 Hz battery drain (13), iOS background suspension (14).
**Research flag:** Needs real-device POC on non-Pixel Android (Xiaomi or Huawei) and real iOS device (screen off, 30+ minutes) before building dependent features. OEM battery deep-links must be verified against dontkillmyapp.com at implementation time.

### Phase 4: Map Integration
**Rationale:** The map layer requires the session lifecycle from Phase 3. TileSource and FogOfWarLayer seams must be established here so the fog renderer (Phase 5) and offline tiles (V1.1) slot in without changes.
**Delivers:** flutter_map with OSM NetworkTileProvider; identifying User-Agent in constants; TileSource port and OnlineOsmTileSource; MapViewportController; tile-cache LRU cap (200 MB); OSM attribution on map and About screen; layer stack order established; FogOfWarLayer widget stub (RepaintBoundary and CustomPaint wired to provider, renderer not yet implemented); MapScreen layout.
**Avoids:** OSM UA ban and attribution violation (8), unbounded tile cache (24).
**Research flag:** Standard patterns. Confirm OSM policy compliance at integration time.

### Phase 5: Fog Rendering
**Rationale:** The MirkRenderer seam can only be fully built once both persistence (Phase 2) and map viewport (Phase 4) are in place. The atmospheric/animated default style is a differentiator - competitors ship static overlays.
**Delivers:** MirkRenderer interface and MirkRendererFactory; MirkPaintContext; CustomPainterMirkRenderer V1.0 default (atmospheric animated noise style); second built-in style variant; RevealedAreaController (GPS fix to RevealCalculator to in-memory bitmap union to Drift batch flush every 5s or 50 fixes to viewport-filtered SubTileIndex set for painter); viewport filtering (only parent tiles intersecting current viewport); zoom-level adaptive rendering; MirkStyleStore; app-global style selector; activeMirkRendererProvider; RepaintBoundary isolation verified in DevTools with 50k-tile fixture.
**Avoids:** Jank with 10k+ tiles (20) - viewport filtering and spatial index required here.
**Research flag:** Sub-tile grid size (64x64 vs 32x32) and batch-flush interval need profiling on real hardware with large fixture data before finalizing.

### Phase 6: Markers
**Rationale:** The icon/category system must be fully functional before the marker creation UI exposes it. Photo storage with relative paths must be established before the first export is written.
**Delivers:** MarkerIconPack interface; BundledDefaultIconPack (RPG PNG assets); MarkerCategory CRUD; default RPG categories pre-seeded; marker CRUD with photo support; image_picker with maxWidth 2048 and imageQuality 85; thumbnail generation at 256x256; EXIF stripping; relative-path photo storage; delete-file-first order on marker removal; startup orphan-reconciliation job; marker list screen; marker detail bottom sheet; markers visible at reduced alpha under mirk (composite trick in renderer).
**Avoids:** Orphaned photos and absolute paths (5), full-resolution photo storage bloat (25).
**Research flag:** EXIF stripping - image_picker does not strip EXIF natively; a lightweight stripping approach needs evaluation at Phase 6 start.

### Phase 7: Import / Export
**Rationale:** Import/export is the number one differentiator and must work perfectly. Requires stable models from all prior phases. The versioned JSON schema and migration framework seeded in Phase 2 are fully exercised here.
**Delivers:** Versioned export envelope (schemaVersion, type, payload); ZIP archive export (.mirkfall) with manifest.json and photos/ directory; share_plus share-sheet integration; pre-export integrity check; post-export round-trip dry-run verification; report.txt inside archive; single-session and all-sessions export; file_picker JSON import; all-or-nothing transactional import (full validation pass before any DB write); photo extraction to staging dir, atomic rename after transaction commit; schema-version dispatch; collision policy UI; import preview screen; import-undo backup (last 3); markers-only JSON import; mirk style JSON import; SCHEMA.md; JsonMigrator cross-version test matrix.
**Avoids:** Partial import inconsistency (16), version field theater (17), absolute photo paths on cross-device import (18), silent incomplete export (19), import silently overwrites (23).
**Research flag:** No research phase needed. SCHEMA.md and cross-version test matrix are not skippable.

### Phase 8: Options, Polish, and Release Preparation
**Rationale:** Options screen glues all settings together. About/Legal is required by GOSL and CLAUDE.md. Release preparation covers store-policy justification copy, sideload cert-expiry mitigation, and final CI polish.
**Delivers:** Options screen (reveal radius, active style, styles list, category manager, global import/export); About/Legal screen with GOSL v1.0 mention and link; session recovery flow for cert-expiry or OS-kill; OEM battery-setup help screen; Clear map cache button with size display; log rotation (max 2 MB per file, 14-day max age); debug menu; Info.plist final audit; Play Console Data Safety form language; CI final validation (both platforms green, license scan passing, zero analyzer warnings).
**Avoids:** Store-policy strings locked here (1, 2), sideload cert expiry recovery flow (15), unbounded log files (26).
**Research flag:** Google Play Data Safety form language should be reviewed against the April 15 2026 policy update text at submission time.

### Phase Ordering Rationale

- Persistence before GPS: the revealed-tile bitmap model is the most consequential design decision; locking it in Phase 2 prevents rewrites in Phase 5.
- GPS before map: background tracking is the number one project risk; validating it in Phase 3 gives maximum warning time before any map or fog code depends on it.
- Map before fog: the FogOfWarLayer sits inside flutter_map layer stack; viewport controller and layer-ordering conventions must exist before the renderer is wired.
- Markers before import/export: the export schema includes markers and photos; the relative-path photo model must be in production use before the export format is frozen.
- Import/export last among feature phases: requires stable models, stable photo layout, and the migration framework.
- No pure UI phase: each service phase delivers the minimum UI needed to exercise the service.

### Research Flags

Phases needing deeper research or real-device validation:
- **Phase 3 (GPS and Session):** POC on real non-Pixel Android and real iOS device with screen off for 30+ minutes required before building dependent features. OEM battery deep-links must be verified at implementation time.
- **Phase 5 (Fog Rendering):** sub-tile grid size and batch-flush interval need profiling with a 50k-tile fixture in DevTools.
- **Phase 8 (Release):** Play Store Data Safety form and App Store review notes written against current policy text at submission time.

Phases with well-established patterns (skip research phase):
- **Phase 1:** standard Flutter project setup, Riverpod bootstrap, file logging.
- **Phase 2:** Drift schema design, Freezed models.
- **Phase 4:** flutter_map with OSM tiles.
- **Phase 6:** flutter_map MarkerLayer, image_picker, SQLite CRUD.
- **Phase 7:** ZIP archive with share_plus and file_picker.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every dependency verified on pub.dev and GitHub source. License audit complete. One MEDIUM caveat: V1.1 offline tile provider ToS may change. |
| Features | HIGH | Multiple primary sources. Competitor feature matrix directly validated. Anti-features grounded in cited evidence (the $9k CASA incident documented in official Fog of World Medium post). |
| Architecture | HIGH | Layer structure, interface seams, and data model are principled decisions. MEDIUM on exact sub-tile resolution and batch-flush timing - both are tuning questions, not design questions. |
| Pitfalls | HIGH | Store policies verified against primary sources. OEM battery killing documented with named sources. SQLite WAL from Drift issue tracker. MEDIUM on exact OEM deep-link URLs - they change per firmware. |

**Overall confidence:** HIGH

### Gaps to Address

- **Photo embedding format:** ZIP archive recommended (JSON manifest + photos/ dir), validated by Polarsteps model. Must be finalized at Phase 7 start.
- **Default reveal radius:** spec says e.g. 50m; urban walking suggests 25-50m. Decide at Phase 5 start with a real-world test. Store in lib/config/constants.dart.
- **Markers-under-mirk alpha level:** 30% suggested in ARCHITECTURE.md for the composite-trick value. Test visually in Phase 5.
- **EXIF stripping on photos:** image_picker does not strip EXIF natively; a lightweight stripping step needs evaluation at Phase 6 start.
- **V1.1 offline tile source:** Stadia Maps 100MB cap and OpenFreeMap ToS need re-verification at V1.1 implementation time.

---

## Sources

### Primary (HIGH confidence)
- pub.dev/flutter_map 8.3.0 - BSD-3-Clause, vendor-free map, telemetry audit
- pub.dev/geolocator 14.0.2 - MIT, background location, foreground service
- pub.dev/drift 2.32.1 - MIT, WAL setup, migration framework
- pub.dev/flutter_riverpod 3.3.1 - MIT, mutations, DI container
- pub.dev/freezed 3.2.5 - MIT, sealed unions
- OSM Tile Usage Policy (operations.osmfoundation.org/policies/tiles/) - bulk download prohibition, UA requirement, attribution
- Google Play policy update 2026-04-15 - background location tightening
- Apple App Review Guidelines 2.5.4 - UIBackgroundModes location requirements
- Fog of World drops Google Drive (Medium, Ollix) - $9k CASA audit evidence
- CaviarChen/Fog-of-World-Data-Parser (GitHub) - proprietary format reverse-engineering evidence
- SideStore FAQ - 7-day cert expiry, 3-app device limit

### Secondary (MEDIUM confidence)
- Beyond Doze - ProAndroidDev March 2026 - OEM battery killing on 70% of Android market
- dontkillmyapp.com - OEM-specific battery deep-links
- Medium benchmarked Flutter background location plugins March 2026 - geolocator 10-14%/hr without distanceFilter
- Apple Developer Forums thread 726945 - iOS 16.4 background location suspension
- Drift issues 3031 and 2990 - WAL and corruption behavior
- Polarsteps data export help - JSON + separate photos model (validates ZIP approach)

### Tertiary (LOW confidence - validate at implementation time)
- Stadia Maps pricing - 100MB mobile cache free tier; confirm at V1.1 time
- OpenFreeMap ToS - ambiguous on offline caching; re-read before V1.1

---
*Research completed: 2026-04-17*
*Ready for roadmap: yes*

# Stack Research — MirkFall

**Domain:** Flutter mobile app (iOS + Android), fog-of-war map + background GPS + local JSON persistence
**Researched:** 2026-04-17
**Overall confidence:** HIGH (mainstream Flutter stack with well-maintained plugins), MEDIUM for background GPS on iOS background reliability (ecosystem-wide issue, not stack-specific), MEDIUM for offline tile provider (policy interpretation required)

---

## Executive Summary

MirkFall sits squarely in the "pure-Flutter, permissively-licensed, official-plugin-first" lane. The stack is boring on purpose:

- **Flutter 3.41.5 / Dart 3.11** — current stable, BSD-3-Clause.
- **flutter_map 8.3.0** (BSD-3-Clause) as the vendor-free, non-SDK map engine — the only serious map lib that doesn't pull in a commercial SDK and allows arbitrary tile providers.
- **geolocator 14.0.2 + flutter_local_notifications 21.0.0** (MIT / BSD-3-Clause) as the **primary** background-tracking strategy, combined with a platform-native foreground service on Android and standard Core Location background mode on iOS. This is the lowest-telemetry, cleanest-license path that works, and it matches CLAUDE.md's directive to "prefer official Flutter plugins."
- **Riverpod 3.3.1 + riverpod_generator 4.0.3** (MIT) as the single state management choice — compile-time safe, testable, no global singletons (maps 1:1 to CLAUDE.md's DI rules).
- **Drift 2.32.1** (MIT) over raw sqflite for structured data (sessions, markers, revealed-mirk tiles) — typed queries prevent schema drift and align with "no `dynamic` without comment" discipline.
- **Fog-of-war rendering** via a `CustomPainter` overlay on top of the `flutter_map` stack, driven by a `ChangeNotifier`/`Listenable` (not rebuilt via `build()`). This is the most portable, most documented approach; a pluggable `MirkRenderer` interface lets us swap in fragment-shader styles later without changing the map layer.
- **Tile provider** = OpenStreetMap's standard tiles for online-only V1.0 (strictly within usage policy: identifying User-Agent, ≥7-day cache, no bulk download) with an abstracted `TileSource` interface ready for **MBTiles via `flutter_map_mbtiles`** (MIT) in V1.1 for offline. **OSM does not allow bulk/offline downloading from tile.openstreetmap.org**, so the V1.1 offline download feature MUST switch to a source that permits it (Stadia Maps 100MB free mobile cache, or MBTiles shipped/downloaded from a legal redistribution source).

Three non-obvious choices deserve emphasis:

1. **`flutter_background_geolocation` is REJECTED** despite being the "standard" answer — it requires a paid per-app license key for Android release builds. Incompatible with a GitHub-distributed hobby app.
2. **`flutter_map_tile_caching` is REJECTED** — GPL-3.0. Forbidden by CLAUDE.md.
3. **`Tracelet` and `Locus` are DEFERRED** — both look promising (Apache 2.0 / MIT, real open-source alternatives) but are new (2025-2026), low star counts, and Tracelet explicitly uses Google Play Integrity (phone-home risk). Not production-proven enough to bet the project on. The `geolocator`-based path is sufficient for V1.0 scope (single user, single session, simple radius). Re-evaluate for V1.1 if battery/reliability becomes the blocker.

---

## Recommended Stack

### Core SDK

| Technology | Pinned Version | Purpose | Why Recommended |
|------------|----------------|---------|-----------------|
| Flutter | 3.41.5 | App framework | Current stable (Feb 2026), includes Dart 3.11. BSD-3-Clause. No telemetry from the framework itself in release builds. |
| Dart SDK | 3.11.x (ships with Flutter 3.41.5) | Language | Bundled with Flutter; pattern matching, sealed classes, records all needed for our domain modelling. |

**Confidence: HIGH** — verified against [Flutter release notes](https://docs.flutter.dev/release/release-notes).

### Flutter Dependencies (pubspec.yaml)

All versions below are **pinned (no caret)** per CLAUDE.md rules.

#### Map & Rendering

| Library | Pinned Version | License | Purpose | Confidence |
|---------|----------------|---------|---------|------------|
| `flutter_map` | `8.3.0` | BSD-3-Clause | Map widget with pluggable `TileProvider` + `Layer`s. "Vendor-free, 100% pure-Flutter." No proprietary SDK, no telemetry. | HIGH |
| `latlong2` | `0.9.1` | BSD-3-Clause | `LatLng` type used by flutter_map (transitive, but we'll reference it directly in our domain models). | HIGH |
| `flutter_map_mbtiles` | `1.0.4` | MIT | **V1.1 only.** Offline tile provider that reads MBTiles (SQLite container). Integrates with flutter_map via custom `TileProvider`. Compatible with flutter_map 6–9. | HIGH |

Telemetry audit: `flutter_map` makes HTTP requests only to the URL template *you* configure (i.e., the tile server). No automatic analytics, no phone-home. Source: [pub.dev/flutter_map](https://pub.dev/packages/flutter_map), [github.com/fleaflet/flutter_map](https://github.com/fleaflet/flutter_map).

#### Geolocation & Background Tracking

| Library | Pinned Version | License | Purpose | Confidence |
|---------|----------------|---------|---------|------------|
| `geolocator` | `14.0.2` | MIT | GPS position stream + foreground-service support on Android. Official Baseflow package, the de-facto standard. | HIGH |
| `permission_handler` | `12.0.1` | MIT | Cross-platform permission requests (location, camera, background location, notification). Also Baseflow. | HIGH |
| `flutter_local_notifications` | `21.0.0` | BSD-3-Clause | Persistent notification shown while a session is active (required for Android FOREGROUND_SERVICE_LOCATION rationale and a nice UX hint on iOS). Publisher: dexterx.dev. | HIGH |

Telemetry audit:
- `geolocator`: No automatic network calls. All network usage is what *you* do with the coordinates. MIT, actively maintained by Baseflow.
- `permission_handler`: Pure wrapper over native permission APIs, no telemetry.
- `flutter_local_notifications`: Pure wrapper over native OS notifications, no telemetry.

**Background GPS strategy explanation (the App Store / Play Store rationale):**

- **Android**: `geolocator` natively supports a foreground service. When a session is active, we start a foreground service with a persistent notification ("MirkFall is tracking your exploration"), request `ACCESS_FINE_LOCATION` + `ACCESS_BACKGROUND_LOCATION` + `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`. This is the **Google-recommended** pattern for continuous location tracking since Android 10 and is explicitly supported by Google Play review (the persistent notification is the mandatory transparency signal).
- **iOS**: standard `UIBackgroundModes: location` + `NSLocationAlwaysAndWhenInUseUsageDescription` with a clear "to reveal the map as you explore, even with screen off" justification. iOS automatically throttles apps that misuse background location; geolocator respects iOS CoreLocation's automatic pausing.

Review rationale that's defensible for both stores: **"User creates a 'session' that explicitly represents an exploration trip. Tracking only runs while a session is active. Stop button immediately terminates all location collection. No data leaves the device."** That matches GOSL principles and both store reviewers' expectations.

##### What we rejected and why

| Rejected | License / Issue | Why rejected |
|----------|-----------------|--------------|
| `flutter_background_geolocation` (transistorsoft) | Apache-2.0 SDK code, but **requires paid per-app license key for Android release builds** | Violates "no license server phone-home" + paid dependency unfit for a free hobby app distributed on GitHub. Verified at [github.com/transistorsoft/flutter_background_geolocation](https://github.com/transistorsoft/flutter_background_geolocation). |
| `tracelet` (ikolvi.com) | Apache 2.0 | Promising Apache-2.0 "clean-room" rewrite, but (a) explicitly uses Google Play Integrity API (device attestation → possible phone-home to Google servers), (b) very new (2026, 24 stars), not battle-tested. Re-evaluate V1.1 if geolocator proves insufficient. |
| `locus` (weorbis.com) | MIT | Same concerns: new package (2026), low star count, has HTTP auto-sync feature (opt-in, but risk of misconfiguration). No documented Google Play Integrity dependency, but native source needs deeper audit. Re-evaluate V1.1. |
| `background_locator_2` | MIT | Unverified publisher, last updated 3 years ago, unmaintained. |
| `location` (package) | MIT | Redundant with `geolocator`; `geolocator` has better maintenance and broader feature set. |

#### State Management

| Library | Pinned Version | License | Purpose | Confidence |
|---------|----------------|---------|---------|------------|
| `flutter_riverpod` | `3.3.1` | MIT | **Single project-wide state management system.** Compile-time safety, automatic disposal, testability via `ProviderContainer` overrides — matches CLAUDE.md's constructor-injection mandate. Publisher: dash-overflow.net (Remi Rousselet, same author as Provider and Freezed). | HIGH |
| `riverpod_annotation` | `3.0.3` | MIT | Annotations for code-generated providers. Minimal boilerplate. | HIGH |
| `riverpod_generator` | `4.0.3` | MIT | Generates provider declarations from annotations. Runs at build time, zero runtime cost. | HIGH |

**Why Riverpod over Bloc / Provider:**
- Riverpod 3.0 (Nov 2025) added mutations (well-suited to our "start session / import JSON / add marker" semantic), automatic retry, and offline persistence — all directly useful.
- `flutter_bloc 9.1.1` (MIT) is an equally valid alternative; rejected because (a) more boilerplate for a solo-dev project, (b) Riverpod's provider-as-DI container doubles as our DI framework, eliminating need for a second library like `get_it`.
- `provider 6.1.5+1` (MIT) is the predecessor; Riverpod 3 supersedes it in every way.

Document the choice in `lib/state/README.md` per CLAUDE.md's "a choisir en début de projet et à documenter."

##### State management alternatives considered

| Library | Version checked | License | Why not picked |
|---------|-----------------|---------|----------------|
| `flutter_bloc` | 9.1.1 | MIT | Equally valid; more ceremony per feature (Event/State/Bloc triples) for a solo app. |
| `provider` | 6.1.5+1 | MIT | Superseded by Riverpod by same author. |
| `get_it` + change notifiers | n/a | MIT | Hidden global singletons — directly violates CLAUDE.md's "pas de singletons globaux cachés." Rejected. |

#### Persistence

| Library | Pinned Version | License | Purpose | Confidence |
|---------|----------------|---------|---------|------------|
| `drift` | `2.32.1` | MIT | Typed SQLite wrapper for structured data: sessions, markers, categories, revealed-mirk tiles. Compile-time SQL validation — kills a whole class of runtime bugs. | HIGH |
| `drift_flutter` | `0.3.0` | MIT | Flutter integration helper (opens DB at correct platform path). | HIGH |
| `sqlite3_flutter_libs` | `0.5.29` | MIT | Bundles sqlite3 native libs (Drift runtime dep on Android/iOS). | HIGH |
| `shared_preferences` | `2.5.5` | BSD-3-Clause | Simple key-value (app options: revealRadiusMeters, activeMirkStyleId, etc.). Official flutter.dev plugin. | HIGH |
| `path_provider` | `2.1.5` | BSD-3-Clause | Platform-aware paths (DB location, logs dir, photos dir, import/export targets). Official flutter.dev plugin. | HIGH |
| `path` | `1.9.1` | BSD-3-Clause | `p.join()` cross-platform path manipulation, mandatory per CLAUDE.md. | HIGH |

Telemetry audit: All four official / dart.dev / flutter.dev packages. No network. No analytics.

**Why Drift over raw sqflite:**
- `sqflite 2.4.2` (BSD-2-Clause) is the lower-level alternative. Excellent package but untyped — queries return `Map<String, Object?>`, requiring manual casting. That directly conflicts with CLAUDE.md's strict type hints rule (`strict-casts: true`).
- Drift sits on top of sqflite / sqlite3, generates typed DAOs, validates SQL at build time, handles migrations explicitly. The extra build-runner step pays for itself inside of a week.

#### Media

| Library | Pinned Version | License | Purpose | Confidence |
|---------|----------------|---------|---------|------------|
| `image_picker` | `1.2.1` | Apache-2.0 + BSD-3-Clause | Pick photos from gallery OR capture from camera via native picker. Official flutter.dev plugin. | HIGH |

**Why NOT `camera`:**
`camera 0.12.0+1` (BSD-3-Clause, flutter.dev) is the lower-level live-preview camera API — we don't need a custom camera UI for V1.0. `image_picker` uses the native camera dialog (OS-provided UI) which is simpler, more accessible, and eliminates a large surface of iOS/Android camera permission edge cases. If V1.x demands a custom camera UX (e.g. for quick burst capture at a marker), swap in `camera` behind a small wrapper interface.

#### Serialization & Code Generation

| Library | Pinned Version | License | Purpose | Confidence |
|---------|----------------|---------|---------|------------|
| `freezed` | `3.2.5` | MIT | Immutable data classes with `copyWith`, equality, sealed-union support. Used for domain models (Session, Marker, MirkStyle). | HIGH |
| `freezed_annotation` | `3.1.0` | MIT | Annotations-only package for freezed. | HIGH |
| `json_serializable` | `6.13.1` | BSD-3-Clause | `fromJson` / `toJson` code generation. Publisher: Google. | HIGH |
| `json_annotation` | `4.9.0` | BSD-3-Clause | Annotations for json_serializable. | HIGH |
| `build_runner` | `2.13.1` | BSD-3-Clause | Dart build system that drives all code generators. Publisher: dart.dev tools. | HIGH |

**Why this set is the right serialization path for the "versioned JSON" core value:**
- Freezed gives immutable models with sealed classes → ideal for representing `ImportResult` as `Success | VersionMismatch | MalformedJson | PhotoMissing` and forcing exhaustive pattern matching.
- `json_serializable` handles the grunt-work of `fromJson`/`toJson`.
- Version field: we wrap all export roots with a `{ "schemaVersion": 1, "type": "session", "payload": {...} }` envelope. Manual `fromJson` on the envelope dispatches to a versioned migration chain (`V1 → V2 → current`). The envelope parsing is hand-written (5 lines of Dart), everything inside the payload is generated.
- Manual serialization was considered and rejected — too many structs (Session, Marker, MirkStyle, Category, RevealedTile, each with nested types) to do by hand without drift.

#### UX & Utility

| Library | Pinned Version | License | Purpose | Confidence |
|---------|----------------|---------|---------|------------|
| `file_picker` | `11.0.2` | MIT | User-initiated file picking for JSON import. | HIGH |
| `share_plus` | `13.0.0` | BSD-3-Clause | OS share sheet for exporting JSON to other apps / cloud drives / email. Publisher: fluttercommunity.dev. | HIGH |
| `logging` | `1.3.0` | BSD-3-Clause | Structured logging. Publisher: dart.dev. Per CLAUDE.md: use `logging` (or `dart:developer log`), not `print()`. | HIGH |
| `collection` | `1.19.1` | BSD-3-Clause | `ListEquality`, `IterableExtension.firstWhereOrNull`, etc. Dart-team maintained. | HIGH |

Telemetry audit: `file_picker` triggers a native file-picker dialog (no network). `share_plus` invokes the OS share sheet (no network by the plugin; what the target app does is that app's problem). `logging` is a pure formatter with sink handlers — logs go where *we* send them (our file sink, not anywhere else).

#### Dev Dependencies

| Library | Pinned Version | License | Purpose |
|---------|----------------|---------|---------|
| `flutter_test` | SDK | BSD-3-Clause | Widget + unit testing framework. |
| `flutter_lints` | `6.0.0` | BSD-3-Clause | Official Flutter-recommended analyzer rules. Baseline. |
| `very_good_analysis` | `10.2.0` | MIT | Stricter lint set (Very Good Ventures). Layer on top of flutter_lints to enforce `prefer_const_constructors`, `avoid_redundant_argument_values`, etc. Optional but recommended to cover CLAUDE.md's strict-mode requirements. |
| `build_runner` | `2.13.1` | BSD-3-Clause | See above (also a dev dep). |
| `freezed` | `3.2.5` | MIT | See above (also a dev dep). |
| `json_serializable` | `6.13.1` | BSD-3-Clause | See above (also a dev dep). |
| `riverpod_generator` | `4.0.3` | MIT | See above (also a dev dep). |
| `custom_lint` | `0.7.5` | MIT | Runtime for lints published as Dart packages (needed by riverpod_lint). |
| `riverpod_lint` | `3.3.1` | MIT | Riverpod-specific lints (catches common provider misuse at analyze-time). |

---

## Tile Provider Decision

This was the single most policy-sensitive research area.

### V1.0 — Online tiles only

**Use OpenStreetMap standard tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`) with a strict usage-policy-compliant client:**

- Custom `User-Agent`: `MirkFall/1.0 (+https://github.com/[user]/GOSL-MirkFall)` — mandatory, OSM blocks generic UAs.
- HTTP cache header respect + minimum 7-day client-side cache via flutter_map's built-in `NetworkTileProvider` (v8.2.0+ ships with OS-level caching) plus optionally `flutter_map_cache 2.1.0` (MIT) for more control if we find the built-in caching insufficient.
- **NO bulk pre-fetching** — we only load tiles the user is actively viewing.
- Visible attribution "© OpenStreetMap contributors" linked to https://www.openstreetmap.org/copyright on the map view and in the "About" screen.

Reference: [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).

**Confidence: HIGH** for compliance of this approach in V1.0.

### V1.1 — Offline tiles (prepared in V1.0 architecture, NOT implemented)

**Architectural rule for V1.0:** the map screen consumes a `TileSource` interface, with an `OnlineTileSource` implementation backed by `NetworkTileProvider`. V1.1 adds `MbtilesFileTileSource` backed by `flutter_map_mbtiles 1.0.4` (MIT) — zero map-screen changes required.

**Offline tile SOURCE options (what to use for the download feature in V1.1):**

| Option | License / Cost | Offline permitted? | Recommended? |
|--------|----------------|--------------------|--------------|
| OSM tile.openstreetmap.org bulk download | Free | **Explicitly prohibited** by policy | NO |
| Stadia Maps free tier | Free up to 200k credits/month | **100MB cached max per device** (free tier) | MAYBE — fine for a small "download my neighborhood" feature, too small for road-trip use case |
| MapTiler free tier | Free up to 100k req/month | Offline via OpenMapTiles MBTiles | MAYBE — requires user API key |
| MBTiles file the user produces themselves (MapTiler Engine, TileMill, planetiler) | Free | Fully offline | **YES — default V1.1 strategy** |
| Thunderforest Hobby Project plan | Free up to 150k req/month | **Offline caching NOT allowed on free tiers** | NO |
| OpenFreeMap | Free (donation-supported) | MBTiles downloadable from site | **YES — alternative V1.1 strategy** |

**V1.1 recommendation (for the roadmap, not V1.0):** import user-supplied MBTiles files via a file picker, plus a "download area" feature that streams from a provider whose ToS explicitly permits it (OpenFreeMap free MBTiles, or Stadia Maps within their 100MB cap). Do **not** offer bulk OSM tile downloads — that's against OSM policy and would get the app blocked.

**Confidence: MEDIUM** — Stadia Maps policies can change, and OpenFreeMap's ToS does not currently address offline caching explicitly (it addresses bulk automated collection negatively). A V1.1-specific research pass should confirm the chosen provider's current ToS at implementation time.

---

## Fog-of-War Rendering Decision

### Chosen approach: `CustomPainter` overlay via a `FogOfWarLayer` that plugs into flutter_map

**Architecture:**

```
flutter_map.FlutterMap(
  layers: [
    TileLayer(tileSource: ...),          // base OSM tiles
    MarkerLayer(markers: ...),           // markers (visible under mirk per spec)
    FogOfWarLayer(                       // OUR layer, repaints on notifier
      revealedTiles: revealedTilesSet,
      currentPosition: currentLatLng,
      renderer: activeMirkRenderer,      // <-- the decoupling seam
    ),
  ],
)

abstract interface class MirkRenderer {
  void paint(Canvas canvas, Size size, MirkPaintContext context);
  void update(Duration dt);              // for animated styles
  void dispose();
}

class CustomPainterMirkRenderer implements MirkRenderer { ... }   // V1.0 default
class ShaderMirkRenderer implements MirkRenderer { ... }          // V1.x candidate
```

- `FogOfWarLayer` is an `AnimatedWidget` or `CustomPaint` child that listens to the current renderer's `Listenable` (not to the widget tree) — so the map doesn't rebuild every 16ms.
- The revealed area is stored as a sparse grid of unioned tiles (see "mirk representation" discussion in PITFALLS) — at zoom 15, a 50 m radius reveals ~4–9 tiles per GPS fix, and the set deduplicates aggressively. One bitmask or one `Set<(int,int)>` per session.

**Why not other approaches:**

| Approach | Why not |
|----------|---------|
| `Flame` (game engine) on top of map | Overkill; brings a full game loop we don't need; ecosystem mismatch with flutter_map. |
| `flutter_shaders` + fragment program from V1.0 | Premature; Impeller is mature but shader authoring is a sharper skill to require on day one. The MirkRenderer abstraction lets us add shader styles in V1.x without tearing up the architecture. |
| `CustomClipper` to punch holes in a black overlay | Works for simple cases but painting is more flexible (animated noise, radial gradient edges, multiple layers). We paint with `BlendMode` and a noise texture instead of clipping. |
| Adapt the `quentinchaignaud/fog-of-war` GitHub library | **GPL-3.0 licensed** — forbidden by CLAUDE.md. We can read it for inspiration only (ideas are not copyrightable, code is). |

**Decoupling requirement (from CLAUDE.md + PROJECT.md):** the `MirkRenderer` interface is the single seam. The map layer, the revealed-tiles domain model, and the persistence layer never import any specific renderer. New mirk styles are pure-additive modules.

**Confidence: HIGH** on the architecture, MEDIUM on performance at very large revealed areas (10k+ tiles) — mitigated by storing tile-index sets (not raw polygons) and only rendering tiles intersecting the current viewport.

---

## Logging

| Choice | Why |
|--------|-----|
| `logging 1.3.0` package (BSD-3-Clause, dart.dev) | Structured logger levels, hierarchical loggers, pluggable handlers. |
| `dart:developer` `log()` | Used internally by the file-sink handler to forward to DevTools when debugging. |

**Setup:** a single `LogBootstrap` service (injected via Riverpod) attaches two handlers to the root logger — a console handler (DevTools / Logcat / Xcode console) and a file handler writing to `<applicationDocumentsDirectory>/logs/yyyymmdd_hhmm.ss_logs.txt` per CLAUDE.md.

Build-time `--dart-define=DEBUG=true` toggles the minimum log level (`Level.FINE` vs `Level.WARNING`). Runtime override available through a debug-menu toggle stored in SharedPreferences for test iOS builds where we can't easily rebuild.

**Do NOT use `print()`** anywhere — enforce via a custom lint or at minimum a `flutter analyze` rule (`avoid_print` in very_good_analysis).

---

## Installation (`pubspec.yaml` draft)

```yaml
name: mirkfall
description: Fog-of-war world map for real-life exploration.
publish_to: none
version: 1.0.0+1

environment:
  sdk: "3.11.0"
  flutter: "3.41.5"

dependencies:
  flutter:
    sdk: flutter

  # Map
  flutter_map: 8.3.0
  latlong2: 0.9.1

  # Geolocation
  geolocator: 14.0.2
  permission_handler: 12.0.1
  flutter_local_notifications: 21.0.0

  # State management
  flutter_riverpod: 3.3.1
  riverpod_annotation: 3.0.3

  # Persistence
  drift: 2.32.1
  drift_flutter: 0.3.0
  sqlite3_flutter_libs: 0.5.29
  shared_preferences: 2.5.5
  path_provider: 2.1.5
  path: 1.9.1

  # Media
  image_picker: 1.2.1

  # Serialization
  freezed_annotation: 3.1.0
  json_annotation: 4.9.0

  # UX
  file_picker: 11.0.2
  share_plus: 13.0.0

  # Utility
  logging: 1.3.0
  collection: 1.19.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 6.0.0
  very_good_analysis: 10.2.0
  build_runner: 2.13.1
  freezed: 3.2.5
  json_serializable: 6.13.1
  riverpod_generator: 4.0.3
  custom_lint: 0.7.5
  riverpod_lint: 3.3.1
```

**Note:** Versions MUST stay pinned (no caret). `pubspec.lock` committed. Run `flutter pub outdated` on a schedule (quarterly) and audit each bump.

---

## Licenses Summary

Every direct dependency above has been verified on pub.dev:

| License | Count | Compatible with GOSL v1.0? |
|---------|-------|---------------------------|
| BSD-3-Clause | 11 | YES |
| MIT | 13 | YES |
| Apache-2.0 (image_picker dual) | 1 | YES |
| BSD-2-Clause (sqflite transitive) | 1 | YES |
| GPL / AGPL / LGPL | **0** | — (none accepted) |

Transitive dependency audit is mandatory before first commit using `flutter pub deps` and a license checker (`dart pub deps --json | jq '.packages[].kind'` + manual cross-check of any flagged package). The `DEPENDENCIES.md` file at the repo root gets one row per direct dependency with: version, license, telemetry audit summary, add-date.

---

## Alternatives Considered (Summary)

| Recommended | Alternative considered | When alternative might be better |
|-------------|------------------------|----------------------------------|
| `flutter_map` | `google_maps_flutter` | Never for MirkFall (commercial SDK + terms + telemetry concerns + forbids offline bulk). |
| `flutter_map` | `mapbox_maps_flutter` | Never for MirkFall (requires account + token + not MIT-compatible SDK terms). |
| `geolocator` (with foreground service) | `flutter_background_geolocation` | If we had budget for a per-app license AND needed sophisticated activity-recognition / geofencing. Not our case. |
| `geolocator` + Flutter FG service | `tracelet` (Apache 2.0) | Re-evaluate in V1.1 if battery life or background reliability becomes a proven blocker. |
| `flutter_riverpod` | `flutter_bloc` | Large-team projects with strict CQRS-event discipline. Overkill for solo dev. |
| `drift` | `sqflite` (raw) | If build_runner overhead becomes painful on CI. Unlikely. |
| `image_picker` | `camera` | If we need a custom camera UI (burst mode, in-app preview with markers). V1.x maybe. |
| MBTiles offline strategy | FMTC bulk download | Never — GPL-3.0, forbidden. |

---

## What NOT to Use

| Avoid | License / Problem | Use Instead |
|-------|-------------------|-------------|
| `flutter_background_geolocation` | Paid license key required for Android release (phone-home activation check) | `geolocator` + foreground service |
| `flutter_map_tile_caching` (FMTC) | GPL-3.0 | `flutter_map_mbtiles` (MIT) + `flutter_map_cache` (MIT) |
| `firebase_*` (any firebase package) | Google telemetry by design | Nothing — not needed |
| `sentry_flutter` / any auto crash reporter | Telemetry to external server | Write crashes locally via `runZonedGuarded` → log file |
| `google_maps_flutter` | Requires Google Cloud API key + commercial terms | `flutter_map` |
| `mapbox_maps_flutter` | Commercial SDK + account required | `flutter_map` |
| `get_it` | Global-singleton pattern violates CLAUDE.md DI rules | Riverpod providers (double as DI container) |
| `print()` | Forbidden by CLAUDE.md | `logging` package |
| `dio` (as default HTTP client) | Overkill for this app (no HTTP API) | stdlib `dart:io` only if strictly necessary |

---

## Version Compatibility

| Package A | Package B | Notes |
|-----------|-----------|-------|
| `flutter_map 8.3.0` | `flutter 3.41.5` | Requires Flutter ≥ 3.27. OK. |
| `flutter_map 8.3.0` | `flutter_map_mbtiles 1.0.4` | mbtiles compat range is `>=6.0.0 <9.0.0` → OK. |
| `flutter_riverpod 3.3.1` | `riverpod_generator 4.0.3` | Version aligned (3.x riverpod ↔ 4.x generator) per Riverpod 3.0 release notes. |
| `drift 2.32.1` | `sqlite3_flutter_libs 0.5.29` | Standard combo, matches Drift's own example. |
| `freezed 3.2.5` | `freezed_annotation 3.1.0` | 3.x family. |
| `freezed 3.2.5` | `json_serializable 6.13.1` | Works with Freezed's `@JsonSerializable` annotation support. |
| `build_runner 2.13.1` | `freezed` + `json_serializable` + `riverpod_generator` | Single `build.yaml` orchestrates all three. Run order doesn't matter. |
| `geolocator 14.0.2` | Android SDK | Requires `compileSdkVersion 35` (Android 15) for `FOREGROUND_SERVICE_LOCATION`. |
| `geolocator 14.0.2` | iOS | Requires iOS 12+. |

---

## Telemetry Audit Summary

Every direct dependency listed above was checked for:
1. Automatic network calls in the package's documented behavior
2. Analytics / crash reporting / attribution SDKs listed as dependencies
3. Known phone-home behavior reported in issues

**Finding: none of the recommended packages perform any telemetry.** The only network I/O is explicit:
- `flutter_map` → the tile URL *we* configure
- `geolocator` → no network
- `image_picker` / `file_picker` / `share_plus` → OS-level UI, no network
- Serialization / persistence / state / logging → purely local

**Risk areas requiring source-level verification at add-time** (as mandated by CLAUDE.md):
- Transitive deps of `flutter_map` (`dio` pulls in nothing suspicious per current pub.dev, but check via `flutter pub deps`).
- `permission_handler` and `flutter_local_notifications` native-code folders — quick grep of Kotlin / Swift for any HTTP client imports.
- Verify `sqlite3_flutter_libs` doesn't include any analytics (it's a build-artefact bundler; should be clean).

These checks produce the audit rows in `DEPENDENCIES.md`.

---

## Sources

**Primary (HIGH confidence — official package pages):**
- [pub.dev/flutter_map 8.3.0](https://pub.dev/packages/flutter_map) — BSD-3-Clause, vendor-free map
- [pub.dev/geolocator 14.0.2](https://pub.dev/packages/geolocator) — MIT, Baseflow, background location support
- [pub.dev/permission_handler 12.0.1](https://pub.dev/packages/permission_handler) — MIT, Baseflow
- [pub.dev/flutter_local_notifications 21.0.0](https://pub.dev/packages/flutter_local_notifications) — BSD-3-Clause, dexterx.dev
- [pub.dev/flutter_riverpod 3.3.1](https://pub.dev/packages/flutter_riverpod) — MIT, dash-overflow.net
- [pub.dev/riverpod_generator 4.0.3](https://pub.dev/packages/riverpod_generator) — MIT
- [pub.dev/drift 2.32.1](https://pub.dev/packages/drift) — MIT, simonbinder.eu
- [pub.dev/drift_flutter 0.3.0](https://pub.dev/packages/drift_flutter) — MIT
- [pub.dev/sqflite 2.4.2](https://pub.dev/packages/sqflite) — BSD-2-Clause (documented as alternative, not picked)
- [pub.dev/path_provider 2.1.5](https://pub.dev/packages/path_provider) — BSD-3-Clause, flutter.dev
- [pub.dev/shared_preferences 2.5.5](https://pub.dev/packages/shared_preferences) — BSD-3-Clause, flutter.dev
- [pub.dev/path 1.9.1](https://pub.dev/packages/path) — BSD-3-Clause, dart.dev
- [pub.dev/image_picker 1.2.1](https://pub.dev/packages/image_picker) — Apache-2.0 + BSD-3-Clause, flutter.dev
- [pub.dev/camera 0.12.0+1](https://pub.dev/packages/camera) — BSD-3-Clause, flutter.dev (documented as alternative)
- [pub.dev/freezed 3.2.5](https://pub.dev/packages/freezed) — MIT
- [pub.dev/json_serializable 6.13.1](https://pub.dev/packages/json_serializable) — BSD-3-Clause, google.dev
- [pub.dev/build_runner 2.13.1](https://pub.dev/packages/build_runner) — BSD-3-Clause, tools.dart.dev
- [pub.dev/logging 1.3.0](https://pub.dev/packages/logging) — BSD-3-Clause, dart.dev
- [pub.dev/flutter_lints 6.0.0](https://pub.dev/packages/flutter_lints) — BSD-3-Clause, flutter.dev
- [pub.dev/very_good_analysis 10.2.0](https://pub.dev/packages/very_good_analysis) — MIT
- [pub.dev/file_picker 11.0.2](https://pub.dev/packages/file_picker) — MIT
- [pub.dev/share_plus 13.0.0](https://pub.dev/packages/share_plus) — BSD-3-Clause, fluttercommunity.dev
- [pub.dev/flutter_map_mbtiles 1.0.4](https://pub.dev/packages/flutter_map_mbtiles) — MIT
- [pub.dev/flutter_map_cache 2.1.0](https://pub.dev/packages/flutter_map_cache) — MIT

**Rejected packages (documented for the record):**
- [pub.dev/flutter_background_geolocation 5.1.1](https://pub.dev/packages/flutter_background_geolocation) — Apache 2.0 source but paid license key required
- [pub.dev/flutter_map_tile_caching 10.1.1](https://pub.dev/packages/flutter_map_tile_caching) — GPL-3.0 (forbidden)
- [pub.dev/tracelet 1.8.11](https://pub.dev/packages/tracelet) — Apache 2.0, deferred for V1.1 evaluation
- [pub.dev/locus 2.2.2](https://pub.dev/packages/locus) — MIT, deferred for V1.1 evaluation
- [pub.dev/background_locator_2 2.0.6](https://pub.dev/packages/background_locator_2) — MIT, unmaintained

**Policy / ToS (MEDIUM confidence on interpretations):**
- [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) — bulk offline download not permitted
- [flutter_map offline mapping docs](https://docs.fleaflet.dev/tile-servers/offline-mapping) — official supported approaches
- [Stadia Maps pricing / limits](https://stadiamaps.com/pricing/) — 100MB mobile cache on free tier
- [OpenFreeMap](https://openfreemap.org/) / [OpenFreeMap ToS](https://openfreemap.org/tos/) — free donation-supported, ToS ambiguous on offline
- [MapTiler free tier](https://www.maptiler.com/cloud/pricing/) — 100k req/month, MBTiles offline via OpenMapTiles

**Flutter platform:**
- [Flutter 3.41 release notes](https://blog.flutter.dev/whats-new-in-flutter-3-41-302ec140e632) — stable Feb 2026, Dart 3.11

**Other context:**
- [GitHub fleaflet/flutter_map](https://github.com/fleaflet/flutter_map) — source & license verification
- [GitHub transistorsoft/flutter_background_geolocation](https://github.com/transistorsoft/flutter_background_geolocation) — license key requirement verification
- [GitHub weorbis/locus](https://github.com/weorbis/locus) — MIT verification
- [GitHub iKolvi/tracelet](https://github.com/iKolvi/tracelet) — Apache 2.0 verification, Google Play Integrity flagged

---

*Stack research for: MirkFall — Flutter fog-of-war map app*
*Researched: 2026-04-17*

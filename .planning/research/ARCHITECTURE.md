# Architecture Research — MirkFall

**Domain:** Flutter mobile fog-of-war map app (iOS + Android), local-first, versioned JSON I/O
**Researched:** 2026-04-17
**Confidence:** HIGH on layering, data model, renderer abstraction, tile integration, session lifecycle. MEDIUM on background-GPS buffering semantics (policy/OS behavior varies). MEDIUM on exact sub-tile bitmap resolution (tuning question, not design question).

---

## Executive Summary

MirkFall is a local-first, CustomPainter-driven, Riverpod-DI'd Flutter app sitting on top of `flutter_map`. Five seams carry the project's stability:

1. **`MirkRenderer`** — the fog paint strategy (swap CustomPainter style, shader style, static style).
2. **`TileSource`** — the map tile origin (V1.0: online OSM; V1.1: MBTiles offline).
3. **`MarkerIconPack`** — the marker icon catalog (V1.0: bundled default RPG; later: imported packs).
4. **`SessionStateStore`** — the repository that owns persistent session + revealed-area state.
5. **`LocationSource`** — the GPS stream wrapper (decouples app from `geolocator`).

Every other module consumes these seams by interface. No screen, no provider, no widget imports the concrete implementation directly.

The **revealed area data model** is the single most important design decision. Raw GPS points do not scale (back-of-envelope: 1 fix every 5 s over 2 km/day × 365 = ~150k points/year per session, many redundant). Instead, MirkFall stores a **hierarchical sparse bitmap**: zoom-14 parent tiles as storage keys, each holding a 64×64 bit sub-tile grid representing ~9m × 9m reveal cells. This gives sub-50m reveal granularity while staying under **~50 KB per year** of dense local use and under **~1 MB** for a user who explores aggressively across multiple cities. The quality-gate target of <100 MB/year is met by a factor of 100.

The phase build order threads the dependency DAG: persistence and models first (nothing runs without them), then GPS + session lifecycle (proves the background story), then map integration (needs lifecycle to observe), then fog rendering (needs map), then markers, then import/export (needs stable models), then polish/styles. UI-level features appear alongside their backing service; there is no "UI phase" decoupled from service work.

---

## Layer Architecture

### Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Presentation (UI)                             │
│                    lib/features/*/presentation/                      │
├──────────────────────────────────────────────────────────────────────┤
│  ┌───────────┐ ┌──────────┐ ┌─────────┐ ┌────────┐ ┌──────────┐     │
│  │ MapScreen │ │Sessions  │ │Marker   │ │Options │ │About/    │     │
│  │  (layers) │ │List/Edit │ │Edit/View│ │Screen  │ │ LegalScrn│     │
│  └─────┬─────┘ └────┬─────┘ └────┬────┘ └───┬────┘ └──────────┘     │
│        │            │            │           │                       │
│   Widgets only consume providers (watch/read). No direct service.    │
├────────┼────────────┼────────────┼───────────┼──────────────────────┤
│                  Application (Riverpod providers)                    │
│                     lib/features/*/application/                      │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐ ┌─────────────────┐ ┌────────────────────┐    │
│  │ SessionControlle │ │MarkerController │ │MirkStyleController │    │
│  │ (AsyncNotifier)  │ │(AsyncNotifier)  │ │(Notifier)          │    │
│  └────────┬─────────┘ └────────┬────────┘ └─────────┬──────────┘    │
│           │                    │                    │                │
│  ┌────────┴─────────┐ ┌────────┴────────┐ ┌─────────┴──────────┐    │
│  │RevealedAreaCtrl  │ │ImportExport     │ │OptionsController   │    │
│  │(tile union +     │ │Controller       │ │(Notifier)          │    │
│  │ viewport filter) │ │(AsyncMutation)  │ │                    │    │
│  └────────┬─────────┘ └────────┬────────┘ └─────────┬──────────┘    │
│           │                    │                    │                │
│  Providers compose domain services + repositories. No I/O inline.   │
├───────────┼────────────────────┼─────────────────────┼──────────────┤
│                    Domain (pure Dart, no Flutter)                    │
│                         lib/domain/                                  │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────┐ ┌──────────────┐ │
│  │ Models       │ │ Services     │ │ Abstractions│ │ Pure Logic   │ │
│  │ (Freezed)    │ │ (use cases)  │ │ (interfaces)│ │ (tile math,  │ │
│  │ Session,     │ │ RevealTile   │ │ MirkRenderer│ │  radius calc,│ │
│  │ Marker, ...  │ │ Calculator   │ │ TileSource  │ │  envelope)   │ │
│  └──────────────┘ │ JsonMigrator │ │IconPack, etc│ └──────────────┘ │
│                   └──────────────┘ └─────────────┘                  │
│  Zero imports of flutter/*, drift, geolocator, flutter_map, dart:io │
├──────────────────────────────────────────────────────────────────────┤
│            Infrastructure (concrete adapters behind interfaces)      │
│                      lib/infrastructure/                             │
├──────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────────┐  │
│  │ Drift DB   │ │ Geolocator │ │ flutter_map│ │ PathProvider /   │  │
│  │ (Sessions  │ │LocationSrc │ │ TileSource │ │ file system      │  │
│  │  Markers   │ │ Impl       │ │ Impl (OSM) │ │ (photos, logs,   │  │
│  │  RevealedT │ │            │ │            │ │  export files)   │  │
│  │  iles,     │ │            │ │            │ │                  │  │
│  │  Categorie │ │            │ │            │ │                  │  │
│  │  s,        │ │            │ │            │ │                  │  │
│  │  MirkStyles│ │            │ │            │ │                  │  │
│  └────────────┘ └────────────┘ └────────────┘ └──────────────────┘  │
│  ┌──────────────┐ ┌──────────────────┐ ┌───────────────────────┐    │
│  │ Shared       │ │ ImagePicker      │ │ FilePicker +          │    │
│  │ Preferences  │ │ (marker photos)  │ │ share_plus (I/O)      │    │
│  └──────────────┘ └──────────────────┘ └───────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Platform (Android foreground service, iOS background mode)  │    │
│  └─────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### Dependency Rule

Inner layers know nothing about outer layers. Arrows point **downward only**:

```
Presentation  →  Application  →  Domain
                                    ↑
                              Infrastructure
```

- Domain declares interfaces. Infrastructure implements them.
- Application wires up Riverpod providers that inject infrastructure into domain services.
- Presentation watches providers. Never constructs services directly.

**Enforcement:** `import_lint` rule + review checklist. `lib/domain/**/*.dart` must not import `package:flutter/`, `package:drift/`, `package:geolocator/`, `package:flutter_map/`, `dart:io`, or any `lib/infrastructure/**` path.

### Folder Structure

```
lib/
├── main.dart                    # bootstrap + runApp() ONLY
├── app.dart                     # root MaterialApp + router + ProviderScope
├── bootstrap.dart               # runZonedGuarded, FlutterError.onError, log init
│
├── config/
│   ├── constants.dart           # magic numbers, timeouts, default reveal radius
│   ├── build_flags.dart         # --dart-define wrappers (DEBUG, ...)
│   └── license_header.dart      # the GOSL header text used by About screen
│
├── domain/                      # PURE DART — no Flutter, no I/O
│   ├── model/
│   │   ├── session.dart         # Freezed Session
│   │   ├── marker.dart          # Freezed Marker
│   │   ├── marker_category.dart # Freezed MarkerCategory
│   │   ├── mirk_style.dart      # Freezed MirkStyle (config-driven)
│   │   ├── revealed_tile.dart   # RevealedTile (parent key + 64×64 bitmap)
│   │   ├── lat_lng.dart         # domain-owned LatLng (not leaking latlong2)
│   │   ├── envelope.dart        # {schemaVersion, type, payload}
│   │   └── ids.dart             # SessionId, MarkerId (typedef wrappers)
│   │
│   ├── service/                 # USE CASES (pure algorithms)
│   │   ├── tile_math.dart       # latLngToSubTile, subTileToLatLng, radiusToCells
│   │   ├── reveal_calculator.dart  # radius+position → cells to set
│   │   ├── json_migrator.dart   # v1→v2→current migrations
│   │   ├── export_builder.dart  # builds envelope + payload from domain
│   │   └── import_parser.dart   # envelope → domain or Result.failure
│   │
│   └── port/                    # INTERFACES the infrastructure implements
│       ├── session_state_store.dart
│       ├── marker_store.dart
│       ├── revealed_tile_store.dart
│       ├── mirk_style_store.dart
│       ├── category_store.dart
│       ├── location_source.dart
│       ├── tile_source.dart
│       ├── photo_store.dart
│       ├── marker_icon_pack.dart
│       ├── mirk_renderer.dart
│       ├── export_sink.dart     # file picker / share sheet
│       ├── import_source.dart   # file picker
│       └── logger.dart
│
├── infrastructure/              # ADAPTERS — implement domain/port/*
│   ├── persistence/
│   │   ├── drift/
│   │   │   ├── app_database.dart
│   │   │   ├── session_table.dart
│   │   │   ├── marker_table.dart
│   │   │   ├── revealed_tile_table.dart
│   │   │   ├── category_table.dart
│   │   │   ├── mirk_style_table.dart
│   │   │   └── migrations/
│   │   ├── drift_session_state_store.dart
│   │   ├── drift_marker_store.dart
│   │   └── drift_revealed_tile_store.dart
│   ├── location/
│   │   ├── geolocator_location_source.dart
│   │   └── foreground_service_controller.dart  # Android FGS, iOS bg mode
│   ├── map/
│   │   ├── online_osm_tile_source.dart
│   │   └── tile_source_factory.dart            # V1.1: add MbtilesTileSource
│   ├── photo/
│   │   ├── image_picker_photo_capturer.dart
│   │   └── filesystem_photo_store.dart
│   ├── export/
│   │   ├── share_plus_export_sink.dart
│   │   └── file_picker_import_source.dart
│   ├── icon_pack/
│   │   ├── bundled_default_icon_pack.dart      # the built-in RPG set
│   │   └── imported_icon_pack.dart             # V1.x
│   ├── render/
│   │   └── custom_painter_mirk_renderer.dart   # V1.0 default renderer
│   └── logging/
│       └── file_logger.dart
│
├── features/                    # Feature slices: application + presentation
│   ├── map/
│   │   ├── application/
│   │   │   ├── map_viewport_controller.dart    # camera state provider
│   │   │   └── fog_of_war_layer_vm.dart        # revealed tiles for viewport
│   │   └── presentation/
│   │       ├── map_screen.dart
│   │       ├── fog_of_war_layer.dart           # CustomPaint widget
│   │       └── marker_overlay_layer.dart
│   ├── session/
│   │   ├── application/
│   │   │   ├── session_list_controller.dart
│   │   │   ├── active_session_controller.dart  # start/stop state machine
│   │   │   └── revealed_area_controller.dart   # consumes LocationSource
│   │   └── presentation/
│   │       ├── session_list_screen.dart
│   │       └── session_edit_screen.dart
│   ├── marker/
│   │   ├── application/
│   │   │   ├── marker_list_controller.dart
│   │   │   └── marker_edit_controller.dart
│   │   └── presentation/
│   │       ├── marker_list_screen.dart
│   │       ├── marker_edit_screen.dart
│   │       └── marker_detail_sheet.dart
│   ├── import_export/
│   │   ├── application/
│   │   │   └── import_export_controller.dart
│   │   └── presentation/
│   │       ├── import_screen.dart
│   │       └── export_screen.dart
│   ├── options/
│   │   ├── application/
│   │   │   └── options_controller.dart
│   │   └── presentation/
│   │       ├── options_screen.dart
│   │       ├── reveal_radius_slider.dart
│   │       ├── mirk_style_picker.dart
│   │       └── category_manager_screen.dart
│   └── legal/
│       └── presentation/
│           └── about_screen.dart              # GOSL text + link
│
└── shared/
    ├── widgets/
    │   ├── error_banner.dart
    │   └── loading_indicator.dart
    └── util/
        ├── async_value_x.dart
        └── context_guards.dart               # mounted-check helpers
```

### Component Responsibilities

| Component | Owns | Exposes | Depends on |
|-----------|------|---------|------------|
| `AppDatabase` (Drift) | SQLite schema, migrations, typed DAOs | Table-level CRUD to store adapters | `drift`, `sqlite3_flutter_libs` |
| `DriftRevealedTileStore` | Persistence of 64×64 sub-tile bitmaps keyed by parent tile | `RevealedTileStore` port | `AppDatabase` |
| `DriftSessionStateStore` | Session row + "currently active session" invariant | `SessionStateStore` port | `AppDatabase` |
| `GeolocatorLocationSource` | GPS subscription, permission check, FGS/iOS-bg integration | `LocationSource` port (stream of `LocationFix`) | `geolocator`, `permission_handler`, `flutter_local_notifications`, `ForegroundServiceController` |
| `OnlineOsmTileSource` | HTTP `GET` of tiles with compliant UA, cache headers | `TileSource` port | `flutter_map`, HTTP client from within it |
| `CustomPainterMirkRenderer` | Paint implementation for the V1.0 default style | `MirkRenderer` port | Flutter `dart:ui` `Canvas` |
| `FilesystemPhotoStore` | Photo copy into app docs dir, path resolution | `PhotoStore` port | `path_provider`, `dart:io` |
| `BundledDefaultIconPack` | The default RPG icon set shipped in assets | `MarkerIconPack` port | Flutter assets |
| `SharePlusExportSink` | Share-sheet-based export | `ExportSink` port | `share_plus` |
| `FilePickerImportSource` | User-picks-JSON import | `ImportSource` port | `file_picker` |
| `RevealCalculator` (pure) | Convert `(position, radius)` → set of sub-tile cells | Static utility | Nothing — pure math |
| `TileMath` (pure) | lat/lng ↔ tile index conversions | Static utility | Nothing — pure math |
| `JsonMigrator` (pure) | Envelope version chain migration | `MigrationResult` sum type | Nothing — pure Dart |
| `ActiveSessionController` (Riverpod `AsyncNotifier`) | Session state machine (Created→Active→Paused→Stopped), exclusivity invariant | `AsyncValue<ActiveSessionState>` | `SessionStateStore`, `LocationSource`, `RevealedAreaController`, `ForegroundServiceController` |
| `RevealedAreaController` (Riverpod `Notifier`) | Consumes location stream, updates bitmap, publishes viewport-filtered tiles | `Set<SubTileIndex>` (viewport-filtered) | `LocationSource`, `RevealedTileStore`, `RevealCalculator`, `MapViewportController` |
| `ImportExportController` (Riverpod `AsyncNotifier` with mutations) | Serialize/deserialize full sessions, marker-only files, style files | `ImportResult` / `ExportResult` | All stores + `JsonMigrator` + `PhotoStore` + `ExportSink`/`ImportSource` |
| `FogOfWarLayer` (widget) | Paints fog on top of `TileLayer`, rebuilds only when viewport or revealed set changes | A `flutter_map` layer child | `RevealedAreaController` provider, `MirkRenderer` provider |

---

## Key Abstractions (Concrete Dart Signatures)

These are the **seams**. The interfaces are the contract; anything on the other side can be swapped without touching consumers.

### `MirkRenderer`

The fog-paint strategy. Receives everything the paint needs; owns its own animation timer if the style is animated.

```dart
/// Paints the mirk layer over the map. Implementations may be static (simple
/// blend) or animated (noise, flow, shader). Life of a renderer is tied to a
/// selected mirk style; switching style disposes the previous renderer.
abstract interface class MirkRenderer implements Listenable {
  /// Called every frame when the renderer is animated, OR only on viewport
  /// change when static. Implementations must paint the fog over [size].
  ///
  /// [ctx] provides the data needed to decide which pixels are fog vs reveal:
  ///   - viewportBounds: the LatLng bounds currently rendered
  ///   - revealedCells: sub-tile cells intersecting the viewport (pre-filtered)
  ///   - currentPosition: the live GPS position (may be null; animates halo)
  ///   - revealRadiusMeters: for animating edge soft-falloff
  ///   - pixelsPerMeter: derived from current zoom, used to size the halo
  ///   - devicePixelRatio: for crisp painting on HiDPI
  void paint(Canvas canvas, Size size, MirkPaintContext ctx);

  /// Called when the active style is swapped or the layer is removed.
  /// Implementations cancel timers, release textures, etc.
  void dispose();

  /// Applies the configuration sub-object of a [MirkStyle]. Called once on
  /// creation and again if the user edits style parameters live.
  /// Throws [MirkStyleConfigException] if [config] is incompatible with this
  /// renderer (e.g. a shader renderer receiving a noise-only config).
  void applyConfig(Map<String, Object?> config);
}

/// Factory registered per renderer type. Matched by [MirkStyle.rendererType].
abstract interface class MirkRendererFactory {
  String get rendererType; // e.g. "custom_painter_v1", "shader_v1"
  MirkRenderer create(MirkStyle style, TickerProvider vsync);
}

/// Data passed to [MirkRenderer.paint]. Immutable per-frame snapshot.
class MirkPaintContext {
  const MirkPaintContext({
    required this.viewportBounds,
    required this.revealedCells,
    required this.currentPosition,
    required this.revealRadiusMeters,
    required this.pixelsPerMeter,
    required this.devicePixelRatio,
    required this.mapToScreen,
  });

  final LatLngBounds viewportBounds;
  final Set<SubTileIndex> revealedCells;
  final LatLng? currentPosition;
  final double revealRadiusMeters;
  final double pixelsPerMeter;
  final double devicePixelRatio;

  /// Converts a LatLng to a screen-space [Offset] for this frame.
  final Offset Function(LatLng point) mapToScreen;
}
```

**Decoupling test:** adding a shader-based renderer only adds `lib/infrastructure/render/shader_mirk_renderer.dart` and a factory registration. Zero changes to `FogOfWarLayer`, `MapScreen`, or any provider.

### `TileSource`

The map tile origin. V1.0 implements online OSM; V1.1 adds MBTiles offline.

```dart
/// Provides raster map tiles for a given (z, x, y). V1.0: online HTTP.
/// V1.1: MBTiles file. Implementations own their own cache policy.
abstract interface class TileSource {
  /// Stable identity of this source; used as cache key namespace.
  String get id;

  /// Human-readable attribution shown on the map (e.g.
  /// "© OpenStreetMap contributors").
  String get attribution;

  /// The zoom range this source can service. Requests outside are rejected.
  ({int min, int max}) get zoomRange;

  /// Returns the raw PNG/JPEG bytes for a tile, or null if not available
  /// (offline MBTiles may not have every tile). Implementation MUST respect
  /// [cancellation]; throws [TileFetchTimeout] after
  /// [MirkTimeouts.tileFetch].
  Future<Uint8List?> fetchTile(TileCoordinate coord, CancelToken cancellation);

  /// Disposes HTTP clients, closes SQLite handles, etc.
  Future<void> dispose();
}

/// A slippy-map tile coordinate.
class TileCoordinate {
  const TileCoordinate({required this.z, required this.x, required this.y});
  final int z;
  final int x;
  final int y;
}
```

**Decoupling test:** adding `MbtilesTileSource` for V1.1 is one new infrastructure file plus one new branch in `tile_source_factory.dart`. `MapScreen`, `TileLayer` configuration, and all providers are unchanged.

### `MarkerIconPack`

The marker icon catalog. Generic enough to support imported packs later.

```dart
/// An icon set for marker categories. V1.0 ships one bundled default pack;
/// V1.x can import additional packs from a user-supplied archive.
abstract interface class MarkerIconPack {
  /// Stable identity, used as foreign key from MarkerCategory.iconPackId.
  String get id;

  /// Display name (localizable).
  String get displayName;

  /// Icons this pack offers. [IconId] is opaque to consumers.
  List<IconDescriptor> get icons;

  /// Resolves an icon to a paintable widget. Implementations may return
  /// a bitmap [Image.asset], an SVG widget (if the pack uses SVG), etc.
  ///
  /// Returns null if [iconId] is not in this pack — caller should fall back
  /// to a placeholder icon.
  Widget? buildIcon(IconId iconId, {required double size, Color? tint});

  /// Paints the icon directly to a canvas, used by the marker layer's
  /// CustomPainter when we want to batch marker rendering instead of
  /// placing a widget per marker.
  void paintIcon(
    Canvas canvas,
    IconId iconId, {
    required Offset center,
    required double size,
    Color? tint,
  });
}

class IconDescriptor {
  const IconDescriptor({
    required this.id,
    required this.displayName,
    required this.tags,
  });
  final IconId id;
  final String displayName;
  final List<String> tags; // "tavern", "camp", "danger", ... for search
}

extension type const IconId(String value) {}
```

**V1.0 bundled pack implementation:** PNG assets in `assets/icons/default/` plus a `bundled_default_icon_pack.dart` that enumerates them. Import pack format (V1.x, not V1.0 scope): a ZIP with `pack.json` manifest + icon PNG/SVG files, unpacked into `<app_docs>/icon_packs/<pack_id>/`.

### `SessionStateStore`

The single source of truth for session persistence. Enforces the "one active session" invariant at the store layer (not just UI).

```dart
/// Persistent session storage. Guarantees the "at most one active session"
/// invariant via a DB constraint or transaction, NOT via caller discipline.
abstract interface class SessionStateStore {
  Future<List<Session>> listAll();

  Future<Session?> findById(SessionId id);

  /// Returns the currently active session if any. At most one.
  Future<Session?> findActive();

  Future<Session> create({required String displayName});

  Future<void> rename(SessionId id, String newDisplayName);

  Future<void> delete(SessionId id);

  /// Sets [id] to Active and atomically sets any other active session to
  /// Stopped. Single transaction — callers cannot observe two actives.
  /// Throws [SessionNotFoundException] if [id] does not exist.
  Future<Session> activate(SessionId id);

  /// Sets [id] to Stopped regardless of its current state. Idempotent.
  Future<Session> stop(SessionId id);

  /// Sets [id] to Paused. Only valid from Active state; throws
  /// [InvalidSessionTransition] otherwise.
  Future<Session> pause(SessionId id);

  /// Stream of all sessions. Re-emits on any mutation. Used by session list UI.
  Stream<List<Session>> watchAll();

  /// Stream of the active session (null when none active).
  Stream<Session?> watchActive();
}
```

### `LocationSource`

The GPS stream wrapper. Thin façade over `geolocator` that our app reasons about — we never import `geolocator` outside `infrastructure/location/`.

```dart
/// The source of GPS fixes. Implementations handle permission prompts,
/// foreground-service lifecycle, and OS-specific background mode config.
abstract interface class LocationSource {
  /// Must be called once at app start to prime permission state.
  /// Does NOT prompt the user — that's deferred to [startTracking].
  Future<LocationPermissionState> currentPermissionState();

  /// Prompts for WhenInUse + Background (Android) / Always (iOS) as needed.
  /// Returns the granted level; caller decides whether to proceed.
  Future<LocationPermissionState> requestPermission();

  /// Begins streaming fixes at up to [minUpdateIntervalMs] rate and
  /// [minDistanceMeters] spatial filter. On Android also starts the
  /// foreground service + persistent notification.
  ///
  /// Throws [LocationPermissionDenied] if permission is insufficient.
  /// Throws [LocationDisabled] if GPS is off.
  ///
  /// The returned stream completes when [stopTracking] is called.
  Stream<LocationFix> startTracking({
    required Duration minUpdateInterval,
    required double minDistanceMeters,
  });

  Future<void> stopTracking();

  /// Whether tracking is currently active (any subscriber present).
  bool get isTracking;
}

class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracyMeters,
    required this.timestampUtc,
    required this.source,
  });
  final LatLng position;
  final double accuracyMeters;
  final DateTime timestampUtc;
  final LocationFixSource source; // foreground / background / resumed
}
```

---

## Revealed-Area Data Model — THE Design Decision

### Problem statement

GPS produces a stream of (lat, lng, timestamp) at 1 fix / 5s while tracking. A one-year active user walking 2 km/day:

- 2 km/day × 365 = 730 km/year of track
- At 5s/fix and 1.4 m/s walking speed → 1 fix every 7 m → **~104k fixes/year per session**
- At ~40 bytes per fix row (SQLite) → **~4 MB/year per session** if stored raw

Storing raw fixes is **functionally wrong** (we don't need fix timestamps — we only care "was this cell ever revealed") and **grows unboundedly** across many sessions. We need a lossy but semantically correct compression.

### Chosen: Hierarchical sparse sub-tile bitmap

**DECIDED.**

- **Parent tile = slippy XYZ at zoom 14.** At zoom 14 and 40° lat, a tile is ≈ 2.4 km × 1.8 km. A "neighborhood" session fits in ~1–10 parent tiles; a road-trip across Europe fits in a few hundred.
- **Sub-tile grid = 64 × 64 cells inside each parent tile.** Each cell is ≈ 38 m × 28 m at 40° lat. Cells are stored as a **512-byte bitmap** (64 × 64 = 4096 bits). A cell is 1 if ever revealed, 0 otherwise.
- Equivalently: we're using OSM slippy tiles at a conceptual zoom 20 (each zoom-14 parent has 2^(20-14)² = 2^12 = 4096 children at zoom 20), stored as a packed 64×64 bitmap per parent.
- **Why not store raw zoom-20 tile indices?** Each index is 16 bytes (z, x, y as ints + row overhead). A mid-density session reveals 5,000–50,000 cells → 80 KB–800 KB as individual rows, versus 512 B × ~10 parent tiles = ~5 KB as bitmaps. Bitmap wins by two orders of magnitude once density is above ~20% of a parent tile.

### Storage math (quality-gate target: <100 MB/year)

| User profile | Parent tiles touched/year | Storage |
|---|---|---|
| Dense local user (one neighborhood, 2 km/day year-round) | ~5 parent tiles | ~2.5 KB + row overhead → **~10 KB/year** |
| Regional explorer (multiple cities, weekend trips) | ~50 parent tiles | ~25 KB + overhead → **~80 KB/year** |
| Road-trip traveler (road-trip across a continent) | ~500 parent tiles | ~250 KB + overhead → **~1 MB/year** |
| Pathological "walk entire country" | ~5,000 parent tiles | ~2.5 MB + overhead → **~10 MB/year** |

**All well below the 100 MB/year ceiling** — we have two orders of magnitude headroom.

### Reveal-radius → cell mapping

Given user position `p` and radius `r` (e.g. 50 m), the set of sub-tile cells intersecting the reveal disc is computed by `RevealCalculator`:

```dart
Set<SubTileIndex> cellsIntersecting(LatLng p, double radiusMeters) {
  // Convert radius to degrees at p's latitude (cos(lat) correction)
  // Compute AABB of the disc in lat/lng
  // Walk the AABB in sub-tile steps, include cells whose center lies in disc
  // Returns SubTileIndex = (parentZ=14, parentX, parentY, subCol 0..63, subRow 0..63)
}
```

At 50 m radius and ~30 m cells, a reveal covers ~5–12 cells per fix. Throughput is trivial: we accumulate into an in-memory bitmap per parent tile and batch-flush to Drift every 5 s / 50 fixes / on session pause. Idempotent (setting a bit that's already 1 is a no-op), so crash recovery is simply "replay from where DB says."

### Drift schema sketch

```dart
@DataClassName('RevealedTileRow')
class RevealedTileTable extends Table {
  TextColumn get sessionId => text().references(SessionTable, #id).makeCase();
  IntColumn get parentZ => integer()();          // always 14 in V1.0
  IntColumn get parentX => integer()();
  IntColumn get parentY => integer()();
  BlobColumn get bitmap => blob()();             // 512 bytes, 64x64 packed
  IntColumn get setBitCount => integer()();      // cached popcount for UI
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId, parentZ, parentX, parentY};
}
```

The `setBitCount` cached popcount lets us show stats like "% of world revealed" without scanning all bitmaps — a V1.x feature, but the column is cheap to maintain.

### Viewport filtering for the fog layer

When the map viewport is (e.g.) zoom 12 showing 20 × 15 km, we only need the parent tiles intersecting that viewport. `RevealedAreaController` exposes a `Set<SubTileIndex>` filtered to the current viewport. This set is the input to `MirkRenderer.paint()`.

At zoom levels **above** 14 (zoomed in), each viewport intersects 1–4 parent tiles → bitmap unpacks once, renderer paints cells. At zoom levels **below** 14 (zoomed out, e.g. continent view), we don't paint cell-level fog at all — instead we paint parent-tile-level "any reveal" rectangles (one bit per parent tile via the `setBitCount > 0` check). This is a rendering optimization handled in `FogOfWarLayer`, invisible to the rest of the app.

### Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Store raw GPS points and render fog as union of circles every frame | Grows 4 MB/year/session; render cost O(points) every frame; no natural way to "merge sessions" on import. |
| H3 hexagons | Hexagons don't line up with the XYZ tile grid `flutter_map` uses; converting H3 cells to screen-space polygons every frame is expensive; gain (better area uniformity) is irrelevant for paint-a-bitmap-over-map. |
| Geohash strings | Variable-length text keys, worst storage density of the three options, bigger I/O. No upside. |
| Raw polygon (concave hull of revealed area) | Union/diff operations grow O(n²) vertices; edge cases at self-intersection; storage cost dominated by string or WKB blob. Wins nothing over bitmap. |
| Fixed per-session 2D array covering whole earth | Sparse allocation wastes memory; needs tiling anyway → just use the tile grid directly. |

### OPEN questions (defer to implementation)

- Exact sub-tile grid size — 64×64 (5 KB typical) vs 32×32 (cheaper storage, coarser reveal at ~75 m cell). 64×64 recommended but tunable after first real-world test.
- Batch flush interval — 5 s / 50 fixes / pause. Tuning question.
- Do we index `(sessionId, updatedAt)` for a future "reveal history" feature? Cheap to add later, skip for V1.0.

---

## Map Integration Pattern

### Layer stack in `MapScreen`

```dart
FlutterMap(
  mapController: ref.watch(mapControllerProvider),
  options: MapOptions(
    initialCenter: initialCenter,
    initialZoom: 15,
    onPositionChanged: (pos, _) =>
        ref.read(mapViewportControllerProvider.notifier).update(pos),
  ),
  children: <Widget>[
    TileLayer(
      tileProvider: ref.watch(tileProviderProvider),
      userAgentPackageName: 'com.thongvan.mirkfall',
      // Attribution rendered separately in an Align; keep the tile layer lean
    ),
    MarkerLayer(
      markers: ref.watch(visibleMarkersProvider),
    ),
    const FogOfWarLayer(),   // custom widget — reads its own providers
    const MapAttributionWidget(), // aligns bottom-right
  ],
)
```

Order is load-bearing: tiles → markers → fog → attribution (topmost). Markers drawn **below** fog so they're rendered "under" — the fog renderer then draws them **back on top** at reduced opacity to satisfy the "markers visible in transparency under mirk" requirement (spec §4.2). This is a single-pass trick handled inside `CustomPainterMirkRenderer` via a composite layer: draw fog mask with markers punched through at 30% alpha.

### `FogOfWarLayer` widget

```dart
class FogOfWarLayer extends ConsumerWidget {
  const FogOfWarLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderer = ref.watch(activeMirkRendererProvider);
    final viewportBounds = ref.watch(mapViewportBoundsProvider);
    final revealedCells = ref.watch(viewportRevealedCellsProvider);
    final currentPosition = ref.watch(currentLocationProvider).valueOrNull;
    final revealRadius = ref.watch(revealRadiusMetersProvider);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _MirkCustomPainter(
          renderer: renderer,            // Listenable — repaints on animation
          context: MirkPaintContext(
            viewportBounds: viewportBounds,
            revealedCells: revealedCells,
            currentPosition: currentPosition,
            revealRadiusMeters: revealRadius,
            /* ... */
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
```

- **RepaintBoundary** isolates the layer so other `flutter_map` layers don't repaint when fog animates.
- **CustomPaint** subscribes to the renderer's `Listenable` via `CustomPainter.shouldRepaint` returning true when the renderer ticks (animated styles) or the revealed-cell set changes.
- The revealed-cell set is **pulled** from a provider, not pushed into the widget. The provider (`viewportRevealedCellsProvider`) does the viewport intersection in pure Dart; it depends on `mapViewportBoundsProvider` (changes on pan/zoom) and `revealedTileStreamProvider` (changes on new reveal).

### Invalidation strategy

Three sources of change, each with its own cost:

| Event | Recompute cost | Mitigation |
|---|---|---|
| User pans/zooms | Viewport intersection (cheap — parent-tile AABB check) | Provider rebuilds, CustomPainter repaints once. |
| New GPS fix adds cells | In-memory bitmap union (cheap — OR into Uint8List). Flush to Drift batched. | Provider emits **only** if the flushed cells actually intersect the current viewport; no-op otherwise. |
| Animation tick (animated styles only) | Same revealed set, different time parameter | Renderer owns its own ticker via `SingleTickerProviderStateMixin`; `shouldRepaint` returns true; revealed set not recomputed. |

**In-memory cache:** `RevealedAreaController` holds the unpacked bitmap(s) of currently visible parent tiles in memory (RAM budget: 4 parent tiles × 512 B = 2 KB; trivial). On viewport change, unload parents that moved out of view, load new ones from Drift. At 60 fps pan, loads are amortized because viewport changes only cross parent-tile boundaries occasionally.

---

## Session Lifecycle

### State machine

```
                   create()
        ┌────────────────────────┐
        ▼                        │
    ┌────────┐  activate()   ┌────────┐
    │Created │──────────────▶│ Active │
    └────────┘               └───┬────┘
        ▲  delete()              │ pause()      ┌────────┐
        │                        ├─────────────▶│ Paused │
        │  (terminal)            │              └───┬────┘
        │                        │                  │
        │                        │ stop()  ─────────┤ stop()
        │                        ▼                  │
        │                   ┌─────────┐             │
        │                   │ Stopped │◀────────────┘
        │                   └────┬────┘
        │                        │
        └────────────────────────┘
                     delete()
```

- **Created**: Row exists, no tracking, no revealed tiles yet.
- **Active**: Currently tracking. The `SessionStateStore.activate()` transaction ensures only one session is Active at any time (the DB enforces it, not caller discipline).
- **Paused**: Tracking stopped but retains "most recently active" semantic. User can resume (= activate again, which demotes previous Active to Stopped). Location fixes received during Paused are **discarded**, not queued (see OPEN below).
- **Stopped**: Prior session, no special status. Can be re-activated later.

### Enforcing "at most one active"

DB-level enforcement via a partial unique index on session `status` when value = `active`:

```sql
CREATE UNIQUE INDEX one_active_session
  ON sessions(status) WHERE status = 'active';
```

Drift migration declares this. `SessionStateStore.activate()` is implemented as a single transaction: `UPDATE sessions SET status='stopped' WHERE status='active'; UPDATE sessions SET status='active' WHERE id=?;`. If two callers race, SQLite serializes them; the loser's transaction sees the winner's row and succeeds (no exception).

### Interaction with background GPS

```
┌─────────────────────────┐
│ ActiveSessionController │
│  (AsyncNotifier)        │
└──────────┬──────────────┘
           │ on activate(id):
           │  1. store.activate(id)           → ensures exclusivity
           │  2. ForegroundService.start()     → Android FGS + notification
           │  3. location.startTracking(...)   → opens stream
           │  4. subscribe stream to           → each fix:
           │     RevealedAreaController             → RevealCalculator
           │                                        → store.mergeBitmap(...)
           │
           │ on pause(id) / stop(id):
           │  1. cancel stream subscription
           │  2. flush any pending bitmap to store
           │  3. ForegroundService.stop()
           │  4. store.pause(id) / store.stop(id)
           └─────────────────────────────────────────
```

### OPEN: fix buffering on Paused

When Paused: should we silently keep buffering GPS fixes and apply them if resumed? **Recommendation: NO — discard.** Paused means "stop revealing." Users who want to keep revealing should not pause. Buffering would cost battery (GPS stays on) and violate the user's explicit "pause" intent. Confirmed in implementation.

### OPEN: app killed during background tracking

Both OSes can kill background apps under memory pressure. Expected behavior:

- **Android**: Foreground service with persistent notification = protected, but not immune. If killed (Doze + memory), next app open shows "Session was interrupted" banner; last-flushed reveal state is intact. User can resume.
- **iOS**: If killed, the `UIBackgroundModes: location` mode allows CoreLocation to relaunch us for significant-location-change events, but granular reveal continuity may be lost. Document as known limitation.

Both cases are handled by the DB-first, flush-often design: we never hold unflushed state for more than 5 s / 50 fixes, so the maximum data loss window is small.

---

## Background GPS Service Architecture

### Consumption path

```
[geolocator native plugin]
         │ stream of Position
         ▼
[GeolocatorLocationSource]   ← infrastructure/location/
         │ maps Position → LocationFix
         │ filters by accuracy threshold (reject >50 m)
         ▼
[LocationSource stream]       ← domain/port/
         │
         ▼
[RevealedAreaController]      ← feature/session/application/
         │ computes cells via RevealCalculator
         │ accumulates in in-memory bitmap per parent tile
         │ emits updated revealedCellsProvider to fog layer
         │
         ▼ batched every 5 s / 50 fixes / onStop
[RevealedTileStore.mergeBitmap(sessionId, parentTile, bitmap)]
         │
         ▼
[AppDatabase]
```

### Key design choices

- **No event bus.** A Riverpod `StreamProvider` *is* the event bus — subscribers auto-dispose when no widget listens. Simpler than a custom bus, integrates with existing DI.
- **Direct-to-DB after in-memory accumulation.** Writing each fix individually to Drift would be fine on desktop but burns flash on mobile. Accumulate OR-into-Uint8List in memory, flush periodically.
- **Accuracy filter at the source adapter.** Rejecting bad fixes (>50 m accuracy) is a policy call; `GeolocatorLocationSource` applies it once. Domain logic assumes all `LocationFix` values are "good enough."
- **Foreground service is Android-only.** iOS uses the `UIBackgroundModes: location` plist entry + CoreLocation's own behavior. `ForegroundServiceController` is a no-op on iOS; the abstraction exists to keep `ActiveSessionController` platform-agnostic.

### Kill-recovery semantics

On app start, `ActiveSessionController` queries `SessionStateStore.findActive()`:

- **None active** → idle state, session list presented.
- **One active** → app was killed mid-tracking. Two choices:
  - **Auto-resume** (start tracking immediately without user confirmation): poor UX; user may not want to track right now.
  - **Show recovery banner** ("Session X was interrupted. Resume tracking?"): preferred.
- Implementation: show banner with "Resume" / "Stop" buttons. Resume calls `activate(id)`; Stop calls `stop(id)`. No automatic tracking start without consent.

---

## JSON Schema Versioning Strategy

### Envelope format (versioned, always)

```json
{
  "schemaVersion": 1,
  "type": "session",
  "exportedAt": "2026-04-17T10:30:00Z",
  "exportedBy": "MirkFall/1.0.0",
  "payload": { /* type-specific */ }
}
```

- **`schemaVersion`**: integer, strictly monotonic across the whole project. Bumped only when making an incompatible schema change.
- **`type`**: discriminant, one of `"session"`, `"sessions_bundle"`, `"markers"`, `"mirk_style"`, `"icon_pack"` (future).
- **`exportedAt` / `exportedBy`**: informational only. Never used to resolve schema.
- **`payload`**: the type-specific body, parsed by a type-specific `fromJson`.

The envelope is **hand-written Dart** (one file, ~30 lines) because its shape is stable and must parse even when the payload is unknown / wrong-versioned. The payloads are Freezed + `json_serializable`.

### Migration chain

```dart
sealed class MigrationResult<T> {}
class MigrationSuccess<T> extends MigrationResult<T> { final T value; ... }
class MigrationNeedsUserConfirm<T> extends MigrationResult<T> { final T value; final String warning; ... }
class MigrationFailed<T> extends MigrationResult<T> { final String reason; ... }

abstract interface class Migrator<T> {
  int get fromVersion;
  int get toVersion; // always fromVersion + 1
  MigrationResult<Map<String, Object?>> migrate(Map<String, Object?> payload);
}

class JsonMigrator {
  JsonMigrator(this._migratorByType);
  final Map<String, List<Migrator<dynamic>>> _migratorByType;

  MigrationResult<Map<String, Object?>> migrateToCurrent({
    required String type,
    required int fromVersion,
    required int currentVersion,
    required Map<String, Object?> payload,
  });
}
```

V1.0 ships **no migrators** (current version = 1, nothing to migrate from). The migration hook exists so V2 is a one-file addition: `migrate_session_v1_to_v2.dart`. Export always writes the current `schemaVersion`; import always runs the chain from the file's version to current.

### Mapping to domain models

Per CLAUDE.md's "DTO only if distinct semantics" rule:

- `Session`, `Marker`, `MarkerCategory`, `MirkStyle` — these **are** the domain entities, and their `fromJson`/`toJson` serve both the persistence boundary (Drift type converters) and the import/export boundary. **No DTO layer.**
- **Exceptions that justify DTOs:**
  - **`SessionBundleExport`** — a bundle of multiple sessions with a shared photo archive. Distinct aggregation semantic (multiple sessions + shared asset map) → it's a DTO, not an entity.
  - **`MarkersOnlyImport`** — markers without a session, used for pre-populating trips. Distinct "sessionless markers" semantic → DTO.
  - **`RevealedTileExport`** — the bitmap encoded as base64 for JSON readability. Distinct from the in-memory `Uint8List` representation → DTO. Documented as such in its docstring.
- `RevealedTile` in the DB is an internal concept (the bitmap per parent tile); on export it's serialized as a **list of (parentX, parentY, base64(bitmap))** sub-objects inside the session payload. The import path rebuilds the DB representation.

### Schema example (session export)

```json
{
  "schemaVersion": 1,
  "type": "session",
  "exportedAt": "...",
  "exportedBy": "MirkFall/1.0.0",
  "payload": {
    "id": "sess_abc123",
    "displayName": "Paris été 2026",
    "createdAt": "2026-04-15T08:00:00Z",
    "status": "stopped",
    "revealedTiles": {
      "parentZoom": 14,
      "subTileGridSize": 64,
      "tiles": [
        {"parentX": 8294, "parentY": 5635, "bitmapBase64": "AAAABAAA..." }
      ]
    },
    "markers": [ /* marker objects */ ],
    "categoriesReferenced": [ /* category objects embedded for self-containment */ ]
  }
}
```

- **`categoriesReferenced`** is embedded so an imported session on a different instance doesn't break when the target has different categories. Import merges by category name (user confirms conflicts).

---

## Photo Storage

### Filesystem layout

```
<applicationDocumentsDirectory>/
├── photos/
│   └── <sessionId>/
│       └── <markerId>/
│           ├── <uuid1>.jpg
│           ├── <uuid2>.jpg
│           └── ...
├── icon_packs/                         # V1.x
│   └── <packId>/
│       └── ...
├── mirk_styles/                        # imported JSON styles
│   └── <styleId>.json
├── logs/
│   └── yyyymmdd_hhmm.ss_logs.txt
└── exports/                            # temporary staging for exports
    └── <exportName>.zip
```

### Marker ↔ photo reference

```dart
@freezed
class Marker with _$Marker {
  const factory Marker({
    required MarkerId id,
    required SessionId sessionId,
    required LatLng position,
    required String title,
    required String description,
    required CategoryId categoryId,
    required List<PhotoRef> photos,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Marker;
  factory Marker.fromJson(Map<String, Object?> j) => _$MarkerFromJson(j);
}

@freezed
class PhotoRef with _$PhotoRef {
  const factory PhotoRef({
    required String filename,        // UUID + .jpg
    required int byteLength,
    required DateTime capturedAt,
  }) = _PhotoRef;
  factory PhotoRef.fromJson(Map<String, Object?> j) => _$PhotoRefFromJson(j);
}
```

- `PhotoRef.filename` is the basename, not a full path. The absolute path is resolved at use time via `FilesystemPhotoStore.resolveAbsolute(sessionId, markerId, filename)`. This is crash-safe across `path_provider` returning different paths after OS upgrades.

### Export strategy: ZIP archive (DECIDED)

Exports are **ZIP archives** with this structure:

```
mirkfall_export_paris_ete_2026.zip
├── export.json                         # envelope + payload
└── photos/
    └── <markerId>/
        ├── <uuid1>.jpg
        └── <uuid2>.jpg
```

- **Why ZIP over base64-in-JSON?** Base64 inflates photo size by ~33%, pushes JSON size past reasonable limits for file pickers and share sheets, and makes the JSON non-human-inspectable (claim #6 of core value — "schema readable by hand").
- **Why ZIP over separate files?** A single file is one share action, one file pick to import. Users don't want to pick a JSON + a folder.
- **Trade-off:** we ship a ZIP dependency. Dart's `archive` package (Apache 2.0 + MIT, no telemetry) is the standard answer. Add as an audited dependency.

### OPEN questions

- **Photo re-encoding on import?** If source photos are 12 MP originals, do we re-encode at import to save space, or preserve as-is? Recommend: **preserve as-is on import** (user's photos are their photos); V1.x option to "compress photo storage" can be added later.
- **Photo capture quality on add?** `image_picker` lets us pick `imageQuality` 0–100. Recommend: **85** as a sensible default, configurable in options.

---

## Marker Category / Icon System

### V1.0 default pack (bundled)

Shipped as a Flutter asset bundle in `assets/icons/default/`. Icons are **PNG at 3x (96×96)** for reliable rendering at any DPI. A `bundled_default_icon_pack.dart` enumerates them with stable IDs.

RPG-style icons sourced from: **game-icons.net** (CC BY 3.0 — acceptable for attribution; attribution shown in About screen). ~30 icons in the default pack covering tavern, camp, landmark, danger, shop, ruin, water, peak, etc.

### Icon pack abstraction

Defined by `MarkerIconPack` interface (see Key Abstractions). The data side of the abstraction:

```dart
@freezed
class MarkerCategory with _$MarkerCategory {
  const factory MarkerCategory({
    required CategoryId id,
    required String displayName,
    required String iconPackId,    // FK to MarkerIconPack.id
    required IconId iconId,        // key within that pack
    required int colorRgb,         // tint color
    required bool isUserCreated,
  }) = _MarkerCategory;
  factory MarkerCategory.fromJson(Map<String, Object?> j) =>
      _$MarkerCategoryFromJson(j);
}
```

- `iconPackId` = `"default"` for bundled categories.
- User-created categories pick an icon from any installed pack.
- On export, the `iconPackId` is preserved. On import, if the target instance doesn't have that pack installed, the marker category falls back to `iconPackId="default"` with a best-effort icon mapping (and a user-visible warning in the import summary).

### Imported pack format (V1.x, not V1.0 scope)

```
mirkfall_iconpack_medieval_expanded.zip
├── pack.json                           # {id, displayName, icons: [{id, displayName, file, tags}]}
└── icons/
    ├── crossbow.png
    ├── manor.png
    └── ...
```

The format is documented in `docs/icon_pack_format.md` (to be written when the feature ships). The V1.0 code paths never have to handle this — `MarkerIconPack` implementations simply slot in.

### Icon format decision: PNG (DECIDED)

- **PNG over SVG for V1.0.** SVG would be nicer (one size, crisp at all zooms), but needs `flutter_svg` (MIT, OK license) or `vector_graphics` (BSD-3). PNG is zero new dependencies for V1.0.
- Default pack ships at 3x (96×96). Flutter downscales to any display size. Storage cost: ~30 icons × 4 KB = 120 KB in the app bundle.
- **OPEN:** V1.1 may switch to SVG if we find downscaling quality bad, or if imported packs commonly want vector assets. Low-risk to add `flutter_svg` later.

---

## Build Order — Phase Dependency Graph

### Phase dependencies

```
[Phase 01: Foundation]
   ↓
   ├─► [Phase 03: GPS + Session lifecycle]
   │        ↓
   │        └─► [Phase 05: Map + Fog rendering]  ─┐
   │                                               │
   └─► [Phase 04: Models + Persistence]            │
            ↓                                      │
            ├──────────────────────────────────────┤
            ├─► [Phase 07: Markers]  ─────────────┤
            │        ↓                             │
            │        └─► [Phase 09: Import/Export]─┤
            │                                      │
            └─► [Phase 11: Mirk Styles + Options]──┤
                                                   │
                              [Phase 13: Polish / About / CI] ◄┘

(Review Gates: 02, 06, 08, 10, 12, 14 interleaved)
```

### Recommended phase ordering (synthesized with STACK.md and spec constraints)

| Phase | Content | Why here / depends on |
|---|---|---|
| **Phase 01 Code** — Foundation | Project scaffolding, analysis_options.yaml strict mode, license headers script, CI skeleton (Android + iOS-unsigned), main.dart bootstrap, runZonedGuarded, file logger, Riverpod `ProviderScope`, `constants.dart`, DEPENDENCIES.md seed. | Nothing works without this. Keep it small — no feature code. |
| **Phase 02 Review Gate** | — | — |
| **Phase 03 Code** — Persistence + domain models | Freezed models (Session, Marker, MarkerCategory, MirkStyle, RevealedTile, LatLng, Envelope). Drift schema + migrations + typed stores. `tile_math.dart` + `reveal_calculator.dart` pure utilities (with unit tests). No UI. | All later phases depend on these models and stores. Doing this before GPS ensures we never write "temporary" code to get GPS streaming without a place to save it. |
| **Phase 04 Review Gate** | — | — |
| **Phase 05 Code** — GPS + session lifecycle | `LocationSource` interface + `GeolocatorLocationSource` impl. Android foreground service setup. iOS `Info.plist` background mode. `ForegroundServiceController`. `ActiveSessionController` state machine. `RevealedAreaController` consuming fixes and writing bitmaps. Minimal session list UI to start/stop. **This phase proves the scariest technical risk** (background GPS across both OSes) early. | Depends on persistence (needs somewhere to write). Precedes map because we want end-to-end "GPS → DB" working before we can visualize. |
| **Phase 06 Review Gate** | — | — |
| **Phase 07 Code** — Map + fog rendering | `TileSource` interface + `OnlineOsmTileSource`. `MapScreen` with `flutter_map`. `MirkRenderer` interface + `CustomPainterMirkRenderer` (V1.0 default style). `FogOfWarLayer`. Viewport → revealed cells wiring. Attribution widget. | Depends on persistence (reads revealed tiles) and session lifecycle (consumes current position). Without these, the map has nothing to render. |
| **Phase 08 Review Gate** | — | — |
| **Phase 09 Code** — Markers | `MarkerIconPack` interface + `BundledDefaultIconPack`. Default RPG icon assets. Marker CRUD UI (list + edit + detail sheet). Photo capture via `image_picker`. `FilesystemPhotoStore`. Category CRUD. Marker rendering on map (with under-fog visibility rule per spec §4.2). | Depends on persistence + map. Doing markers **after** fog ensures the "under fog visibility" concern is designed in, not bolted on. |
| **Phase 10 Review Gate** | — | — |
| **Phase 11 Code** — Import/Export + style imports | Envelope, `JsonMigrator` (with v1 no-op chain), `ExportBuilder`, `ImportParser`. ZIP packaging via `archive`. Share-sheet export + file-picker import flows. Markers-only import. Mirk style JSON import. `MirkStyleStore`. Global options screen (reveal radius, active style, category manager, import/export buttons). | Depends on **all** models being stable. Doing this last avoids schema churn invalidating test exports. Options screen lives here because most options control previously-built features. |
| **Phase 12 Review Gate** | — | — |
| **Phase 13 Code** — Polish, About, CI hardening | About screen with GOSL text + link + attribution. Per-file license header audit. `flutter analyze` zero warnings. Unit + widget test coverage on key abstractions (interfaces + calculators + migrators). CI green on both platforms. README / DEPENDENCIES.md completion. Tag v1.0.0. | Terminal phase; consolidation. |
| **Phase 14 Review Gate** | — | — |

### What we deliberately DEFER (V1.1+)

- **Offline MBTiles tile source** — the `TileSource` abstraction in Phase 07 accommodates it without changes; the implementation is pure V1.1 work.
- **Additional mirk renderers** (shader style, seasonal variants) — the `MirkRenderer` abstraction accommodates them.
- **Imported icon packs** — `MarkerIconPack` abstraction accommodates.
- **Re-brumage** — explicitly out of scope per spec §8.
- **Stats / achievements** — out of scope.

### Build-order rationale in three sentences

We build **bottom up**: data and pure logic first, then the scariest integration (background GPS) next, then the visible result (map + fog) to get a working app feel, then markers on top, then the core-value feature (import/export) once schemas are stable, then polish. **The order minimizes rework**: every later phase depends only on earlier ones; no later phase forces a model change that would break an earlier one. **The order front-loads risk**: if background GPS is infeasible on iOS, we learn it in Phase 05, not Phase 11.

---

## Decision Register

### DECIDED (locked in this research, carried into roadmap)

| # | Decision | Rationale |
|---|---|---|
| D1 | Four-layer architecture: Presentation / Application / Domain / Infrastructure | Matches clean architecture, Riverpod community consensus, and CLAUDE.md's "separate UI and business logic strictly." |
| D2 | Domain is pure Dart; zero Flutter imports | Enables Domain unit tests to run on plain `dart test` without flutter_test harness. Enforces the abstraction discipline by ergonomics. |
| D3 | Revealed area = **zoom-14 parent tiles + 64×64 sub-tile bitmaps** | Storage ~10 KB/year typical, <10 MB/year pathological. Maps naturally to `flutter_map`'s tile grid. 10² less than raw GPS points. |
| D4 | Single Drift DB for all structured data | One migration story, one backup target, typed queries. |
| D5 | Riverpod as single state mgmt + DI container | Mandated by CLAUDE.md "un seul système." Doubles as DI — no `get_it`. |
| D6 | `MirkRenderer` interface is the **only** seam for fog rendering | Passes the "swap implementation without touching the rest" test. |
| D7 | `TileSource` interface decouples map from OSM/MBTiles/whatever | V1.1 offline is a one-file addition. |
| D8 | `MarkerIconPack` interface — V1.0 ships default bundled pack only | Future imports are a one-file addition. |
| D9 | Envelope JSON format `{schemaVersion, type, payload}` with hand-written envelope parsing, Freezed+json_serializable payloads | Versioning from day 1, but no premature migrator infrastructure. |
| D10 | Domain entities serve as import/export models (no 1:1 DTOs) | CLAUDE.md rule. DTOs only for genuine distinct semantics (bundle, markers-only import, base64-encoded bitmap). |
| D11 | Photos stored as files, referenced by basename via `PhotoRef` | Path portability across OS upgrades. |
| D12 | Export = ZIP (envelope JSON + photos folder) | Single-file share, JSON remains human-inspectable. Needs `archive` package (audited). |
| D13 | Session "one active" enforced by **DB partial unique index**, not caller discipline | Cannot be violated by any code path. |
| D14 | In-memory bitmap accumulation, flushed to Drift every 5s / 50 fixes / on state change | Battery + flash wear + crash-window sweet spot. |
| D15 | `FogOfWarLayer` wraps `CustomPaint` inside `RepaintBoundary`; renderer is `Listenable`-backed | `flutter_map`'s other layers don't repaint on fog animation. |
| D16 | V1.0 default icon pack: PNG at 3x from game-icons.net (CC BY 3.0), attributed in About screen | Zero new dependencies, licensing clean. |
| D17 | Recovery banner on app start if a session is marked Active from a prior run (no auto-resume) | User consent, no surprise battery drain. |
| D18 | Build order: Foundation → Models+Persistence → GPS+Session → Map+Fog → Markers → Import/Export → Polish | Minimizes rework, front-loads risk. |

### OPEN (resolve in implementation phase)

| # | Question | Where it resolves |
|---|---|---|
| O1 | Exact sub-tile grid size (32×32 vs 64×64 vs 128×128) | Phase 03; tunable after first real-world test. |
| O2 | Batch flush thresholds (time/count) | Phase 05; measure battery impact, adjust. |
| O3 | Paused session: discard fixes vs buffer | Phase 05 — recommendation: **discard**. |
| O4 | iOS kill-recovery granularity — do we need significant-location-change relaunch? | Phase 05; first real iOS test will tell. |
| O5 | Photo capture default quality (`image_picker` `imageQuality` 85?) | Phase 09; user-configurable later. |
| O6 | Photo re-encoding on import? | Phase 09 — recommendation: **preserve as-is**. |
| O7 | SVG icons vs PNG for V1.1 imported packs | Phase 11 or later; PNG-only in V1.0. |
| O8 | Exact list of default categories (tavern, camp, landmark, ...) | Phase 09; product decision, not architectural. |
| O9 | Should mirk styles apply per-session or globally? Spec §3.3 says global in V1.0. | Spec confirms global; schema supports per-session later. |
| O10 | MBTiles offline provider for V1.1 (OpenFreeMap vs Stadia Maps vs user-supplied) | Defer to V1.1 research pass. |
| O11 | `archive` package audit details (transitive deps, recent version) | Phase 11; dependency audit per CLAUDE.md. |

---

## Anti-Patterns (MirkFall-specific)

### Anti-Pattern 1: Reading `geolocator` directly from a widget

**What:** A `MapScreen` subscribes to `Geolocator.getPositionStream()` to display the current-position dot.
**Why it's wrong:** Breaks the domain abstraction. The widget now imports `geolocator`; replacing the source (e.g. a mock for tests, or `Tracelet` in V1.1) means editing every widget.
**Instead:** Widget watches `currentLocationProvider` which sources from `LocationSource` interface. Concrete plugin only appears in `infrastructure/location/`.

### Anti-Pattern 2: Storing revealed area as a list of LatLng points

**What:** `List<LatLng> revealedPath` persisted to Drift, map layer rendering unioned circles each frame.
**Why it's wrong:** 4 MB/year/session, O(n) render cost, no natural union/diff for imports.
**Instead:** Tile-based sub-tile bitmap per D3. Writers OR bits, readers unpack bitmap.

### Anti-Pattern 3: `MirkRenderer` exposing `ui.Image` or `Canvas` in its public interface

**What:** `MirkRenderer` declares `ui.Image buildFrame(...)` and the map layer paints that image.
**Why it's wrong:** Forces every renderer through a fixed intermediate. A shader renderer that wants to draw directly to the layer's canvas is handicapped.
**Instead:** Renderer receives the `Canvas` and paints into it directly. (See interface signature above.)

### Anti-Pattern 4: Singleton `DatabaseProvider.instance` accessed globally

**What:** `DatabaseProvider.instance.session.findAll()` from anywhere.
**Why it's wrong:** Violates CLAUDE.md's "pas de singletons globaux cachés." Unmockable in tests.
**Instead:** `databaseProvider` is a Riverpod provider. Test overrides via `ProviderContainer.overrides` inject a mock.

### Anti-Pattern 5: `is SessionActive` / `is SessionPaused` chains in application logic

**What:** `if (session is SessionActive) { ... } else if (session is SessionPaused) { ... }`
**Why it's wrong:** CLAUDE.md prohibits `is`-chains. Adds fragility on state enum expansion.
**Instead:** Dart 3 sealed class + switch expression exhaustiveness: `return switch (session.status) { SessionStatus.active => ..., SessionStatus.paused => ..., ... };`

### Anti-Pattern 6: Hiding `BuildContext` use after `await`

**What:** `await _picker.pickImage(); Navigator.push(context, ...);`
**Why it's wrong:** `context` may be unmounted. Explicit CLAUDE.md rule.
**Instead:** `await ...; if (!context.mounted) return; Navigator.push(context, ...);`

### Anti-Pattern 7: Saving the GPS stream subscription in a widget State

**What:** `_locationSub = Geolocator.getPositionStream().listen(...)` inside `initState` of `MapScreen`.
**Why it's wrong:** GPS lifecycle != widget lifecycle. Navigating away stops tracking. Background tracking impossible.
**Instead:** `ActiveSessionController` owns the subscription, scoped to session lifetime, independent of which widget is currently on screen.

### Anti-Pattern 8: Skipping the version envelope for "simple" exports

**What:** Mirk style import JSON is just `{ "color": "...", "noise": {...} }` without an envelope.
**Why it's wrong:** V2 of the style format has no migration path. "Simple" today = locked in forever.
**Instead:** Every importable/exportable JSON has the envelope, period.

---

## Data Flow Summary

### Write flow: GPS reveals a cell

```
Native OS (GPS) → geolocator plugin → GeolocatorLocationSource.stream
   → LocationFix → ActiveSessionController (subscribes while Active)
       → RevealedAreaController.onFix(fix)
           → RevealCalculator.cellsIntersecting(fix.position, radius)
           → in-memory bitmap OR (per parent tile)
       [batched flush trigger]
           → DriftRevealedTileStore.mergeBitmap(sessionId, parent, bitmap)
               → AppDatabase (SQLite)
```

### Read flow: map repaints fog

```
User pans map → FlutterMap.onPositionChanged
   → MapViewportController.update(pos)
       → mapViewportBoundsProvider rebuilds
           → viewportRevealedCellsProvider rebuilds
               → reads DriftRevealedTileStore.loadParentsIntersecting(bounds)
                   → unpacks bitmap(s) in memory → Set<SubTileIndex>
           → FogOfWarLayer rebuilds
               → CustomPaint invokes MirkRenderer.paint(canvas, ctx)
                   → canvas strokes
```

### Write flow: user imports session JSON

```
User taps Import → FilePickerImportSource.pick()
   → Uint8List bytes (ZIP archive)
       → ImportExportController.importSession(bytes)
           → extract ZIP → envelope JSON + photos/
           → Envelope.fromJson → type=="session", schemaVersion=N
           → JsonMigrator.migrateToCurrent(...) → payload at current version
           → Session.fromJson(payload) → domain Session, List<Marker>, revealedTiles
           → transaction:
               SessionStateStore.create(session)
               MarkerStore.createAll(markers)
               RevealedTileStore.bulkInsert(tiles)
               categories merged / warned
               photos copied to <photos>/<newSessionId>/<markerId>/
           → ImportResult.success(...)
               → UI banner: "Imported 'Paris été 2026' with 14 markers."
```

### Write flow: session start/stop (exclusivity)

```
User taps Start on sessionB (sessionA currently active)
   → ActiveSessionController.activate(sessionB.id)
       → SessionStateStore.activate(sessionB.id) [single transaction]
           UPDATE sessions SET status='stopped' WHERE status='active'
           UPDATE sessions SET status='active'  WHERE id=sessionB.id
       → ForegroundServiceController.restart(newSessionB)  (Android)
       → location.stopTracking(); location.startTracking(...)
       → RevealedAreaController rebinds to sessionB's bitmap
```

---

## Quality Gate Verification

- [x] **Components clearly defined with boundaries** — seven named interfaces in `domain/port/`, concrete implementations in `infrastructure/`, single-direction dependency rule enforced by folder structure.
- [x] **Data flow direction explicit** — four named flows documented with arrows; writers and readers identified per provider.
- [x] **Build order rationalized** — seven code phases with explicit dependency DAG; risk front-loaded (background GPS in Phase 05), core value (import/export) after schema stabilizes.
- [x] **Revealed-area storage is scalable** — back-of-envelope shows ~10 KB/year typical, ~10 MB/year pathological; 10² below the 100 MB/year ceiling.
- [x] **Mirk renderer decoupled** — `MirkRenderer` interface with concrete signature; adding a new renderer is one infrastructure file + one factory registration; zero changes to `FogOfWarLayer`, providers, or any other widget.
- [x] **V1.1 offline tile drop-in** — `TileSource` interface; V1.0 implements `OnlineOsmTileSource`; V1.1 adds `MbtilesTileSource` as a sibling; `tile_source_factory.dart` gains one branch. No other file changes.
- [x] **Concrete Dart interfaces provided** — `MirkRenderer`, `TileSource`, `MarkerIconPack`, `SessionStateStore`, `LocationSource` with full signatures.

---

## Sources

**flutter_map layer architecture:**
- [flutter_map — Layers](https://docs.fleaflet.dev/usage/layers) — children stack, last=topmost, custom widget layers supported
- [flutter_map — TileLayer](https://docs.fleaflet.dev/layers/tile-layer)
- [flutter_map API docs — TileLayer class](https://pub.dev/documentation/flutter_map/latest/flutter_map/TileLayer-class.html)
- [Mastering flutter_map (Medium, 2025)](https://medium.com/@developerimad70/mastering-flutter-map-a-practical-guide-part-1-e353fabf30ae)

**Tile / zoom math:**
- [OSM — Zoom levels](https://wiki.openstreetmap.org/wiki/Zoom_levels) — meters/pixel formula, tile sizes by zoom
- [OSM — Slippy map tilenames](https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames) — zoom 16 tile ≈ 0.61 km wide at equator
- [DEV Community — Understanding Map Zoom Levels and XYZ Tile Coordinates](https://dev.to/geoapify-maps-api/understanding-map-zoom-levels-and-xyz-tile-coordinates-55da)

**Fog-of-war real-world precedent:**
- [Fog of World app](https://fogofworld.app/) — real-time vector rendering, efficient DB; establishes the product category baseline
- [kindofdoon: Fog of War maps with real-world data (blog)](http://www.kindofdoon.com/2017/10/where-have-i-been-aka-fog-of-war.html) — zoom/scale tradeoffs
- [DidacRomero/Fog-of-War (GitHub)](https://didacromero.github.io/Fog-of-War/) — tile-based approach concepts (informational only; GPL project, code NOT reused)

**Geospatial indexing comparisons (to justify tile choice over H3/geohash):**
- [Geospatial Indexing Explained: Geohash, S2, H3 (benfeifke.com)](https://benfeifke.com/posts/geospatial-indexing-explained/)
- [Breaking Down Location-Based Algorithms (Medium)](https://medium.com/@sylvain.tiset/breaking-down-location-based-algorithms-r-tree-geohash-s2-and-h3-explained-a65cd10bd3a9)
- [H3 vs Geohash (h3geo.org)](https://h3geo.org/docs/comparisons/geohash/)

**Riverpod architecture patterns:**
- [Flutter App Architecture with Riverpod: An Introduction (codewithandrea.com)](https://codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/) — four-layer model (data/domain/application/presentation)
- [How to Fetch Data and Perform Data Mutations with the Riverpod Architecture (codewithandrea.com)](https://codewithandrea.com/articles/data-mutations-riverpod/) — AsyncNotifier + mutations pattern (Riverpod 3)
- [Flutter Riverpod Clean Architecture (DEV)](https://dev.to/ssoad/flutter-riverpod-clean-architecture-the-ultimate-production-ready-template-for-scalable-apps-gdh)
- [Implementing Clean Architecture with Riverpod (Medium)](https://theutsavg1.medium.com/implementing-clean-architecture-with-riverpod-for-modular-flutter-apps-7d21acfa9db0)

**Project context (read at top of research):**
- `.planning/PROJECT.md` — core value, constraints
- `CLAUDE.md` — conventions (DI, DTO rules, state management, layer separation)
- `specification V1.0.md` — full functional spec
- `.planning/research/STACK.md` — chosen technology stack

---

*Architecture research for: MirkFall (Flutter fog-of-war map app, local-first, versioned JSON)*
*Researched: 2026-04-17*

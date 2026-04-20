---
phase: 07-map-integration
plan: 03
type: execute
wave: 3
depends_on: ["07-02"]
files_modified:
  - lib/infrastructure/map/maplibre_map_view.dart
  - lib/infrastructure/map/pmtiles_source.dart
  - lib/infrastructure/map/style_rewriter.dart
  - lib/infrastructure/map/style_layer_order.dart
  - lib/infrastructure/map/country_resolver.dart
  - lib/infrastructure/map/first_launch_world_copier.dart
  - lib/infrastructure/map/geo/point_in_polygon.dart
  - lib/infrastructure/map/README.md
  - lib/infrastructure/mirk/noop_mirk_renderer.dart
  - lib/infrastructure/mirk/README.md
  - lib/infrastructure/platform/disk_space_checker.dart
  - lib/infrastructure/platform/ios_backup_excluder.dart
  - android/app/src/main/kotlin/app/gosl/mirkfall/DiskSpaceChannel.kt
  - android/app/src/main/kotlin/app/gosl/mirkfall/MainActivity.kt
  - ios/Runner/DiskSpaceChannel.swift
  - ios/Runner/IosBackupExcluderChannel.swift
  - ios/Runner/AppDelegate.swift
  - test/infrastructure/map/pmtiles_source_test.dart
  - test/infrastructure/map/style_rewriter_test.dart
  - test/infrastructure/map/style_layer_order_test.dart
  - test/infrastructure/map/country_resolver_test.dart
  - test/infrastructure/map/first_launch_world_copier_test.dart
  - test/infrastructure/map/geo/point_in_polygon_test.dart
  - test/infrastructure/mirk/noop_mirk_renderer_test.dart
  - test/infrastructure/platform/disk_space_checker_test.dart
autonomous: true
requirements:
  - MAP-01
  - MAP-03
  - MAP-04
  - MAP-05
  - MAP-06
  - MAP-07

must_haves:
  truths:
    - "Only `lib/infrastructure/map/` directory contains `import 'package:maplibre_gl/...'`; lint gate green"
    - "`PmtilesSource.forCountry(CountryCode? code)` returns `pmtiles://file:///<absolute-path>` for installed countries, world bundle fallback otherwise — NEVER an `http(s)://` URI"
    - "`localPmtilesUri(String)` helper produces `pmtiles://file:///<path>` on POSIX and normalises backslashes on Windows (no-op at runtime since MapLibre Native is not supported on desktop, but deterministic for unit tests)"
    - "`StyleRewriter.rewriteStyleForCountry(activeCountry)` loads `assets/maps/style.json`, substitutes the `YOUR_PMTILES_PATH_PLACEHOLDER` literal with the resolved URI, returns the final JSON string"
    - "`styleLayerOrder` constant list declares the 8 frozen layer IDs in order; unit test asserts `assets/maps/style.json` matches"
    - "`CountryResolver.resolve({lat, lon, zoom, installed})` returns alpha3 when viewport center is inside an installed polygon AND zoom ≥ 3; world fallback otherwise. 15+ lat/lon test cases green (Paris/Berlin/Madrid/London/NYC plus edge cases)"
    - "`FirstLaunchWorldCopier.ensureInstalled(expectedSha256)` copies `assets/maps/world.pmtiles` → `<app_support>/maps/world.pmtiles` idempotently, re-copies on sha256 mismatch"
    - "`NoopMirkRenderer implements MirkRenderer` — paint is empty, update is no-op, dispose returns completed future"
    - "`DiskSpaceChecker.freeBytes()` returns positive int on both Android (StatFs platform channel) and iOS (NSFileManager attributesOfFileSystem platform channel); test uses a fake platform channel to assert the contract"
    - "`IosBackupExcluder.excludePath(filename)` sets `NSURLIsExcludedFromBackupKey=true` via platform channel on iOS; no-op on Android (channel returns immediately)"
    - "Open Question #1 resolved: `MapLibreMapView.showMap(…)` captures camera position BEFORE `setStyle`, re-applies AFTER `onStyleLoadedCallback` fires (defensive, ~10 LoC)"
    - "Open Question #2 resolved: source swap uses `removeSource`+`addSource` if the maplibre_gl 0.25.0 API accepts the pmtiles URI in `VectorSourceProperties.url`; falls back to full `setStyle` if not. Decision documented in SUMMARY."
  artifacts:
    - path: "lib/infrastructure/map/maplibre_map_view.dart"
      provides: "MapLibreMapView adapter implementing MapView — the only file that imports maplibre_gl"
      contains: "package:maplibre_gl"
    - path: "lib/infrastructure/map/pmtiles_source.dart"
      provides: "PmtilesSource seam + localPmtilesUri helper"
      contains: "pmtiles://file://"
    - path: "lib/infrastructure/map/country_resolver.dart"
      provides: "CountryResolver: viewport + installed set → alpha3 | null"
      contains: "class CountryResolver"
    - path: "lib/infrastructure/map/first_launch_world_copier.dart"
      provides: "MAP-07 first-launch copy + sha256 auto-heal"
      contains: "class FirstLaunchWorldCopier"
    - path: "lib/infrastructure/mirk/noop_mirk_renderer.dart"
      provides: "stub MirkRenderer impl for Phase 07"
      contains: "class NoopMirkRenderer implements MirkRenderer"
    - path: "lib/infrastructure/platform/disk_space_checker.dart"
      provides: "hand-rolled platform channel (Android StatFs + iOS NSFileManager)"
      contains: "MethodChannel"
    - path: "lib/infrastructure/platform/ios_backup_excluder.dart"
      provides: "NSURLIsExcludedFromBackupKey setter via platform channel"
      contains: "NSURLIsExcludedFromBackupKey"
    - path: "ios/Runner/DiskSpaceChannel.swift"
      provides: "iOS native side of disk-space channel"
    - path: "android/app/src/main/kotlin/app/gosl/mirkfall/DiskSpaceChannel.kt"
      provides: "Android native side of disk-space channel"
  key_links:
    - from: "lib/infrastructure/map/pmtiles_source.dart"
      to: "lib/domain/installed_maps/installed_manifest.dart"
      via: "PmtilesSource reads installed manifest to decide URI target"
      pattern: "InstalledManifest"
    - from: "lib/infrastructure/map/maplibre_map_view.dart"
      to: "lib/domain/map/map_view.dart"
      via: "concrete adapter implements the pure-Dart MapView interface"
      pattern: "implements MapView"
    - from: "lib/infrastructure/map/first_launch_world_copier.dart"
      to: "lib/config/world_bundle_sha256.dart"
      via: "expectedSha256 constant compared against the copied file"
      pattern: "kWorldBundleSha256"
    - from: "lib/infrastructure/platform/disk_space_checker.dart"
      to: "android/app/src/main/kotlin/app/gosl/mirkfall/DiskSpaceChannel.kt"
      via: "MethodChannel('app.gosl.mirkfall/disk_space')"
      pattern: "app.gosl.mirkfall/disk_space"
---

<objective>
Land the MapLibre-bound infrastructure: the adapter that implements the `MapView` port, the PmtilesSource seam (local-only), the style rewriter, the country resolver, the first-launch world copier, the no-op MirkRenderer, and two hand-rolled platform channels (disk-space + iOS backup-exclude). This plan is the ONLY allowed location for `package:maplibre_gl` imports — enforced by the lint gate from Plan 07-01.

Purpose: Close RESEARCH Open Questions #1 (camera preservation), #2 (source swap mechanism), #3 (iOS backup exclude), #6 (hand-roll disk space). Satisfies MAP-01 (local pmtiles), MAP-03 (attribution hook point), MAP-04 (layer order), MAP-05 (PmtilesSource seam), MAP-06 (MapView adapter), MAP-07 (first-launch world copy).
Output: A compiling infrastructure subtree where downstream controllers (07-05) and screens (07-06) consume only the `MapView` port, leaving maplibre_gl types sealed inside `lib/infrastructure/map/`.
</objective>

<execution_context>
@C:/Users/oliver/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/oliver/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-map-integration/07-CONTEXT.md
@.planning/phases/07-map-integration/07-RESEARCH.md
@.planning/phases/07-map-integration/07-01-SUMMARY.md
@.planning/phases/07-map-integration/07-02-SUMMARY.md
@CLAUDE.md
@lib/config/constants.dart
@lib/config/world_bundle_sha256.dart
@lib/infrastructure/README.md
@lib/infrastructure/notifications/session_notification_service.dart
@lib/infrastructure/platform/
@android/app/src/main/kotlin/app/gosl/mirkfall/MainActivity.kt
@ios/Runner/AppDelegate.swift
@tool/check_avoid_maplibre_leak.dart
@tool/check_avoid_remote_pmtiles.dart

<interfaces>
<!-- Key types consumed from Plans 07-01 + 07-02 -->

From `lib/domain/map/map_view.dart`:
```dart
abstract class MapView {
  Future<void> showMap(CountryCode? country);
  Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom});
  Future<void> setTheme(MapTheme theme);
  Future<void> setUserLocation(Fix? fix);
  Future<({double latitude, double longitude, double zoom})> queryViewport();
  Stream<({double latitude, double longitude, double zoom})> get viewportUpdates;
  Future<void> markVisited(List<({double latitude, double longitude})> polygon);
  Future<void> addPointOfInterest({required String id, required double latitude, required double longitude, required String iconId});
  Future<void> removePointOfInterest(String id);
  bool get isFollowMeEnabled;
  Future<void> setFollowMeEnabled(bool enabled);
  Future<void> dispose();
}
```

From `lib/domain/installed_maps/installed_manifest.dart`:
```dart
abstract class InstalledManifestRepository {
  Future<InstalledManifest> read();
  Future<void> write(InstalledManifest manifest);
  Stream<InstalledManifest> get updates;
}
class InstalledCountry {
  CountryCode alpha3;
  String filePath; // relative to appSupportDir, e.g. 'countries/fra.pmtiles'
  // ...
}
```

From `lib/domain/mirk/mirk_renderer.dart`:
```dart
abstract class MirkRenderer {
  void paint(Canvas canvas, Size size, MirkPaintContext context);
  void update(Duration elapsed);
  Future<void> dispose();
}
```

From `lib/config/constants.dart` (Plan 07-01):
```dart
const String kMapCatalogAssetPath = 'assets/maps/catalog.json';
const String kWorldPmtilesAssetPath = 'assets/maps/world.pmtiles';
const String kWorldPmtilesInternalPath = 'maps/world.pmtiles';
const String kCountriesDir = 'maps/countries';
const String kStagingDir = 'maps/staging';
const String kInstalledManifestPath = 'maps/installed.json';
const String kStyleJsonAssetPath = 'assets/maps/style.json';
const int kInitialSessionMapZoom = 13;
const double kDiskSpaceSafetyMarginMultiplier = 1.1;
```

From `lib/config/world_bundle_sha256.dart`:
```dart
const String kWorldBundleSha256 = '<hex>'; // generated Plan 07-01
```

MethodChannel pattern established Phase 05 `boot_completed_watchdog.dart`:
```dart
const MethodChannel _channel = MethodChannel('app.gosl.mirkfall/boot_watchdog');
// Triple-source truth: Dart + Kotlin + Swift coordinate on the channel name
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: PmtilesSource + StyleRewriter + StyleLayerOrder + CountryResolver + PointInPolygon + FirstLaunchWorldCopier + NoopMirkRenderer</name>
  <files>
    lib/infrastructure/map/pmtiles_source.dart,
    lib/infrastructure/map/style_rewriter.dart,
    lib/infrastructure/map/style_layer_order.dart,
    lib/infrastructure/map/country_resolver.dart,
    lib/infrastructure/map/first_launch_world_copier.dart,
    lib/infrastructure/map/geo/point_in_polygon.dart,
    lib/infrastructure/map/README.md,
    lib/infrastructure/mirk/noop_mirk_renderer.dart,
    lib/infrastructure/mirk/README.md,
    test/infrastructure/map/pmtiles_source_test.dart,
    test/infrastructure/map/style_rewriter_test.dart,
    test/infrastructure/map/style_layer_order_test.dart,
    test/infrastructure/map/country_resolver_test.dart,
    test/infrastructure/map/first_launch_world_copier_test.dart,
    test/infrastructure/map/geo/point_in_polygon_test.dart,
    test/infrastructure/mirk/noop_mirk_renderer_test.dart
  </files>
  <behavior>
    - **`localPmtilesUri(String absolutePath)`** free function: returns `'pmtiles://file://${absolutePath.startsWith('/') ? absolutePath : '/' + absolutePath}'`. Normalises backslashes to forward slashes first. Never emits `pmtiles://http`. Tested for POSIX (`/var/foo.pmtiles`), Windows absolute (`C:\foo\bar.pmtiles`), edge (`/with spaces/bar.pmtiles`).
    - **`PmtilesSource`** class:
      - Ctor: `PmtilesSource({required InstalledManifestRepository installedManifestPort, required String appSupportDir})`
      - `Future<String> forCountry(CountryCode? code)` — world if null, installed if found, world fallback if code unknown. Reads manifest lazily (awaiting `read()`).
      - Sync variant `String forCountryOrWorld(CountryCode? code, InstalledManifest snapshot)` for hot paths where snapshot already fetched.
      - World filename resolved via `p.join(appSupportDir, kWorldPmtilesInternalPath)`.
    - **`StyleRewriter`**:
      - Ctor: `StyleRewriter(this._pmtilesSource)`
      - `Future<String> rewriteStyleForCountry(CountryCode? activeCountry)`:
        - Loads `assets/maps/style.json` via `rootBundle.loadString(kStyleJsonAssetPath)` (requires flutter_test binding for unit tests)
        - Verifies the literal `pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER` exists (else throw `MapStyleCorruptException`)
        - Substitutes via `replaceFirst`
        - Returns the full JSON string (NOT parsed Map — maplibre_gl.setStyle accepts raw JSON string)
    - **`styleLayerOrder`** constant + `assertStyleLayerOrder(String styleJson)` helper:
      - const `kStyleLayerOrder = <String>['background', 'landcover', 'water', 'boundaries', 'roads', 'pois', 'mirk_fog', 'user_location']`
      - Helper parses the JSON, extracts `layers[].id`, asserts equality against `kStyleLayerOrder`. Throws `MapStyleCorruptException` on mismatch.
    - **`CountryResolver`** pure-Dart:
      - Ctor: `CountryResolver({required Map<CountryCode, List<List<({double lat, double lon})>>> installedPolygons})` (map from alpha3 to list of polygon rings in lat/lon)
      - `CountryCode? resolve({required double latitude, required double longitude, required double zoom})`:
        - If `zoom < 3` → return `null` (world fallback)
        - For each installed polygon, run `pointInPolygon` (hand-rolled ray-casting)
        - Return first matching alpha3 or `null`
      - `Stream<CountryCode?> resolveForViewportUpdates(Stream<(double lat, double lon, double zoom)>)` optional convenience (debounced 500 ms)
    - **`pointInPolygon({required double lat, required double lon, required List<({double lat, double lon})> ring})`** — hand-rolled ray-casting (Rosetta Code reference, ~40 lines):
      - Given a simple polygon (not self-intersecting), returns bool
      - Handles holes? NO — Phase 07 GeoJSON are simple exteriors only (aggregate polygons.json can carry multi-polygon by using multiple ring entries per alpha3)
      - Tested exhaustively with 20+ cases: Paris-in-FRA, Berlin-in-DEU, Madrid-in-ESP, London-in-GBR, NYC-in-USA, mid-Atlantic-false, antimeridian-boundary, equator-crossing
    - **`FirstLaunchWorldCopier`**:
      - Ctor: `FirstLaunchWorldCopier({required String appSupportDir, String expectedSha256 = kWorldBundleSha256})`
      - `Future<void> ensureInstalled()`:
        - If target file exists + sha256 matches → return (healthy)
        - Else: delete target if exists, load asset via `rootBundle.load(kWorldPmtilesAssetPath)`, write to target via streamed sink (not `writeAsBytes` on 856 KB — even though it's small, establish the streaming pattern here for Plan 07-04 consistency)
        - Post-copy sha256 recomputed → if mismatch throw `MapAssetMissingException`
      - Budget: <1 s on first launch (856 KB).
    - **`NoopMirkRenderer`** implements `MirkRenderer`:
      - `paint(Canvas c, Size s, MirkPaintContext ctx)` — `return;` (empty)
      - `update(Duration d)` — `return;`
      - `dispose()` — `return Future.value();`
      - Tested: 100 iterations of paint/update don't throw, dispose returns completed future.
  </behavior>
  <action>
    1. **`lib/infrastructure/map/README.md`**: "The ONLY directory allowed to `import 'package:maplibre_gl/...'`. Enforced by `tool/check_avoid_maplibre_leak.dart`. All other `lib/` code must consume the `MapView` port (`lib/domain/map/map_view.dart`)."

    2. **`lib/infrastructure/map/pmtiles_source.dart`**:
       - GOSL header
       - Top-level free function `localPmtilesUri(String)` documented + unit-tested in `pmtiles_source_test.dart`
       - `PmtilesSource` class with async + sync lookup variants
       - Uses `package:path/path.dart` as `p` for `p.join`. Does NOT import `package:maplibre_gl/...` (this file doesn't need it — it just produces strings).

    3. **`lib/infrastructure/map/style_rewriter.dart`**: per behavior spec. Imports `package:flutter/services.dart` (`rootBundle`) — OK, it's inside infrastructure. Does NOT import maplibre_gl.

    4. **`lib/infrastructure/map/style_layer_order.dart`**: const list + helper. Pure Dart. Unit test reads the real `assets/maps/style.json` via flutter_test rootBundle and asserts exact equality.

    5. **`lib/infrastructure/map/geo/point_in_polygon.dart`**:
       - Pure-Dart function. ~40 lines. Rosetta Code reference implementation. Handles horizontal edges via consistent convention (exclusive-upper-bound).
       - Exhaustive unit tests: simple square, L-shape, degenerate point-on-edge, antimeridian edge.

    6. **`lib/infrastructure/map/country_resolver.dart`**:
       - Ctor takes pre-parsed polygon map. Parsing from asset GeoJSON is a separate `CountryPolygonLoader` helper in same file (loads `assets/maps/polygons/*.geo.json` or aggregate).
       - Polygon loader: `Future<Map<CountryCode, List<List<({double lat, double lon})>>>> loadPolygonsFromAssets()` reads via rootBundle.
       - Tests: 5 country fixtures (from Plan 07-01 `test/fixtures/polygons/`) + 15 lat/lon test cases.

    7. **`lib/infrastructure/map/first_launch_world_copier.dart`**:
       - Implementation per behavior. Streamed copy via `rootBundle.load` → `Uint8List` → `File.openWrite` sink.
       - Tests: idempotent (second call is cheap, no rewrite if healthy), auto-heal (seed a corrupted file, assert rewrite).
       - Test harness uses `Directory.systemTemp` for `appSupportDir` override. Uses `flutter_test` to access rootBundle.

    8. **`lib/infrastructure/mirk/noop_mirk_renderer.dart`**: 3-method impl, ~15 lines. Unit test asserts trivial operation.

    9. Every file: GOSL header. `flutter analyze --fatal-infos` clean. `tool/check_avoid_maplibre_leak.dart` still exits 0 (none of these files import maplibre_gl yet — Task 2 is the first one that does).
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos lib/infrastructure/map/ lib/infrastructure/mirk/ test/infrastructure/map/ test/infrastructure/mirk/ &&
      flutter test test/infrastructure/map/ test/infrastructure/mirk/ &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_avoid_remote_pmtiles.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    Infrastructure-map + infrastructure-mirk subtrees compile + test-green. No maplibre_gl imports yet (Task 2 adds them). PmtilesSource returns only local URIs. Country resolver passes 15+ lat/lon tests. World copier is idempotent + auto-heals. style.json layer order verified matches frozen constant.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: MapLibreMapView adapter (the ONLY maplibre_gl consumer) — solves Open Q #1 + #2</name>
  <files>
    lib/infrastructure/map/maplibre_map_view.dart
  </files>
  <behavior>
    - `lib/infrastructure/map/maplibre_map_view.dart` is the ONLY file under `lib/` that imports `package:maplibre_gl/maplibre_gl.dart`.
    - `MapLibreMapViewWidget extends StatefulWidget`:
      - Constructor: `MapLibreMapViewWidget({required StyleRewriter styleRewriter, required PmtilesSource pmtilesSource, required ValueChanged<MapView> onReady, CountryCode? initialCountry})`
      - Builds `MapLibreMap` with `styleString: <await rewriteStyleForCountry(initialCountry)>` resolved in initState
      - `onMapCreated` captures the controller; `onStyleLoadedCallback` constructs `_MapLibreMapViewAdapter(controller, styleRewriter, pmtilesSource)` and invokes `onReady(adapter)`
      - Custom attribution: pass `attributionButtonMargins: const Point(-100, -100)` to hide MapLibre's default; Phase 07 UI (07-06) paints its own widget
    - `_MapLibreMapViewAdapter implements MapView`:
      - Wraps `MapLibreMapController _controller` privately
      - **Open Question #1 resolution** (camera preservation): `showMap(CountryCode? country)`:
        1. Capture camera via `final CameraPosition prev = await _controller.cameraPosition ?? const CameraPosition(target: LatLng(0, 0), zoom: 2);`
        2. Build rewritten style via `styleRewriter.rewriteStyleForCountry(country)`
        3. Call `await _controller.setStyle(rewritten)`
        4. After `setStyle` resolves, re-apply camera: `await _controller.moveCamera(CameraUpdate.newCameraPosition(prev))`
        5. Log both before/after positions at INFO level for debug observability.
      - **Open Question #2 resolution**: the FIRST call to `showMap` in session uses `setStyle` (carries the layer skeleton). SUBSEQUENT calls with different country but same style skeleton use `removeSource('mirkfall_map') + addSource('mirkfall_map', VectorSourceProperties(url: <pmtilesUri>))` to avoid full style re-parse. Fall-back branch: if `VectorSourceProperties(url:…)` doesn't accept `pmtiles://` prefix in maplibre_gl 0.25.0 (determined at compile time), fall back to full `setStyle`. Both paths are tested by FakeMapView widget assertions (the adapter itself is harder to unit-test; integration test in 07-07).
      - Every `MapView` method: `moveCameraTo`, `setTheme` (0.25 only supports setTheme→setStyle round-trip), `setUserLocation` (adds/updates a SymbolAnnotation), `queryViewport` (returns controller.cameraPosition as record), `viewportUpdates` (hooked via `_controller.addListener` into a broadcast StreamController), `markVisited` (Phase 09 stub — records polygon in memory, no visual change), `addPointOfInterest` (Phase 11 stub — adds a SymbolAnnotation but doesn't render icons yet), `removePointOfInterest` (removes SymbolAnnotation), `setFollowMeEnabled` (toggles the internal flag; the adapter doesn't auto-pan — `MapCameraController` in Plan 07-05 orchestrates).
    - Verify Open Question #2 compile-time: if `VectorSourceProperties` does not exist or doesn't accept `url`, use `controller.addSourceVector(SourceOptions...)` (exact API name TBD); if neither works, fall back to setStyle-only path and note in SUMMARY.
    - Do NOT `dispose` the broadcast controller on widget disposal without draining listeners — subscribers must explicitly `cancel`. Document in class-level docstring.
    - Platform-view rebuild guard (RESEARCH Pitfall #9): wrap `MapLibreMap` in `KeyedSubtree(key: const ValueKey('mirkfall_map_view'), child: MapLibreMap(…))` to protect against parent-key churn flashing the platform view.
  </behavior>
  <action>
    1. Create `lib/infrastructure/map/maplibre_map_view.dart` with GOSL header + single `import 'package:maplibre_gl/maplibre_gl.dart';` + imports of domain types + `package:flutter/widgets.dart` + `package:logging/logging.dart`.

    2. Implement `MapLibreMapViewWidget` as described. Use `FutureBuilder` inside `build` OR `initState + ValueNotifier<String?>` for async style loading — choose the pattern that avoids platform-view rebuild (pre-compute the styleString before the widget is rendered).

    3. Implement `_MapLibreMapViewAdapter` with all 12 MapView methods.

    4. Resolve Open Q #1 + #2 per behavior. Do the compile-time probe for Q#2 (try `addSource(VectorSourceProperties(url: ...))` first; fall back if the signature doesn't match).

    5. Add logging: `final Logger _log = Logger('infrastructure.map.maplibre');`. Info log on every setStyle + source swap with before/after camera.

    6. No unit test at this layer (the adapter is widget-bound; widget tests are in 07-06 via `FakeMapView`). Document the gap: "Real adapter coverage comes from the integration_test/ suite in 07-07."

    7. Run `dart run tool/check_avoid_maplibre_leak.dart` — should STILL exit 0 because this file is inside `lib/infrastructure/map/` (the allowed directory).

    8. Run `flutter analyze` — MUST be clean. Warnings about missing coverage in this adapter are acceptable (Plan 07-07 tests it).

    9. Commit.
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos lib/infrastructure/map/maplibre_map_view.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_avoid_remote_pmtiles.dart
    </automated>
  </verify>
  <done>
    `lib/infrastructure/map/maplibre_map_view.dart` compiles + is the sole maplibre_gl consumer in `lib/`. Open Q #1 (camera preservation) and Q #2 (source swap path) both implemented with fall-back logic. Lint gates green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Hand-rolled DiskSpaceChecker platform channel (Android StatFs + iOS NSFileManager) + IosBackupExcluder platform channel</name>
  <files>
    lib/infrastructure/platform/disk_space_checker.dart,
    lib/infrastructure/platform/ios_backup_excluder.dart,
    android/app/src/main/kotlin/app/gosl/mirkfall/DiskSpaceChannel.kt,
    android/app/src/main/kotlin/app/gosl/mirkfall/MainActivity.kt,
    ios/Runner/DiskSpaceChannel.swift,
    ios/Runner/IosBackupExcluderChannel.swift,
    ios/Runner/AppDelegate.swift,
    test/infrastructure/platform/disk_space_checker_test.dart
  </files>
  <behavior>
    - **`DiskSpaceChecker`** Dart:
      - Channel constant: `MethodChannel('app.gosl.mirkfall/disk_space')`
      - `Future<int> freeBytes({required String path})` — returns free bytes at `path`. Android: StatFs. iOS: NSFileManager.attributesOfFileSystem(forPath:).
      - Timeout: 5 s via `Future.timeout(Duration(seconds: 5))` around `invokeMethod`.
      - Exceptions: wraps native errors into `DiskSpaceCheckException` (new typed exception added here or in Plan 07-02 if we missed it — if missed, defer to a future fix commit; the simplest path is to add it here as `implements Exception` in the platform/ dir).
    - **Android Kotlin** `DiskSpaceChannel.kt`:
      - Singleton `object DiskSpaceChannel`
      - `fun register(messenger: BinaryMessenger)` registers the MethodChannel
      - `onMethodCall`: for `"freeBytes"` expect `Map<String, Any>{"path": String}`; compute `android.os.StatFs(path).availableBytes.toLong()`; return via `result.success(bytes)`; catch IOException → `result.error("IO_ERROR", …, …)`
    - **`MainActivity.kt`**: register `DiskSpaceChannel.register(flutterEngine.dartExecutor.binaryMessenger)` in `onCreate`/`configureFlutterEngine`. Also leave Phase 05 boot_watchdog registration untouched.
    - **iOS Swift** `DiskSpaceChannel.swift`:
      - `class DiskSpaceChannel` with static `register(with registrar: FlutterPluginRegistrar)`
      - `handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)`: for `"freeBytes"` unwrap args, call `FileManager.default.attributesOfFileSystem(forPath: path)` → read `FileAttributeKey.systemFreeSize` → return as Int.
    - **`AppDelegate.swift`**: register `DiskSpaceChannel.register(…)` + `IosBackupExcluderChannel.register(…)` in `application(_:didFinishLaunchingWithOptions:)`. Do NOT touch Phase 05 boot_watchdog registration.
    - **`IosBackupExcluder`** Dart + `IosBackupExcluderChannel.swift`:
      - Channel: `MethodChannel('app.gosl.mirkfall/ios_backup_excluder')`
      - `Future<void> excludePath(String filename)` — calls `invokeMethod('excludeFromBackup', {'path': filename})` on iOS; no-op on Android.
      - Swift side: `URL(fileURLWithPath: path).setResourceValues(…)` with `URLResourceValues(isExcludedFromBackup: true)` — closes RESEARCH Open Question #3.
    - **Tests**:
      - `test/infrastructure/platform/disk_space_checker_test.dart`:
        - Mock platform channel via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`
        - Assert `freeBytes({path: '/fake'})` returns the handler's emit value
        - Assert timeout produces `TimeoutException` after 5 s
        - Assert handler error → `DiskSpaceCheckException`
      - No unit test for `IosBackupExcluder` (the no-op on Android branch is trivial; the iOS path is manually verified via a device smoke in 07-07).
  </behavior>
  <action>
    1. **Dart side** both platform channels with typed surfaces.

    2. **Android Kotlin**: create DiskSpaceChannel.kt, wire in MainActivity. Respect existing Phase 05 boot_watchdog registration.

    3. **iOS Swift**: create DiskSpaceChannel.swift + IosBackupExcluderChannel.swift, wire in AppDelegate.swift. Respect existing Phase 05 app-lifecycle hooks.

    4. **`tool/check_platform_manifests.dart`** — if Phase 06 added a required-channels list, append the two new channel names. Update paired test. If no such list exists, skip this step.

    5. **Test** disk space checker via mock platform channel. Use the Phase 05 `test/fakes/fake_local_notifications_port.dart` structure as reference (mock method-call handler pattern).

    6. **Verify**: `flutter analyze`, `dart run tool/check_headers.dart`, `flutter test test/infrastructure/platform/`, `dart run tool/check_platform_manifests.dart` — all 0.

    7. Document in SUMMARY: decision to hand-roll disk-space per RESEARCH §Don't Hand-Roll (Open Question #6 closed).

    8. Commit.
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos lib/infrastructure/platform/ &&
      flutter test test/infrastructure/platform/disk_space_checker_test.dart &&
      dart run tool/check_headers.dart &&
      dart run tool/check_platform_manifests.dart
    </automated>
  </verify>
  <done>
    DiskSpaceChecker Dart + Kotlin + Swift native sides work. IosBackupExcluder Dart + Swift native side works. Triple-source channel constant coordination verified. Mock-channel unit test green. CI platform-manifests gate still green.
  </done>
</task>

</tasks>

<verification>
```
dart run build_runner build --delete-conflicting-outputs &&
flutter analyze --fatal-infos --fatal-warnings &&
flutter test test/infrastructure/map/ test/infrastructure/mirk/ test/infrastructure/platform/ &&
dart run tool/check_domain_purity.dart &&
dart run tool/check_avoid_maplibre_leak.dart &&
dart run tool/check_avoid_remote_pmtiles.dart &&
dart run tool/check_headers.dart &&
dart run tool/check_platform_manifests.dart
```

All steps MUST exit 0. The `check_avoid_maplibre_leak.dart` gate specifically validates that ONLY `lib/infrastructure/map/maplibre_map_view.dart` imports `package:maplibre_gl/`.
</verification>

<success_criteria>
- `lib/infrastructure/map/` contains 7 files (PmtilesSource, StyleRewriter, StyleLayerOrder, CountryResolver, FirstLaunchWorldCopier, MapLibreMapView, point_in_polygon geo helper) + README
- `lib/infrastructure/mirk/` contains NoopMirkRenderer + README
- `lib/infrastructure/platform/` contains DiskSpaceChecker + IosBackupExcluder (both hand-rolled)
- Open Questions #1 (camera preservation), #2 (source swap), #3 (iOS backup exclude), #6 (hand-roll disk space) all closed with documented decisions
- Country resolver passes 15+ lat/lon unit tests
- FirstLaunchWorldCopier is idempotent + auto-heals on sha256 mismatch
- Every `maplibre_gl` import lives inside `lib/infrastructure/map/` — lint gate green
- Style layer order frozen (8 layers) + regression-guarded unit test green
</success_criteria>

<output>
After completion, create `.planning/phases/07-map-integration/07-03-SUMMARY.md`:
- Open Question #2 resolution: which API branch (removeSource+addSource VS setStyle) the adapter uses — and whether maplibre_gl 0.25.0 `VectorSourceProperties(url: pmtilesUri)` was supported or not
- Open Question #3 resolution: iOS backup-exclude channel wired + first invocation is from Plan 07-05 (MapCameraController? InstalledMapsController?) — document which downstream plan attaches it
- Native code additions (Kotlin + Swift file paths + line counts)
- MainActivity.kt / AppDelegate.swift delta (before/after diff summary)
- Any unexpected maplibre_gl 0.25.0 API quirks encountered
- Commit hashes
</output>

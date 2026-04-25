// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../fixes/fix.dart';
import '../mirk/mirk_viewport_bbox.dart';
import 'country_code.dart';
import 'map_theme.dart';

/// Domain-level map port — the single abstraction over every map-rendering
/// implementation MirkFall might use (MapLibre today, Mapbox or a custom
/// WebGL renderer tomorrow). See CONTEXT.md §MapView seam.
///
/// Every signature is expressed in **MirkFall vocabulary** only. No
/// MapLibre types (`MapLibreMapController`, `SymbolOptions`,
/// `CameraUpdate`, `LatLng`) are visible — they stay behind
/// `lib/infrastructure/map/` where the concrete adapter lives. The
/// `tool/check_avoid_maplibre_leak.dart` CI gate enforces this invariant
/// at lint time.
///
/// Implementation contract:
/// - Every method completes its returned [Future] exactly once, even on
///   error.
/// - Methods MAY be called before [showMap]; implementations ignore
///   [moveCameraTo] / [setUserLocation] / etc. when no map surface is
///   attached rather than throwing — tests against the [MapView] interface
///   frequently exercise happy-path scenarios without a real render
///   surface.
/// - [dispose] is idempotent — calling twice is a no-op on the second
///   call, not an exception.
abstract class MapView {
  /// Switches the displayed map to [country]'s PMTiles bundle, or the
  /// bundled world basemap when [country] is `null`.
  ///
  /// Implementations replace the active source + style layers in one
  /// transaction; layer order stays frozen (see Plan 07-01 style.json).
  Future<void> showMap(CountryCode? country);

  /// Pans + zooms the camera to the given geographic target with an
  /// implementation-chosen animation curve (smooth fly-to).
  /// Latitude in [-90, 90]; longitude in [-180, 180]; zoom in
  /// [0, ~22] (implementation dependent).
  ///
  /// Use [jumpCameraTo] instead when the call happens synchronously
  /// inside or right after an `onStyleLoaded`-equivalent hook: at that
  /// point some renderers (MapLibre Native iOS 6.14.0 via
  /// `maplibre_gl` 0.25.0) throw a native C++ exception if their
  /// animator is instantiated before the render loop has committed
  /// the freshly-loaded style. See Phase 07-07 device-smoke
  /// Runner-2026-04-22-122719.ips bisection.
  Future<void> moveCameraTo({
    required double latitude,
    required double longitude,
    required double zoom,
  });

  /// Same as [moveCameraTo] but WITHOUT animation — the camera jumps
  /// to the target instantly. Safe to call right after an
  /// onStyleLoaded-equivalent hook (the bug path described on
  /// [moveCameraTo] only affects the animator path).
  ///
  /// Expect callers to prefer this for "first positioning" flows
  /// (open-map with active session, deep-link landing, etc.) where
  /// the motion would be a single frame anyway and any animation is
  /// wasted effort.
  Future<void> jumpCameraTo({
    required double latitude,
    required double longitude,
    required double zoom,
  });

  /// Swaps the rendering theme (see [MapTheme]). Implementations keep the
  /// current camera + sources intact; only visual styles change.
  Future<void> setTheme(MapTheme theme);

  /// Updates the user-location indicator. `null` hides the indicator
  /// (e.g. when the active session has no fixes yet or when tracking is
  /// off). See [Fix] for the domain payload.
  Future<void> setUserLocation(Fix? fix);

  /// Reads the current viewport (camera center + zoom). Used by the
  /// country resolver (Plan 07-03) to pick a PMTiles source based on the
  /// viewport center.
  Future<({double latitude, double longitude, double zoom})> queryViewport();

  /// Returns the current viewport bounds in lat/lon as a
  /// [MirkViewportBbox] (Phase 09 plan 09-07 Task 1).
  ///
  /// Phase 09 consumers need the full bbox (not just the centre from
  /// [queryViewport]) to compute which parent tiles intersect the
  /// viewport. The implementation queries MapLibre-native
  /// `LatLngBounds` and adapts to the MapLibre-free [MirkViewportBbox]
  /// at the platform boundary (MAP-06 seam discipline).
  ///
  /// Implementations MAY throw or return an out-of-range value if the
  /// adapter's MapLibre surface is not loaded yet. Callers that
  /// subscribe before the first style-loaded callback are expected to
  /// retry on the next [viewportUpdates] event.
  Future<MirkViewportBbox> queryViewportBounds();

  /// Broadcast stream of viewport updates (camera idle events). Every
  /// camera-move gesture emits exactly one event once the camera settles.
  /// Implementations MAY debounce; subscribers should not assume
  /// per-frame resolution.
  Stream<({double latitude, double longitude, double zoom})>
  get viewportUpdates;

  /// Marks [polygon] as visited — Phase 09+ fog-of-war integration point.
  /// Stubbed in Phase 07 so later renderers can plumb through without
  /// reshaping the MapView surface.
  Future<void> markVisited(List<({double latitude, double longitude})> polygon);

  /// Adds / updates a point of interest keyed by [id]. Idempotent: calling
  /// twice with the same [id] replaces the existing marker. Phase 11+
  /// marker integration point.
  Future<void> addPointOfInterest({
    required String id,
    required double latitude,
    required double longitude,
    required String iconId,
  });

  /// Removes a point of interest by [id]. No-op when [id] is unknown.
  Future<void> removePointOfInterest(String id);

  /// Tears down the map surface, cancels listeners, flushes pending
  /// camera moves. Idempotent — safe to call multiple times.
  Future<void> dispose();

  /// True when the camera automatically follows the user's location.
  /// Read-only on the port; mutated via [setFollowMeEnabled].
  bool get isFollowMeEnabled;

  /// Enables or disables follow-me camera behaviour. When enabled, the
  /// adapter subscribes to fix updates + issues [moveCameraTo] per fix;
  /// when disabled, the camera stays wherever the user last panned to.
  Future<void> setFollowMeEnabled(bool enabled);
}

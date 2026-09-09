// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../fixes/fix.dart';
import '../mirk/mirk_viewport_bbox.dart';
import 'country_code.dart';
import 'map_theme.dart';

/// Domain-level map port — the single abstraction over every map-rendering
/// implementation MirkFall might use (flutter_map 7.0.2 today, another
/// engine tomorrow). See CONTEXT.md §MapView seam.
///
/// Every signature is expressed in **MirkFall vocabulary** only. No
/// engine type (`MapController`, `MapCamera`, `LatLng`, `VectorTileLayer`)
/// is visible — they stay behind `lib/infrastructure/map/` where the
/// concrete adapter lives. The `tool/check_avoid_flutter_map_leak.dart`
/// CI gate (Phase 09.1, MAP-06) enforces this invariant at lint time.
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
  /// Implementations swap the tile provider in one transaction and keep
  /// the camera where it is; the style / layer order stays frozen (see
  /// `kStyleLayerOrder`).
  Future<void> showMap(CountryCode? country);

  /// Moves the camera to the given geographic target. The move is
  /// instantaneous; an animation can be added inside the adapter
  /// without touching the port. Latitude in [-90, 90]; longitude in
  /// [-180, 180]; zoom inside the engine envelope
  /// (`kMapMinZoom`..`kMapMaxZoom`).
  ///
  /// Implementations echo the resulting camera on [viewportUpdates] —
  /// `MapCameraController` relies on that echo to tell its own moves
  /// apart from user pans.
  Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom});

  /// Swaps the rendering theme (see [MapTheme]). Implementations keep the
  /// current camera + sources intact; only visual styles change.
  Future<void> setTheme(MapTheme theme);

  /// Updates the user-location indicator. `null` hides the indicator
  /// (e.g. when the active session has no fixes yet or when tracking is
  /// off). See [Fix] for the domain payload.
  Future<void> setUserLocation(Fix? fix);

  /// Reads the current viewport (camera center + zoom). Used by the
  /// country resolver (Plan 07-03) to pick a PMTiles source based on the
  /// viewport center. Before the first render, implementations return
  /// the initial camera they were constructed with.
  Future<({double latitude, double longitude, double zoom})> queryViewport();

  /// Returns the current viewport bounds in lat/lon as a
  /// [MirkViewportBbox] (Phase 09 plan 09-07 Task 1).
  ///
  /// Phase 09 consumers need the full bbox (not just the centre from
  /// [queryViewport]) to compute which parent tiles intersect the
  /// viewport. The adapter converts the engine's own bounds type into
  /// the engine-free [MirkViewportBbox] at the platform boundary
  /// (MAP-06 seam discipline).
  ///
  /// MAY throw a [StateError] before the first render; the providers
  /// retry on the next [viewportUpdates] event.
  Future<MirkViewportBbox> queryViewportBounds();

  /// Broadcast stream of viewport updates (camera events). Every camera
  /// change — gesture or programmatic — emits at least one event.
  /// Implementations MAY debounce; subscribers should not assume
  /// per-frame resolution.
  Stream<({double latitude, double longitude, double zoom})> get viewportUpdates;

  /// Adds / updates a point of interest keyed by [id]. Idempotent: calling
  /// twice with the same [id] replaces the existing marker. Phase 11+
  /// marker integration point.
  Future<void> addPointOfInterest({required String id, required double latitude, required double longitude, required String iconId});

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

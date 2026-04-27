// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';
import 'dart:ui' as ui show Size;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/offscreen_fog_renderer.dart';

final Logger _log = Logger('presentation.mirk_overlay');

/// Invisible controller widget that pushes fog-of-war images to MapLibre's
/// geo-pinned image source on every tick.
///
/// BUG-014 architectural fix: replaces the previous `CustomPaint` screen-space
/// overlay (which lagged 1-3 frames behind camera motion) with an offscreen
/// PNG render pushed to MapLibre's image source. MapLibre composites the fog
/// in map-space at 60 fps with zero camera lag — the image source tracks the
/// camera natively between updates.
///
/// Lifecycle:
/// * `initState` creates a `Ticker` and starts it. Every tick checks the
///   throttle gate ([kMirkFogMapLayerUpdateIntervalMs]), then renders the fog
///   offscreen via [OffscreenFogRenderer] and pushes the PNG to [MapView].
/// * `build` always returns [SizedBox.shrink] — this widget is purely a
///   side-effect controller with no visible output.
/// * `dispose` tears down the Ticker and removes the fog image source from
///   the map if it was previously added.
///
/// The active renderer is owned by `activeMirkRendererProvider`
/// (via `ref.onDispose`) — this widget is NOT responsible for the renderer's
/// lifecycle.
class MirkOverlay extends ConsumerStatefulWidget {
  const MirkOverlay({super.key});

  @override
  ConsumerState<MirkOverlay> createState() => _MirkOverlayState();
}

class _MirkOverlayState extends ConsumerState<MirkOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _tickerElapsed = Duration.zero;

  /// BUG-012 fix: last known disc list from a successful provider read.
  /// When the viewport changes, the family provider creates a new instance
  /// that starts in `AsyncLoading` (no previous value). Without this
  /// field, the overlay would bail out for one frame on every viewport
  /// update — the fog disappears briefly. By retaining the last successful
  /// disc list, the overlay keeps pushing fog with stale-but-stable data
  /// until the fresh query resolves (typically < 2 ms).
  List<RevealDisc>? _lastKnownDiscs;

  /// BUG-009 follow-up diagnostic — frame counter used to throttle the
  /// per-tick log to roughly once per second (60 Hz Ticker -> log every
  /// 60th tick). Drops the log volume from ~3600/min to ~60/min.
  int _tickCallCount = 0;

  /// BUG-009 follow-up diagnostic — last bail-out reason we INFO-logged so
  /// we can pinpoint which prerequisite was gating the overlay.
  String? _lastBailoutReason;

  /// Tracks whether the fog image source + raster layer have been added to
  /// the MapLibre map. `addFogImageSource` on first render,
  /// `updateFogImageSource` on subsequent renders.
  bool _fogSourceAdded = false;

  /// Elapsed milliseconds of the last successful render push. Used to
  /// throttle updates to [kMirkFogMapLayerUpdateIntervalMs] (~20 fps)
  /// instead of running at the Ticker's native 60 fps.
  int _lastRenderTimeMs = 0;

  /// Guard preventing concurrent offscreen renders. The tick callback is
  /// synchronous but [OffscreenFogRenderer.renderToPng] and the MapView
  /// image source calls are async — without this flag a slow PNG encode
  /// could stack up multiple in-flight renders.
  bool _renderInFlight = false;

  /// Stateless offscreen renderer — all mutable state lives in the
  /// [MirkRenderer] and [MirkPaintContext] passed per frame.
  final OffscreenFogRenderer _offscreenRenderer = const OffscreenFogRenderer();

  /// Reference to the [MapView] used when removing the fog source on
  /// dispose. Captured during the render loop so `dispose` can call
  /// `removeFogImageSource` even if the provider has already been torn down.
  MapView? _lastMapView;

  @override
  void initState() {
    super.initState();
    _log.info('MirkOverlay: initState — Ticker started (BUG-014 image-source mode)');
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _tickerElapsed = elapsed;
    // Throttle: only render when enough time has passed since the last push.
    final int elapsedMs = elapsed.inMilliseconds;
    if (elapsedMs - _lastRenderTimeMs < kMirkFogMapLayerUpdateIntervalMs) {
      return;
    }
    if (_renderInFlight) return;

    _scheduleRender(elapsedMs);
  }

  /// Reads all Riverpod providers, checks prerequisites, and fires the
  /// async render + push pipeline. Called from [_onTick] when the throttle
  /// gate is open and no render is in flight.
  void _scheduleRender(int elapsedMs) {
    // --- read providers (synchronous) ---
    final AsyncValue<MirkRenderer> rendererAsync = ref.read(activeMirkRendererProvider);
    final MirkViewportBbox? viewport = ref.read(mapViewportProvider);
    final ActiveSessionState? sessionState = ref.read(activeSessionControllerProvider).value;
    final double? zoom = ref.read(mapViewportZoomProvider);
    final MapView? mapView = ref.read(mapViewProvider);

    final AsyncValue<List<RevealDisc>> discsAsync = viewport != null
        ? ref.read(discsInViewportProvider(viewport: viewport))
        : const AsyncData<List<RevealDisc>>(<RevealDisc>[]);

    // BUG-009 diagnostic — throttled to ~1 Hz
    if (_tickCallCount == 0) {
      _log.info(
        'tick: first invocation — rendererAsync=${rendererAsync.runtimeType} '
        'discsAsync=${discsAsync.runtimeType} viewport=${viewport != null} '
        'zoom=$zoom mapView=${mapView != null}',
      );
    } else if (_tickCallCount % 60 == 0) {
      _log.fine(
        'tick: rendererAsync=${rendererAsync.runtimeType} '
        'discsAsync=${discsAsync.runtimeType} viewport=${viewport != null} '
        'zoom=$zoom mapView=${mapView != null}',
      );
    }
    _tickCallCount++;

    // BUG-012 fix: cache disc list on success, fall back to stale data on
    // loading transitions.
    if (discsAsync.hasValue) {
      _lastKnownDiscs = discsAsync.value;
    }
    final List<RevealDisc>? effectiveDiscs = discsAsync.hasValue ? discsAsync.value : _lastKnownDiscs;

    // --- prerequisite checks ---
    final String bailoutReason;
    if (!rendererAsync.hasValue) {
      bailoutReason = 'rendererAsync not hasValue (${rendererAsync.runtimeType})';
    } else if (viewport == null) {
      bailoutReason = 'viewport==null';
    } else if (zoom == null) {
      bailoutReason = 'zoom==null';
    } else if (effectiveDiscs == null) {
      bailoutReason = 'discsAsync not hasValue and no cached discs (${discsAsync.runtimeType})';
    } else if (mapView == null) {
      bailoutReason = 'mapView==null';
    } else {
      bailoutReason = 'pushing';
    }
    if (bailoutReason != _lastBailoutReason) {
      _log.info('tick: prerequisite state ${_lastBailoutReason ?? "(initial)"} → $bailoutReason');
      _lastBailoutReason = bailoutReason;
    }
    if (bailoutReason != 'pushing') {
      return;
    }

    final MirkRenderer renderer = rendererAsync.value!;
    final List<RevealDisc> discs = effectiveDiscs!;
    final Tracking? tracking = sessionState is Tracking ? sessionState : null;
    final Fix? currentFix = tracking?.lastFix;

    _lastMapView = mapView;

    final MirkPaintContext paintContext = MirkPaintContext(
      zoomLevel: zoom!,
      // pixelRatio: the offscreen render is in logical pixels at
      // kMirkFogMapLayerResolution — use 1.0 so the renderer paints at
      // 1:1 into the offscreen canvas rather than scaling for device DPR.
      pixelRatio: 1.0,
      sessionElapsed: _tickerElapsed,
      viewportBbox: viewport!,
      discs: discs,
      currentFix: currentFix,
    );

    _renderInFlight = true;
    _lastRenderTimeMs = elapsedMs;

    _renderAndPush(renderer, paintContext, mapView!, viewport).then(
      (_) {
        _renderInFlight = false;
      },
      onError: (Object e, StackTrace st) {
        _renderInFlight = false;
        _log.severe('render-and-push failed', e, st);
      },
    );
  }

  /// Offscreen-renders the fog to PNG and pushes it to MapLibre's image
  /// source. Async — guarded by [_renderInFlight].
  Future<void> _renderAndPush(MirkRenderer renderer, MirkPaintContext paintContext, MapView mapView, MirkViewportBbox viewport) async {
    const double resolution = kMirkFogMapLayerResolution * 1.0;
    const ui.Size renderSize = ui.Size(resolution, resolution);

    final Uint8List? pngBytes = await _offscreenRenderer.renderToPng(renderer: renderer, context: paintContext, size: renderSize);

    if (pngBytes == null) {
      _log.fine('renderToPng returned null — skipping this frame');
      return;
    }

    if (!mounted) return;

    final double south = viewport.south;
    final double west = viewport.west;
    final double north = viewport.north;
    final double east = viewport.east;

    if (!_fogSourceAdded) {
      await mapView.addFogImageSource(south: south, west: west, north: north, east: east, pngBytes: pngBytes);
      _fogSourceAdded = true;
      _log.info(
        'fog image source added to map (${pngBytes.length} bytes, '
        'bounds: S=$south W=$west N=$north E=$east)',
      );
    } else {
      await mapView.updateFogImageSource(south: south, west: west, north: north, east: east, pngBytes: pngBytes);
    }
  }

  @override
  void dispose() {
    _log.info('MirkOverlay: dispose — Ticker stopped');
    _ticker.dispose();

    if (_fogSourceAdded) {
      final MapView? mapView = _lastMapView;
      if (mapView != null) {
        // Fire-and-forget: the map surface may already be tearing down,
        // but removeFogImageSource is idempotent per the MapView contract.
        mapView.removeFogImageSource().catchError((Object e, StackTrace st) {
          _log.warning('removeFogImageSource failed during dispose', e, st);
        });
      }
      _fogSourceAdded = false;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers so Riverpod keeps them alive while this widget is
    // mounted. The actual values are read synchronously in _scheduleRender
    // via ref.read — the watch here is purely for lifecycle subscription.
    ref.watch(activeMirkRendererProvider);
    ref.watch(mapViewportProvider);
    ref.watch(activeSessionControllerProvider);
    ref.watch(mapViewportZoomProvider);
    ref.watch(mapViewProvider);

    final MirkViewportBbox? viewport = ref.watch(mapViewportProvider);
    if (viewport != null) {
      ref.watch(discsInViewportProvider(viewport: viewport));
    }

    // Invisible — this widget is purely a controller that pushes fog images
    // to MapLibre's image source. No Flutter painting occurs here.
    return const SizedBox.shrink();
  }
}

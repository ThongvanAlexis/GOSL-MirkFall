// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/providers/visible_mirk_tiles_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';

/// Stateful Riverpod overlay that hosts the mirk Ticker + CustomPainter.
///
/// Mounted as a sibling of the MapLibre platform view in
/// [`MapScreen`]'s Stack — wrapped in a [RepaintBoundary] (set up by the
/// caller, see plan 09-07 Task 5) so the noise tick does not invalidate
/// the map's display list.
///
/// Lifecycle:
/// * `initState` creates a `Ticker` and starts it. Every `onTick` saves
///   the elapsed Duration and calls `setState` to schedule a repaint.
/// * `build` watches the active renderer + visible-tile list +
///   viewport bbox + zoom. Any of those becoming null (loading, no
///   session, viewport not yet ready) renders an empty `SizedBox.shrink`.
/// * `dispose` releases the Ticker. The active renderer is owned by
///   `activeMirkRendererProvider` (via `ref.onDispose`) — the widget
///   is NOT responsible for the renderer's lifecycle.
///
/// Plan 09-07 Task 2.
class MirkOverlay extends ConsumerStatefulWidget {
  const MirkOverlay({super.key});

  @override
  ConsumerState<MirkOverlay> createState() => _MirkOverlayState();
}

class _MirkOverlayState extends ConsumerState<MirkOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _tickerElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _tickerElapsed = elapsed;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MirkRenderer> rendererAsync = ref.watch(
      activeMirkRendererProvider,
    );
    final tilesAsync = ref.watch(visibleMirkTilesProvider);
    final viewport = ref.watch(mapViewportProvider);
    final sessionState = ref.watch(activeSessionControllerProvider);
    final double? zoom = ref.watch(mapViewportZoomProvider);

    // Bail out cheaply when any prerequisite is not ready. The overlay
    // becomes invisible — the underlying RepaintBoundary keeps the
    // pipeline cold.
    if (!rendererAsync.hasValue ||
        !tilesAsync.hasValue ||
        viewport == null ||
        zoom == null) {
      return const SizedBox.shrink();
    }
    final renderer = rendererAsync.value!;
    final tiles = tilesAsync.value!;
    final Tracking? tracking = sessionState.value is Tracking
        ? sessionState.value as Tracking
        : null;
    final Fix? currentFix = tracking?.lastFix;

    return CustomPaint(
      size: Size.infinite,
      painter: _MirkPainter(
        renderer: renderer,
        paintContext: MirkPaintContext(
          zoomLevel: zoom,
          pixelRatio: MediaQuery.of(context).devicePixelRatio,
          // Ticker.elapsed measures time since the overlay mounted, which
          // is operationally aligned with "time since session started"
          // for the noise-based renderers' animation phase. The Phase 09
          // research consolidated on a single `sessionElapsed` field
          // rather than a separate per-frame Ticker time — see plan
          // 09-02 SUMMARY for the rationale.
          sessionElapsed: _tickerElapsed,
          viewportBbox: viewport,
          visibleTiles: tiles,
          currentFix: currentFix,
        ),
      ),
    );
  }
}

class _MirkPainter extends CustomPainter {
  _MirkPainter({required this.renderer, required this.paintContext});

  final MirkRenderer renderer;
  final MirkPaintContext paintContext;

  @override
  void paint(Canvas canvas, Size size) =>
      renderer.paint(canvas, size, paintContext);

  /// Always returns true: the Ticker drives the rebuild via setState,
  /// so the painter's repaint signal is gated by the widget tree
  /// already. A more selective predicate would be redundant.
  @override
  bool shouldRepaint(_MirkPainter old) => true;
}

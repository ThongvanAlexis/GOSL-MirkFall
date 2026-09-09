// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — port of the POC `FogLayer` (`mirk-poc-debug` @ 90c9321,
// `lib/presentation/widgets/fog_layer.dart`, 954 lines). Structural difference: the
// MirkFall layer DELEGATES the painting to the injected `MirkRenderer` instead of
// embedding the shader — the painter prepares the frame (translate + clip), builds
// the extended `MirkPaintContext` and calls `renderer.paint`. The shader, the SDF and
// the wisps live behind the renderer seam. This file is one of the three presentation
// files allowed to import flutter_map (`tool/check_avoid_flutter_map_leak.dart`).

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';
import 'package:mirkfall/presentation/widgets/fog_clip_path.dart';

/// Same-canvas fog layer — child (direct or via a `FadeTransition`) of `FlutterMap`.
///
/// Paints the mirk into the SAME canvas as the tile layer, in the same frame,
/// from the same camera snapshot — the architectural cure for BUG-014 (the
/// overlay fog lagging one frame behind the map). Pure widget: everything is
/// constructor-injected (no Riverpod `ref`); the Riverpod connector arrives in
/// plan 09.1-07.
///
/// ## FOG-07 single-MapCamera-snapshot lock (KEYSTONE)
///
/// `MapCamera.of(context)` is called EXACTLY ONCE, in [State.build]. The
/// snapshot is passed by constructor to the painter, which never re-reads the
/// context. Re-reading would re-create BUG-014's white-ellipse symptom (clip
/// path at zoom Z, shader falloff at zoom Z+ε). `fog_layer_camera_snapshot_test`
/// counts the reads through [debugOnCameraRead].
///
/// ## No repaint-boundary widget, no rebuild per frame
///
/// A repaint boundary around the layer would isolate it from the tile layer's
/// repaint and put it one frame behind — BUG-014 re-created inside Flutter.
/// Per-frame repaint goes through a `Ticker` notifying the painter's `repaint:`
/// `Listenable`; the build phase is never involved (no per-frame rebuild).
///
/// ## Invariant 10 — live Stopwatch by reference
///
/// The painter receives the mount `Stopwatch` BY REFERENCE and reads it on
/// every paint. A `Duration` captured at build time would freeze the fog
/// drift between rebuilds (idle-fog animation gate).
class FogLayer extends StatefulWidget {
  /// Creates the layer. Everything is constructor-injected (no Riverpod `ref`).
  const FogLayer({
    super.key,
    required this.renderer,
    required this.discs,
    this.currentFix,
    required this.frameDeltaProbe,
    required this.fogTransformLogger,
    this.isAndroid,
    this.pixelRatio,
  });

  /// Active renderer (`activeMirkRendererProvider` on the connector side).
  /// Owned by its provider — the layer never calls `dispose()` on it.
  final MirkRenderer renderer;

  /// Snapshot of the reveal discs to punch through the fog (Drift provider on
  /// the connector side). Compared by identity in `shouldRepaint`.
  final List<RevealDisc> discs;

  /// Most recent accepted GPS fix (candlelight centre), or `null`.
  final Fix? currentFix;

  /// PERF-07 frame-delta probe — `recordCameraSnapshot()` at the top of build,
  /// `recordFogUniformPopulation()` right before the renderer paints. No-op
  /// unless verbose logging is on.
  final FrameDeltaProbe frameDeltaProbe;

  /// FOG-10 fog-transform rollup logger — one `recordPaint()` per paint. No-op
  /// unless verbose logging is on.
  final FogTransformLogger fogTransformLogger;

  /// Platform flag for the FOG-21 / FOG-23 corrections; `null` →
  /// `Platform.isAndroid`, resolved once in `initState`. Test seam.
  final bool? isAndroid;

  /// Device pixel ratio; `null` → `MediaQuery.devicePixelRatioOf(context)`.
  final double? pixelRatio;

  /// Keystone FOG-07 seam — invoked exactly once per build, right before
  /// `MapCamera.of(context)`. Production: `null`, zero overhead.
  @visibleForTesting
  static void Function()? debugOnCameraRead;

  @override
  State<FogLayer> createState() => _FogLayerState();
}

class _FogLayerState extends State<FogLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final bool _isAndroid;

  /// LIVE mount clock, passed BY REFERENCE to the painter (invariant 10).
  final Stopwatch _wallClockSinceMount = Stopwatch()..start();

  /// Per-frame paint trigger fed by [_ticker]; the painter's `repaint:` Listenable.
  final _Repaint _repaint = _Repaint();

  @override
  void initState() {
    super.initState();
    _isAndroid = widget.isAndroid ?? Platform.isAndroid;
    _ticker = createTicker((_) => _repaint.tick())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FOG-07 LOCK — exactly one MapCamera.of(context) read per build.
    FogLayer.debugOnCameraRead?.call();
    final MapCamera camera = MapCamera.of(context);
    final int cameraSnapshotMicros = widget.frameDeltaProbe.recordCameraSnapshot();
    final double pixelRatio = widget.pixelRatio ?? MediaQuery.devicePixelRatioOf(context);
    return MobileLayerTransformer(
      child: CustomPaint(
        painter: _FogPainter(
          camera: camera,
          discs: widget.discs,
          currentFix: widget.currentFix,
          renderer: widget.renderer,
          wallClock: _wallClockSinceMount,
          pixelRatio: pixelRatio,
          isAndroid: _isAndroid,
          frameDeltaProbe: widget.frameDeltaProbe,
          fogTransformLogger: widget.fogTransformLogger,
          cameraSnapshotMicros: cameraSnapshotMicros,
          repaint: _repaint,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Per-frame paint trigger: the Ticker calls [tick] once per frame; the painter
/// takes this as its `repaint:` Listenable so paint cycles bypass build.
class _Repaint extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Prepares the identity frame and the clip, builds the extended
/// [MirkPaintContext] from the single camera snapshot and delegates the actual
/// painting to the [MirkRenderer]. Order of operations is locked (PORTBACK §5).
class _FogPainter extends CustomPainter {
  _FogPainter({
    required this.camera,
    required this.discs,
    required this.currentFix,
    required this.renderer,
    required this.wallClock,
    required this.pixelRatio,
    required this.isAndroid,
    required this.frameDeltaProbe,
    required this.fogTransformLogger,
    required this.cameraSnapshotMicros,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// THE camera snapshot of this build (FOG-07).
  final MapCamera camera;
  final List<RevealDisc> discs;
  final Fix? currentFix;
  final MirkRenderer renderer;

  /// Live mount clock — read fresh on every paint (invariant 10).
  final Stopwatch wallClock;
  final double pixelRatio;
  final bool isAndroid;
  final FrameDeltaProbe frameDeltaProbe;
  final FogTransformLogger fogTransformLogger;

  /// Probe stamp captured in build right after the camera read (PERF-07).
  final int cameraSnapshotMicros;

  @override
  void paint(Canvas canvas, Size size) {
    // FOG-12 — ONE `getTransform()` read per paint; the same Float64List feeds
    // the translate compensation AND the diagnostic logger (single-snapshot
    // discipline at the matrix level, mirroring FOG-07).
    final Float64List canvasTransform = canvas.getTransform();
    final Offset canvasOffset = Offset(canvasTransform[kCanvasTransformTxIndex], canvasTransform[kCanvasTransformTyIndex]);

    canvas.save();
    // FOG-13 — translate to the identity frame BEFORE any clip / draw, so the
    // whole painter operates in the frame of the sibling CircleLayer puck.
    // `MobileLayerTransformer` applies a non-zero translation under gesture
    // (Walk #2 sustained (+757, +319)); without this, the reveal hole and the
    // rect cover drift from the map. Always called, even at identity, so the
    // call sequence is branchless.
    canvas.translate(-canvasOffset.dx, -canvasOffset.dy);
    // FOG-06 — clip in raw identity-frame coordinates. `canvasOffset` is left
    // at zero on purpose: shifting the path here on top of the translate above
    // double-compensated the hole (03.1-08-FIX, build 8a37bfd regression).
    canvas.clipPath(computeFogClipPath(camera: camera, discs: discs));

    // FOG-23 + FOG-21 — the two Android-only shader corrections, applied ONCE
    // on the raw camera.pixelOrigin (see fog_platform_corrections.dart).
    final PlatformShaderCorrections corrections = applyPlatformShaderCorrections(
      pixelOrigin: (x: camera.pixelOrigin.x, y: camera.pixelOrigin.y),
      isAndroid: isAndroid,
    );
    // FOG-19 — uZoomScale anchors the noise cells to lat/lng across zooms;
    // 1.0 at the reference zoom keeps the sampling bit-identical to the
    // validated build. FOG-18 — pixelOrigin is forwarded RAW (no Dart-side
    // modulo / period: the wrap event itself was the visible snap).
    final double zoomScale = math.pow(_kZoomScaleBase, camera.zoom - kMirkFogReferenceZoom).toDouble();
    // Invariant 10 — read the live clock on EVERY paint.
    final Duration sessionElapsed = Duration(microseconds: wallClock.elapsedMicroseconds);
    final MirkPaintContext paintContext = MirkPaintContext(
      zoomLevel: camera.zoom,
      pixelRatio: pixelRatio,
      sessionElapsed: sessionElapsed,
      viewportBbox: _viewportFromCamera(camera),
      discs: discs,
      currentFix: currentFix,
      pixelOrigin: corrections.pixelOrigin,
      zoomScale: zoomScale,
      sdfRect: corrections.sdfRect,
      canvasOffset: (dx: canvasOffset.dx, dy: canvasOffset.dy),
      projectToScreen: cameraScreenProjector(camera),
      metersToPixels: cameraMetersToPixels(camera),
    );

    // Diagnostics (verbose-only no-ops otherwise) — recorded AFTER the
    // derivation and BEFORE the renderer so the logged tuple is what was forwarded.
    frameDeltaProbe.recordFogUniformPopulation(cameraSnapshotMicros);
    fogTransformLogger.recordPaint(
      canvasTransform: canvasTransform,
      cameraPixelOrigin: camera.pixelOrigin,
      cameraCenter: (latitude: camera.center.latitude, longitude: camera.center.longitude),
      appliedPixelOrigin: corrections.pixelOrigin,
      uResolutionX: size.width,
      uResolutionY: size.height,
      zoom: camera.zoom,
    );

    // The renderer paints `Offset.zero & size` in the identity frame, inside the clip.
    renderer.update(sessionElapsed);
    renderer.paint(canvas, size, paintContext);
    canvas.restore();
  }

  /// Gates whether a NEW painter instance triggers a paint; the `repaint:`
  /// Listenable drives the per-frame redraws. Renderer internals (SDF, wisps)
  /// mutate behind a stable reference and are picked up by the next tick.
  @override
  bool shouldRepaint(_FogPainter oldDelegate) =>
      camera != oldDelegate.camera ||
      !identical(discs, oldDelegate.discs) ||
      renderer != oldDelegate.renderer ||
      currentFix != oldDelegate.currentFix ||
      pixelRatio != oldDelegate.pixelRatio ||
      isAndroid != oldDelegate.isAndroid;
}

/// `camera.visibleBounds` → [MirkViewportBbox] (flutter_map 7.0.2 exposes the
/// four edges as public double fields).
MirkViewportBbox _viewportFromCamera(MapCamera camera) {
  final LatLngBounds bounds = camera.visibleBounds;
  return MirkViewportBbox(south: bounds.south, west: bounds.west, north: bounds.north, east: bounds.east);
}

/// Base of the FOG-19 zoom-scale power: one zoom level doubles the world-pixel
/// density, so `uZoomScale = 2 ^ (zoom - kMirkFogReferenceZoom)`.
const double _kZoomScaleBase = 2.0;

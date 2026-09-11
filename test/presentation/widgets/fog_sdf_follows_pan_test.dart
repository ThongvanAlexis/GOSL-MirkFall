// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 UAT regression (Pixel 6 Pro, build f347eeb — "la zone découverte se décale du
// point bleu quand je pan"). The shader samples the SDF through the platform-static `sdfRect`
// (invariant 9): the texture is assumed to describe the viewport being painted, so an SDF
// that lags the camera is pinned to the SCREEN while the clip hole and the CircleLayer puck
// move with the map. This test drives a continuous pan (camera moved every real 20 ms, the way
// a finger re-arms any gesture-level timer) and measures on every frame how far the SDF the
// shader received lags the live camera, in screen pixels — at DPR 3.5, Android corrections on,
// zoom 16 (≠ reference zoom 13), real-world coordinates (the UAT session's fix in Melun).
// The clip hole is asserted alongside as the control: it tracks the puck on every frame.

import 'dart:async' show Completer;
import 'dart:math' show Point;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/revealed_sdf_builder.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/sdf_cache.dart';
import 'package:mirkfall/infrastructure/mirk/sdf_rebuild_logger.dart';

import '../../_helpers/atmospheric_fog_layer_harness.dart';
import '../../_helpers/fog_layer_test_harness.dart';
import '../../_helpers/recording_fog_shader_renderer.dart';

/// The UAT session's initial fix (device log 20260911_1621.08) — world-pixel magnitudes ~1e7
/// at zoom 16, i.e. the coordinate range the small-number fixtures never reach.
const LatLng kUatCenter = LatLng(48.528644, 2.655185);
const double kUatZoom = 16.0;
const double kUatDevicePixelRatio = 3.5;
const double kUatDiscRadiusMeters = 25.0;

/// Camera step per simulated gesture frame, in logical px (≈ 19 m at zoom 16 / lat 48.5 —
/// above the SdfCache's 1e-4° key quantisation, so every step is a genuine rebuild trigger).
const double kPanStepPx = 12.0;
const int kPanStepCount = 25;

/// Real-time spacing between steps, far below the 200 ms window a gesture-level debounce
/// would need to fire: a moving finger never lets such a timer expire.
const Duration kPanStepRealDelay = Duration(milliseconds: 20);

/// Maximum tolerated lag between the live camera and the viewport the forwarded SDF was built
/// for: one gesture step of build latency, plus one 1e-4° cache-quantisation cell (~11 m ≈ 7 px
/// at zoom 16), plus one step of event-loop slack. An SDF glued to the screen lags by the whole
/// pan instead (~300 px here).
const double kMaxSdfLagPx = 3 * kPanStepPx;

/// [RevealedSdfBuilder] that resolves a fresh 1×1 stub per build and remembers which viewport
/// each image was built for — the only way to ask "which viewport does the SDF the shader
/// received describe?" from outside the renderer.
class _ViewportTaggingSdfBuilder extends RevealedSdfBuilder {
  /// SDF midpoint byte (distance 0) — any value is fine for a 1×1 stub, this one is the
  /// convention of `RevealedSdfBuilder`.
  static const int _kSdfMidpointByte = 128;
  static const int _kOpaqueAlphaByte = 255;

  final Map<ui.Image, MirkViewportBbox> viewportByImage = <ui.Image, MirkViewportBbox>{};

  @override
  Future<ui.Image> buildFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport}) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final Uint8List pixels = Uint8List.fromList(<int>[_kSdfMidpointByte, 0, 0, _kOpaqueAlphaByte]);
    ui.decodeImageFromPixels(pixels, 1, 1, ui.PixelFormat.rgba8888, completer.complete);
    final ui.Image image = await completer.future;
    viewportByImage[image] = viewport;
    return image;
  }
}

/// Screen distance, through the LIVE [camera], between the north-west corner of the viewport
/// the forwarded SDF was built for and the screen origin. At rotation 0 the visible bounds'
/// north-west corner IS screen `(0, 0)`, so a fresh SDF measures ~0 and a stale one measures
/// exactly how far the map moved since its build.
double _sdfLagPx({required MapCamera camera, required MirkViewportBbox sdfViewport}) {
  final Point<double> sdfOriginOnScreen = camera.latLngToScreenPoint(LatLng(sdfViewport.north, sdfViewport.west));
  return sdfOriginOnScreen.distanceTo(const Point<double>(0, 0));
}

/// Camera centre shifted east by [dxPx] screen pixels — the next frame of the simulated pan.
LatLng _centerShiftedEastByPx(MapCamera camera, double dxPx) {
  final Point<double> screenCentre = camera.size / 2;
  return camera.pointToLatLng(Point<double>(screenCentre.x + dxPx, screenCentre.y));
}

void main() {
  testWidgets('the SDF forwarded to the shader follows the camera on every frame of a continuous pan (no screen-glued reveal)', (tester) async {
    final mapController = MapController();
    addTearDown(mapController.dispose);
    final spyBuilder = _ViewportTaggingSdfBuilder();
    final recorder = RecordingFogShaderRenderer();
    final renderer = AtmosphericMirkRenderer(
      const AtmosphericConfig(),
      shaderRenderer: recorder,
      sdfCache: SdfCache(rebuildLogger: SdfRebuildLogger(), builder: spyBuilder),
    );
    final RevealDisc puckDisc = RevealDisc(
      id: 'rvd_uat_melun',
      sessionId: 'sess_uat',
      lat: kUatCenter.latitude,
      lon: kUatCenter.longitude,
      radiusMeters: kUatDiscRadiusMeters,
      fixedAtUtc: DateTime.utc(2026, 9, 11),
    );
    await pumpFogLayerInFlutterMap(
      tester,
      renderer: renderer,
      discs: <RevealDisc>[puckDisc],
      mapController: mapController,
      initialCenter: kUatCenter,
      initialZoom: kUatZoom,
      devicePixelRatio: kUatDevicePixelRatio,
      isAndroid: true,
    );
    await pumpUntilShaderRendered(tester, recorder);

    final List<double> sdfLagPxPerFrame = <double>[];
    final List<bool> holeOnPuckPerFrame = <bool>[];
    await tester.runAsync(() async {
      for (int step = 0; step < kPanStepCount; step++) {
        mapController.move(_centerShiftedEastByPx(mapController.camera, kPanStepPx), kUatZoom);
        await Future<void>.delayed(kPanStepRealDelay);
        await tester.pump();
        final MapCamera camera = mapController.camera;
        final MirkViewportBbox? sdfViewport = spyBuilder.viewportByImage[recorder.renders.last.sdfImage];
        expect(sdfViewport, isNotNull, reason: 'every forwarded SDF image comes from the tagging builder');
        sdfLagPxPerFrame.add(_sdfLagPx(camera: camera, sdfViewport: sdfViewport!));

        // Control: the clip hole is cut around the puck's LIVE projection on this same frame.
        final canvas = RecordingCanvasFake(canvasTx: 0, canvasTy: 0);
        findFogPainter(tester).paint(canvas, Size(camera.size.x, camera.size.y));
        final Point<double> puckOnScreen = camera.latLngToScreenPoint(LatLng(puckDisc.lat, puckDisc.lon));
        holeOnPuckPerFrame.add(!canvas.clipPathCalls.single.contains(Offset(puckOnScreen.x, puckOnScreen.y)));
      }
    });

    expect(holeOnPuckPerFrame, everyElement(isTrue), reason: 'control — the clip hole tracks the puck on every frame (same projector)');
    final double totalPanPx = kPanStepPx * kPanStepCount;
    expect(
      sdfLagPxPerFrame,
      everyElement(lessThan(kMaxSdfLagPx)),
      reason:
          'the reveal the shader paints must move with the map, not with the screen: '
          'SDF lag per frame (px) = $sdfLagPxPerFrame over a ${totalPanPx.toStringAsFixed(0)} px pan',
    );
    await renderer.dispose();
  });
}

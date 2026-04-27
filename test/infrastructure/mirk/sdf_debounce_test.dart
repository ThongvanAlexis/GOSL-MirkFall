// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-014 iteration 4 — SDF rebuild tests (replaces BUG-012 debounce tests).
//
// Verifies:
// 1. First paint triggers an immediate SDF build.
// 2. Viewport-only changes do NOT trigger a rebuild (the SDF is in disc-bbox
//    coordinates now — camera movement only changes the UV mapping).
// 3. Disc-list changes trigger an IMMEDIATE rebuild regardless of viewport.
// 4. The fix applies identically to atmospheric + heavenly_clouds renderers.
//
// Strategy: inject a spy [RevealedSdfBuilder] that counts `buildFromDiscs`
// calls and returns a minimal SdfBuildResult. The renderer's `paint()` is
// the public entry point; each call drives `_refreshSdfIfNeeded` internally.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/revealed_sdf_builder.dart';

import '_render_helpers.dart';

// ---------------------------------------------------------------------------
// Spy SDF builder — counts build calls and completes with a stub result.
// ---------------------------------------------------------------------------

/// Spy that records how many times [buildFromDiscs] was called and
/// allows the test to control when the future completes.
class _SpySdfBuilder extends RevealedSdfBuilder {
  const _SpySdfBuilder();

  /// Total number of [buildFromDiscs] invocations.
  static int buildCallCount = 0;

  /// Completers the test can complete to resolve each build.
  static List<Completer<SdfBuildResult>> completers = <Completer<SdfBuildResult>>[];

  static void reset() {
    buildCallCount = 0;
    completers = <Completer<SdfBuildResult>>[];
  }

  @override
  Future<SdfBuildResult> buildFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport}) {
    buildCallCount++;
    final completer = Completer<SdfBuildResult>();
    completers.add(completer);
    return completer.future;
  }
}

/// Creates a minimal 1x1 RGBA `ui.Image` to complete spy builders with.
Future<ui.Image> _stubImage() async {
  final completer = Completer<ui.Image>();
  // 1x1 RGBA pixel — midpoint-128 in R channel (boundary distance = 0).
  final bytes = Uint8List.fromList(<int>[128, 0, 0, 255]);
  ui.decodeImageFromPixels(bytes, 1, 1, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

/// Completes the oldest pending spy builder future with a stub result.
Future<void> _completePendingBuild() async {
  if (_SpySdfBuilder.completers.isEmpty) return;
  final completer = _SpySdfBuilder.completers.removeAt(0);
  if (!completer.isCompleted) {
    final image = await _stubImage();
    final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
    completer.complete(SdfBuildResult(image: image, bbox: bbox));
  }
  // Let microtasks propagate.
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MirkPaintContext _ctx({MirkViewportBbox? viewport, List<RevealDisc>? discs, int elapsedMs = 0}) {
  final bbox = viewport ?? MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  return MirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: 1.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: bbox,
    discs: discs ?? <RevealDisc>[singleCentreDisc(bbox: bbox)],
  );
}

RevealDisc _disc({String id = 'rvd_test_a', double lat = 43.5, double lon = 5.5}) {
  return RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: 100.0, fixedAtUtc: DateTime.utc(2026, 4, 26));
}

void _paintOnce(MirkRenderer renderer, {required MirkPaintContext context}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  renderer.paint(canvas, kTestCanvasSize, context);
  recorder.endRecording().dispose();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    _SpySdfBuilder.reset();
  });

  group('BUG-014 iteration 4 — SDF rebuild (AtmosphericMirkRenderer)', () {
    late AtmosphericMirkRenderer renderer;

    setUp(() {
      renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, sdfBuilder: const _SpySdfBuilder());
    });

    tearDown(() async {
      await renderer.dispose();
    });

    test('first paint triggers an immediate SDF build', () async {
      final ctx = _ctx();
      _paintOnce(renderer, context: ctx);
      expect(_SpySdfBuilder.buildCallCount, 1, reason: 'First paint must trigger an immediate SDF build');
    });

    test('same discs + different viewport does NOT trigger rebuild (BUG-014)', () async {
      final bbox1 = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final bbox2 = MirkViewportBbox(south: 43.1, west: 5.1, north: 44.1, east: 6.1);
      final discs = <RevealDisc>[_disc()];
      final ctx1 = _ctx(viewport: bbox1, discs: discs);
      final ctx2 = _ctx(viewport: bbox2, discs: discs);

      // First paint → triggers build.
      _paintOnce(renderer, context: ctx1);
      expect(_SpySdfBuilder.buildCallCount, 1);

      // Complete the first build so _sdfBuildInFlight clears.
      await _completePendingBuild();

      // Second paint with different viewport, same discs → NO rebuild.
      // BUG-014 iteration 4: the SDF is in disc-bbox coordinates, so
      // viewport changes don't affect it at all.
      _paintOnce(renderer, context: ctx2);
      expect(_SpySdfBuilder.buildCallCount, 1, reason: 'Viewport-only change must NOT trigger any rebuild');

      // Even after waiting — no delayed rebuild either.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(_SpySdfBuilder.buildCallCount, 1, reason: 'No debounced rebuild either — viewport changes are free');
    });

    test('new disc triggers IMMEDIATE rebuild even when viewport also changed', () async {
      final bbox1 = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final bbox2 = MirkViewportBbox(south: 43.1, west: 5.1, north: 44.1, east: 6.1);

      // First paint with disc A.
      _paintOnce(
        renderer,
        context: _ctx(
          viewport: bbox1,
          discs: [_disc(id: 'rvd_a')],
        ),
      );
      await _completePendingBuild();
      expect(_SpySdfBuilder.buildCallCount, 1);

      // Second paint: different viewport AND a new disc → immediate build.
      _paintOnce(
        renderer,
        context: _ctx(
          viewport: bbox2,
          discs: [
            _disc(id: 'rvd_a'),
            _disc(id: 'rvd_b', lat: 43.6),
          ],
        ),
      );
      expect(_SpySdfBuilder.buildCallCount, 2, reason: 'New disc in the list must trigger an immediate rebuild');
    });

    test('multiple viewport changes without disc changes → zero rebuilds after initial', () async {
      final discs = <RevealDisc>[_disc()];

      // Initial build.
      _paintOnce(
        renderer,
        context: _ctx(viewport: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0), discs: discs),
      );
      await _completePendingBuild();
      expect(_SpySdfBuilder.buildCallCount, 1);

      // Simulate a pan gesture: 10 viewport changes, same discs.
      for (var i = 1; i <= 10; i++) {
        final offset = i * 0.01;
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: MirkViewportBbox(south: 43.0 + offset, west: 5.0 + offset, north: 44.0 + offset, east: 6.0 + offset),
            discs: discs,
          ),
        );
      }

      // No rebuilds should have been triggered.
      expect(_SpySdfBuilder.buildCallCount, 1, reason: '10 viewport changes with same discs must NOT trigger any rebuilds');
    });
  });

  group('BUG-014 iteration 4 — SDF rebuild (HeavenlyCloudsMirkRenderer)', () {
    late HeavenlyCloudsMirkRenderer renderer;

    setUp(() {
      renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig, sdfBuilder: const _SpySdfBuilder());
    });

    tearDown(() async {
      await renderer.dispose();
    });

    test('viewport-only change does NOT trigger rebuild', () async {
      final bbox1 = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final bbox2 = MirkViewportBbox(south: 43.1, west: 5.1, north: 44.1, east: 6.1);
      final discs = <RevealDisc>[_disc()];

      _paintOnce(
        renderer,
        context: _ctx(viewport: bbox1, discs: discs),
      );
      expect(_SpySdfBuilder.buildCallCount, 1);

      await _completePendingBuild();

      _paintOnce(
        renderer,
        context: _ctx(viewport: bbox2, discs: discs),
      );
      expect(_SpySdfBuilder.buildCallCount, 1, reason: 'Heavenly clouds: viewport-only change must NOT trigger rebuild');
    });

    test('new disc triggers immediate rebuild', () async {
      final bbox1 = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

      _paintOnce(
        renderer,
        context: _ctx(
          viewport: bbox1,
          discs: [_disc(id: 'rvd_a')],
        ),
      );
      await _completePendingBuild();
      expect(_SpySdfBuilder.buildCallCount, 1);

      _paintOnce(
        renderer,
        context: _ctx(
          viewport: bbox1,
          discs: [
            _disc(id: 'rvd_a'),
            _disc(id: 'rvd_b', lat: 43.6),
          ],
        ),
      );
      expect(_SpySdfBuilder.buildCallCount, 2, reason: 'Heavenly clouds: new disc must trigger immediate rebuild');
    });
  });
}

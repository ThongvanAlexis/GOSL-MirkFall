// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 3 RED test suite for `HeavenlyCloudsMirkRenderer`
// (MIRK-06 builtin).
//
// BUG-010 Option B Commit 5 — fixture surface migrated from cell-bitmap
// to continuous-geometry discs (see atmospheric renderer test for the
// "all-revealed" → "viewport-spanning disc" rationale).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show BlendMode, Color, Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle_system.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_transform_logger.dart';

import '../../_helpers/fake_stopwatch.dart';
import '../../_helpers/mirk_paint_context_builder.dart';
import '../../_helpers/recording_fog_shader_renderer.dart';
import '_render_helpers.dart';

void main() {
  group('09-04 — HeavenlyCloudsMirkRenderer (MIRK-06)', () {
    test('paint() output differs between two frames at 5s sessionElapsed apart (drift animation proof)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final bytes0 = await renderToBytes(renderer, context: fakeContext());
      final bytes5s = await renderToBytes(renderer, context: fakeContext(elapsedMs: 5000));
      expect(
        bytes0,
        isNot(equals(bytes5s)),
        reason:
            'Heavenly clouds must drift — sessionElapsed delta of 5s '
            'must produce visually distinct output',
      );
      await renderer.dispose();
    });

    test('paint() output is deterministic at fixed sessionElapsed + seed', () async {
      final r1 = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final r2 = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      // The CPU noise tile is rasterised asynchronously: settle both before
      // painting so neither paint races the other's tile arrival.
      await r1.noiseReady;
      await r2.noiseReady;
      final ctx = fakeContext(elapsedMs: 2500);
      final bytes1 = await renderToBytes(r1, context: ctx);
      final bytes2 = await renderToBytes(r2, context: ctx);
      expect(
        bytes1,
        equals(bytes2),
        reason:
            'Two HeavenlyCloudsMirkRenderer instances with the same '
            'default seed must produce byte-identical output',
      );
      await r1.dispose();
      await r2.dispose();
    });

    test('paint() with empty discs list paints full fog (BUG-013 fix)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final ctx = fakeContext(discs: const <RevealDisc>[]);
      final bytes = await renderToBytes(renderer, context: ctx);
      // BUG-013: empty discs = user panned away from revealed area →
      // entire viewport must be fog, not transparent/clear (heavenly is
      // lighter than atmospheric, hence the lower floor).
      expect(alphaAt(bytes, x: 128, y: 128), greaterThan(150), reason: 'Empty discs list should produce full fog, not a no-op');
      expect(alphaAt(bytes, x: 0, y: 0), greaterThan(150));
      await renderer.dispose();
    });

    test('paint() with a viewport-spanning disc draws no fog (every pixel transparent under the shared clip)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final swallowingDisc = RevealDisc(
        id: 'rvd_test_swallow_h',
        sessionId: 'sess_test',
        lat: 43.5,
        lon: 5.5,
        radiusMeters: 200000.0,
        fixedAtUtc: DateTime.utc(2026, 4, 26),
      );
      final ctxAllRevealed = fakeContext(viewport: bbox, discs: [swallowingDisc]);
      final ctxLocalised = fakeContext(viewport: bbox);
      final bytesRevealed = await renderToBytes(renderer, context: ctxAllRevealed);
      final bytesLocalised = await renderToBytes(renderer, context: ctxLocalised);
      expect(isFullyTransparent(bytesRevealed), isTrue, reason: 'Viewport-spanning disc must leave every pixel transparent');
      expect(isFullyTransparent(bytesLocalised), isFalse, reason: 'A localised reveal leaves fog around its hole');
      await renderer.dispose();
    });

    test('dispose() is idempotent (calling twice does not throw)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.dispose();
      final ctx = fakeContext();
      expect(() => renderToPicture(renderer, context: ctx).dispose(), returnsNormally);
    });
  });

  group('09.1-03 — shader seam (FogShaderRenderer injected)', () {
    final MirkViewportBbox bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

    /// Context with deliberately non-neutral camera inputs so verbatim
    /// forwarding is distinguishable from the builder defaults.
    MirkPaintContext seamContext({int elapsedMs = 1000}) => buildTestMirkPaintContext(
      sessionElapsed: Duration(milliseconds: elapsedMs),
      viewportBbox: bbox,
      discs: <RevealDisc>[singleCentreDisc(bbox: bbox)],
      pixelOrigin: (x: 4255934.927218, y: -1234567.890123),
      zoomScale: 4.0,
      sdfRect: (0.0, 1.0, 1.0, -1.0),
    );

    HeavenlyCloudsMirkRenderer newRenderer(RecordingFogShaderRenderer recorder) =>
        HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig, sdfCache: immediateStubSdfCache(), shaderRenderer: recorder);

    /// First paint schedules the (immediate) SDF build; after one event-queue
    /// pump the image is resolved and the next paint takes the shader path.
    Future<void> paintUntilShaderPath(HeavenlyCloudsMirkRenderer renderer, RecordingFogShaderRenderer recorder, {int elapsedMs = 1000}) async {
      renderToPicture(renderer, context: seamContext(elapsedMs: elapsedMs)).dispose();
      await pumpEventQueue();
      renderToPicture(renderer, context: seamContext(elapsedMs: elapsedMs)).dispose();
      expect(recorder.renders, isNotEmpty, reason: 'second paint must go through the seam once the SDF resolved');
    }

    test('forwards pixelOrigin / zoomScale / sdfRect verbatim, 20 tunables (31 observed slots), heavenly palette', () async {
      final RecordingFogShaderRenderer recorder = RecordingFogShaderRenderer();
      final HeavenlyCloudsMirkRenderer renderer = newRenderer(recorder);
      await paintUntilShaderPath(renderer, recorder);
      final RecordedFogRender last = recorder.renders.last;
      final MirkPaintContext context = seamContext();
      expect(last.pixelOrigin, context.pixelOrigin);
      expect(last.zoomScale, context.zoomScale);
      expect(last.sdfRect, context.sdfRect);
      expect(last.resolution, kTestCanvasSize);
      expect(last.namedFloatArgs.keys.toSet(), FogShaderTunableKey.all.toSet());
      expect(last.namedFloatArgs, hasLength(20));
      expect(last.totalFloatSlotsObserved, 31);
      expect(last.baseArgb, kMirkFogHeavenlyBaseColorArgb);
      expect(last.highlightArgb, kMirkFogHeavenlyHighlightColorArgb);
      expect(last.shadowArgb, kMirkFogHeavenlyShadowColorArgb);
      await renderer.dispose();
    });

    test('timeSeconds is strictly increasing across paints at increasing sessionElapsed', () async {
      final RecordingFogShaderRenderer recorder = RecordingFogShaderRenderer();
      final HeavenlyCloudsMirkRenderer renderer = newRenderer(recorder);
      await paintUntilShaderPath(renderer, recorder);
      final double first = recorder.renders.last.timeSeconds;
      renderToPicture(renderer, context: seamContext(elapsedMs: 2500)).dispose();
      final double second = recorder.renders.last.timeSeconds;
      expect(second, greaterThan(first));
      expect(second - first, closeTo(1.5, 1e-9), reason: 'uTime tracks sessionElapsed 1:1 (seed jitter is a constant offset)');
      await renderer.dispose();
    });

    test('a tunable changed via MirkRuntimeTunables.instance between two paints reaches the seam (tuner stays live)', () async {
      addTearDown(MirkRuntimeTunables.instance.reset);
      final RecordingFogShaderRenderer recorder = RecordingFogShaderRenderer();
      final HeavenlyCloudsMirkRenderer renderer = newRenderer(recorder);
      await paintUntilShaderPath(renderer, recorder);
      final double before = recorder.renders.last.namedFloatArgs[FogShaderTunableKey.opacityFar]!;
      MirkRuntimeTunables.instance.opacityFar = before + 0.11;
      renderToPicture(renderer, context: seamContext(elapsedMs: 1500)).dispose();
      expect(recorder.renders.last.namedFloatArgs[FogShaderTunableKey.opacityFar], closeTo(before + 0.11, 1e-9));
      await renderer.dispose();
    });

    test('every render carries the same sdfImage reference until the disc list changes (SDF resolved once)', () async {
      final RecordingFogShaderRenderer recorder = RecordingFogShaderRenderer();
      final HeavenlyCloudsMirkRenderer renderer = newRenderer(recorder);
      await paintUntilShaderPath(renderer, recorder);
      renderToPicture(renderer, context: seamContext(elapsedMs: 1200)).dispose();
      expect(recorder.renders, hasLength(2));
      expect(identical(recorder.renders.first.sdfImage, recorder.renders.last.sdfImage), isTrue);
      await renderer.dispose();
    });
  });

  group('09.1-05 — wisps spawned on disc emergence, rendered after the shader rect via projectToScreen', () {
    final MirkViewportBbox bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
    const Color tint = Color(kMirkWispTintHeavenlyArgb);

    MirkPaintContext ctx({required List<RevealDisc> discs, int elapsedMs = 0}) => buildTestMirkPaintContext(
      zoomLevel: 14.0,
      sessionElapsed: Duration(milliseconds: elapsedMs),
      viewportBbox: bbox,
      discs: discs,
    );

    RevealDisc disc(String id, {double lat = 43.5, double lon = 5.5}) =>
        RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: 25.0, fixedAtUtc: DateTime.utc(2026, 4, 26));

    test(
      'draws activeCount circles at projectToScreen(position), all AFTER the drawRect, tinted kMirkWispTintHeavenlyArgb, one recordPaint per paint',
      () async {
        final _CountingWispTransformLogger wispLogger = _CountingWispTransformLogger();
        final WispParticleSystem wispSystem = WispParticleSystem(rngSeed: 42, wallClock: FakeStopwatch(initialMs: 6000));
        final HeavenlyCloudsMirkRenderer renderer = HeavenlyCloudsMirkRenderer(
          const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
          wispSystem: wispSystem,
          wispTransformLogger: wispLogger,
          sdfCache: immediateStubSdfCache(),
          shaderRenderer: const DrawRectFogShaderRenderer(),
        );
        addTearDown(renderer.dispose);

        // Paint #1: no disc → schedules the SDF, no wisp, no recordPaint.
        renderToPicture(renderer, context: ctx(discs: const <RevealDisc>[])).dispose();
        await pumpEventQueue();
        expect(wispLogger.recordPaintCallCount, 0, reason: 'no wisp alive → no diagnostic sample');

        // Paint #2: one new disc → ~20 wisps spawned and drawn on this very paint, shader path.
        final MirkPaintContext context = ctx(discs: <RevealDisc>[disc('rvd_new')], elapsedMs: 16);
        final RecordingCanvas spy = RecordingCanvas();
        renderer.paint(spy, kTestCanvasSize, context);

        expect(wispSystem.activeCount, inInclusiveRange(18, 22));
        expect(spy.circles, hasLength(wispSystem.activeCount), reason: 'one drawCircle per live wisp');
        expect(spy.ops.where((String op) => op == 'drawRect'), hasLength(1), reason: 'the shader rect was drawn once');
        expect(
          spy.ops.lastIndexOf('drawRect'),
          lessThan(spy.ops.indexOf('drawCircle')),
          reason: 'every circle comes AFTER the shader rect — never the inverse',
        );

        final List<Offset> expectedCentres = wispSystem.wisps.map((WispParticle w) => context.projectToScreen(w.position)).toList();
        expect(spy.circles.map((RecordedCircle c) => c.centre).toList(), expectedCentres, reason: 'centres = projectToScreen(wisp.position), same order');
        for (final RecordedCircle c in spy.circles) {
          expect(c.color.r, closeTo(tint.r, 1e-6));
          expect(c.color.g, closeTo(tint.g, 1e-6));
          expect(c.color.b, closeTo(tint.b, 1e-6));
          expect(c.color.a, inInclusiveRange(0.0, kMirkFogWispPeakAlpha + 1e-9));
          expect(c.blendMode, BlendMode.plus);
          expect(c.radius, inInclusiveRange(kMirkFogWispBirthRadiusPx, kMirkFogWispDeathRadiusPx));
        }
        expect(wispLogger.recordPaintCallCount, 1, reason: 'exactly one recordPaint for the paint that drew wisps');
        expect(wispLogger.lastActiveCount, wispSystem.activeCount);
      },
    );

    test('wisps advance between paints by the sessionElapsed delta (world position moves, projection follows)', () async {
      final WispParticleSystem wispSystem = WispParticleSystem(rngSeed: 42, wallClock: FakeStopwatch(initialMs: 6000));
      final HeavenlyCloudsMirkRenderer renderer = HeavenlyCloudsMirkRenderer(
        const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
        wispSystem: wispSystem,
        sdfCache: immediateStubSdfCache(),
      );
      addTearDown(renderer.dispose);
      final List<RevealDisc> discs = <RevealDisc>[disc('rvd_new')];
      renderToPicture(renderer, context: ctx(discs: discs)).dispose();
      final List<GeoPoint> before = wispSystem.wisps.map((WispParticle w) => w.position).toList();
      renderToPicture(renderer, context: ctx(discs: discs, elapsedMs: 100)).dispose();
      final List<GeoPoint> after = wispSystem.wisps.map((WispParticle w) => w.position).toList();
      expect(after, hasLength(before.length));
      expect(after, isNot(equals(before)), reason: '100 ms at ~1.5 m/s moves every wisp');
      expect(wispSystem.wisps.every((WispParticle w) => w.life < kMirkFogWispLifeSeconds), isTrue);
    });
  });

  group('09.1-06 — CPU fallback noise anchored to world pixels (pixelOrigin / zoomScale)', () {
    final MirkViewportBbox bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

    /// Disc-free context (no feather ring, no hole) with camera-derived fields overridable.
    MirkPaintContext cpuContext({
      ({double x, double y}) pixelOrigin = kTestNeutralPixelOrigin,
      double zoomScale = kTestNeutralZoomScale,
      (double, double, double, double) sdfRect = kTestIdentitySdfRect,
      int elapsedMs = 1000,
    }) => buildTestMirkPaintContext(
      zoomLevel: 14.0,
      sessionElapsed: Duration(milliseconds: elapsedMs),
      viewportBbox: bbox,
      pixelOrigin: pixelOrigin,
      zoomScale: zoomScale,
      sdfRect: sdfRect,
    );

    /// Renderer forced onto the CPU path (the seam never draws) with its noise tile settled.
    Future<HeavenlyCloudsMirkRenderer> cpuRenderer() async {
      final HeavenlyCloudsMirkRenderer renderer = HeavenlyCloudsMirkRenderer(
        const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
        sdfCache: immediateStubSdfCache(),
        shaderRenderer: const FallbackOnlyFogShaderRenderer(),
      );
      addTearDown(renderer.dispose);
      await renderer.noiseReady;
      return renderer;
    }

    test('pan (iOS): pixelOrigin (37, 0) renders the (0, 0) frame shifted 37 px to the left — noise anchored to the world', () async {
      final HeavenlyCloudsMirkRenderer renderer = await cpuRenderer();
      const int rowY = 40;
      final Uint8List frameA = await renderToBytes(renderer, context: cpuContext());
      final Uint8List frameB = await renderToBytes(renderer, context: cpuContext(pixelOrigin: (x: 37.0, y: 0.0)));
      final List<int> rowA = _redRow(frameA, rowY);
      final List<int> rowB = _redRow(frameB, rowY);
      expect(_spread(rowA), greaterThanOrEqualTo(_minVisibleSpread), reason: 'the CPU path must show spatial noise on the fallback fog');
      expect(
        _bestShift(reference: rowA, candidate: rowB),
        37,
        reason: 'B[x] == A[x + 37]: a 37 px camera pan moves the clouds 37 px on screen',
      );
      expect(alphaAt(frameB, x: 128, y: 128), greaterThan(150), reason: 'the overlay modulates the colour, not the fog opacity');
    });

    test('pan (Android): sdfRect V-flip + negative pixelOrigin.y → the raw camera y drives the vertical shift', () async {
      final HeavenlyCloudsMirkRenderer renderer = await cpuRenderer();
      const int columnX = 40;
      final Uint8List frameA = await renderToBytes(renderer, context: cpuContext());
      // FOG-23 flips y for the GPU only; the raw camera value is +29 → the clouds move 29 px up.
      final Uint8List frameB = await renderToBytes(
        renderer,
        context: cpuContext(pixelOrigin: (x: 0.0, y: -29.0), sdfRect: kFogSdfRectAndroidVFlip),
      );
      final List<int> columnA = _redColumn(frameA, columnX);
      final List<int> columnB = _redColumn(frameB, columnX);
      expect(_spread(columnA), greaterThanOrEqualTo(_minVisibleSpread));
      expect(
        _bestShift(reference: columnA, candidate: columnB),
        29,
        reason: 'B[y] == A[y + 29]: the CPU path reads rawPixelOriginOf(context)',
      );
    });

    test('zoom: zoomScale 2 doubles the on-screen noise period (B[2i] == A[i] at the same pixelOrigin)', () async {
      final HeavenlyCloudsMirkRenderer renderer = await cpuRenderer();
      const int rowY = 40;
      final Uint8List frameA = await renderToBytes(renderer, context: cpuContext());
      final Uint8List frameB = await renderToBytes(renderer, context: cpuContext(zoomScale: 2.0));
      final List<int> rowA = _redRow(frameA, rowY);
      final List<int> rowB = _redRow(frameB, rowY);
      expect(_spread(rowA), greaterThanOrEqualTo(_minVisibleSpread));
      // Tolerance: bilinear weights computed from float32 matrices may round differently.
      const int maxLevelDelta = 2;
      const int halfWidth = _canvasPx ~/ 2;
      var mismatches = 0;
      for (var i = 0; i < halfWidth; i++) {
        if ((rowB[2 * i] - rowA[i]).abs() > maxLevelDelta) mismatches++;
      }
      const int maxMismatches = halfWidth ~/ 20;
      expect(mismatches, lessThanOrEqualTo(maxMismatches), reason: 'the ×2 zoom must stretch the same world noise ×2 on screen');
    });

    test('sessionElapsed still drives the temporal drift (two elapsed → different bytes)', () async {
      final HeavenlyCloudsMirkRenderer renderer = await cpuRenderer();
      final Uint8List frame1 = await renderToBytes(renderer, context: cpuContext());
      final Uint8List frame2 = await renderToBytes(renderer, context: cpuContext(elapsedMs: 6000));
      expect(frame1, isNot(equals(frame2)));
    });
  });
}

/// Canvas edge in pixels (the builder default is 256×256, matching `kTestCanvasSize`).
const int _canvasPx = 256;

/// Red channel of row [y], one entry per column.
List<int> _redRow(Uint8List rgba, int y) => List<int>.generate(_canvasPx, (int x) => redAt(rgba, x: x, y: y));

/// Red channel of column [x], one entry per row.
List<int> _redColumn(Uint8List rgba, int x) => List<int>.generate(_canvasPx, (int y) => redAt(rgba, x: x, y: y));

/// Half-width of the shift search window (px) and the sample span inside the line that keeps
/// `index + shift` within the 256-px line for every candidate shift.
const int _maxShiftPx = 64;
const int _sampleStart = 64;
const int _sampleEnd = 192;

/// Shift `d` in `[-64, 64]` minimising `Σ |candidate[i] − reference[i + d]|` over the sample span:
/// the displacement that maps the reference line onto the candidate line.
int _bestShift({required List<int> reference, required List<int> candidate}) {
  var bestShift = 0;
  var bestError = double.infinity;
  for (var d = -_maxShiftPx; d <= _maxShiftPx; d++) {
    var error = 0.0;
    for (var i = _sampleStart; i < _sampleEnd; i++) {
      error += (candidate[i] - reference[i + d]).abs();
    }
    if (error < bestError) {
      bestError = error;
      bestShift = d;
    }
  }
  return bestShift;
}

/// Spread (max − min) of a line — proves the noise is visible on it.
int _spread(List<int> line) => line.reduce(math.max) - line.reduce(math.min);

/// Minimal visible spread of the noise along a line (8-bit levels).
const int _minVisibleSpread = 8;

/// Counts `recordPaint` calls regardless of the verbose gate (the override runs before it).
class _CountingWispTransformLogger extends WispTransformLogger {
  int recordPaintCallCount = 0;
  int? lastActiveCount;

  @override
  void recordPaint({
    required int activeCount,
    required double meanAge,
    required (double, double) latBounds,
    required (double, double) lonBounds,
    required (double, double) screenXBounds,
    required (double, double) screenYBounds,
    required double spawnRatePerSecond,
  }) {
    recordPaintCallCount++;
    lastActiveCount = activeCount;
  }
}

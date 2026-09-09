// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 3 RED test suite for `HeavenlyCloudsMirkRenderer`
// (MIRK-06 builtin).
//
// BUG-010 Option B Commit 5 — fixture surface migrated from cell-bitmap
// to continuous-geometry discs (see atmospheric renderer test for the
// "all-revealed" → "viewport-spanning disc" rationale).

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_renderer.dart';

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
      final pic = renderToPicture(renderer, context: ctx);
      // BUG-013: empty discs = user panned away from revealed area →
      // entire viewport must be fog, not transparent/clear. The fallback
      // path emits a single drawPath (~300 bytes); a true no-op produces
      // ~120 bytes (recorder header only).
      expect(pic.approximateBytesUsed, greaterThan(200), reason: 'Empty discs list should produce full-fog picture, not a no-op');
      pic.dispose();
      await renderer.dispose();
    });

    test('paint() with a viewport-spanning disc draws no fog (smaller picture than localised disc)', () async {
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
      final picRevealed = renderToPicture(renderer, context: ctxAllRevealed);
      final picLocalised = renderToPicture(renderer, context: ctxLocalised);
      expect(
        picRevealed.approximateBytesUsed,
        lessThan(picLocalised.approximateBytesUsed),
        reason: 'Viewport-spanning disc must draw less than a localised reveal',
      );
      picRevealed.dispose();
      picLocalised.dispose();
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

    HeavenlyCloudsMirkRenderer newRenderer(RecordingFogShaderRenderer recorder) => HeavenlyCloudsMirkRenderer(
      const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
      sdfBuilder: const ImmediateStubSdfBuilder(),
      shaderRenderer: recorder,
    );

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
}

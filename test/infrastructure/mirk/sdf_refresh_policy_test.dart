// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// SDF refresh policy of the two shader renderers — successor of the BUG-012 `sdf_debounce_test`.
//
// Phase 09.1 UAT (Pixel 6 Pro): the shader samples the SDF through the platform-static `sdfRect`
// (invariant 9), so a texture that lags the camera is pinned to the SCREEN and the reveal slides
// off the puck during a pan. The 200 ms viewport-only debounce of BUG-012 it. 1 (harmless in the
// overlay era only because it. 2's dynamic `sdfRect` remapped the stale texture) is gone; the POC
// policy applies: EVERY camera change reaches `SdfCache.getOrBuild` immediately, with one build in
// flight and coalescing, and the cache's quantised key is the only rate limiter.
//
// Scenarios:
// 1. First paint → immediate build.
// 2. Same discs + different viewport → IMMEDIATE build (no timer to wait for).
// 3. New disc → immediate build even when the viewport also changed.
// 4. A viewport change while a build is in flight is coalesced into ONE follow-up with the latest viewport.
// 5. Paints during an in-flight build coalesce into at most ONE follow-up `getOrBuild`.
// 6. The previous SDF stays in use while a rebuild is in flight (stale, never absent).
// 7. A fresh List with the same discs is NOT a disc change (the provider hands out a new list per query).
// 8. Sub-quantisation viewport drift reaches the cache but does not rebuild (PERF-08 layering).
// 9. dispose() while a build is in flight → no follow-up build.
//
// Strategy: a spy [RevealedSdfBuilder] (build count, per-build viewport, completers) injected
// through `SdfCache(builder:)`, both renderers exercised through the same table.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/revealed_sdf_builder.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/sdf_cache.dart';
import 'package:mirkfall/infrastructure/mirk/sdf_rebuild_logger.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_renderer.dart';

import '../../_helpers/mirk_paint_context_builder.dart';
import '../../_helpers/recording_fog_shader_renderer.dart';
import '_render_helpers.dart';

/// Spy builder — counts `buildFromDiscs` calls, records the viewport of each, and lets the test
/// decide when each build resolves.
class _SpySdfBuilder extends RevealedSdfBuilder {
  _SpySdfBuilder();

  int buildCallCount = 0;
  final List<MirkViewportBbox> builtViewports = <MirkViewportBbox>[];
  final List<Completer<ui.Image>> completers = <Completer<ui.Image>>[];

  @override
  Future<ui.Image> buildFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport}) {
    buildCallCount++;
    builtViewports.add(viewport);
    final Completer<ui.Image> completer = Completer<ui.Image>();
    completers.add(completer);
    return completer.future;
  }

  /// Completes the oldest pending build with a stub image and lets the renderer's continuation
  /// (publish image, coalesced follow-up) run.
  Future<void> completeOldestBuild() async {
    if (completers.isEmpty) return;
    final Completer<ui.Image> completer = completers.removeAt(0);
    if (!completer.isCompleted) {
      completer.complete(await stubSdfImage());
    }
    await pumpEventQueue();
  }
}

typedef _RendererFactory = MirkRenderer Function({required SdfCache sdfCache, required FogShaderRenderer shaderRenderer});

MirkRenderer _newAtmospheric({required SdfCache sdfCache, required FogShaderRenderer shaderRenderer}) =>
    AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, sdfCache: sdfCache, shaderRenderer: shaderRenderer);

MirkRenderer _newHeavenly({required SdfCache sdfCache, required FogShaderRenderer shaderRenderer}) =>
    HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig, sdfCache: sdfCache, shaderRenderer: shaderRenderer);

final MirkViewportBbox _bbox1 = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
final MirkViewportBbox _bbox2 = MirkViewportBbox(south: 43.1, west: 5.1, north: 44.1, east: 6.1);
final MirkViewportBbox _bbox3 = MirkViewportBbox(south: 43.2, west: 5.2, north: 44.2, east: 6.2);

/// Long enough for any timer a regression might re-introduce to fire.
const Duration _wellAfterAnyTimer = Duration(milliseconds: 250);

MirkPaintContext _ctx({required MirkViewportBbox viewport, required List<RevealDisc> discs, int elapsedMs = 0}) => buildTestMirkPaintContext(
  zoomLevel: 14.0,
  sessionElapsed: Duration(milliseconds: elapsedMs),
  viewportBbox: viewport,
  discs: discs,
);

RevealDisc _disc({String id = 'rvd_test_a', double lat = 43.5, double lon = 5.5}) =>
    RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: 100.0, fixedAtUtc: DateTime.utc(2026, 4, 26));

void _paintOnce(MirkRenderer renderer, {required MirkPaintContext context}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  renderer.paint(ui.Canvas(recorder), kTestCanvasSize, context);
  recorder.endRecording().dispose();
}

void main() {
  for (final (String name, _RendererFactory newRenderer) in <(String, _RendererFactory)>[
    ('AtmosphericMirkRenderer', _newAtmospheric),
    ('HeavenlyCloudsMirkRenderer', _newHeavenly),
  ]) {
    group('SDF refresh policy — every camera change reaches SdfCache immediately ($name)', () {
      late _SpySdfBuilder spy;
      late RecordingFogShaderRenderer seam;
      late MirkRenderer renderer;

      setUp(() {
        spy = _SpySdfBuilder();
        seam = RecordingFogShaderRenderer();
        renderer = newRenderer(
          sdfCache: SdfCache(rebuildLogger: SdfRebuildLogger(), builder: spy),
          shaderRenderer: seam,
        );
      });

      tearDown(() async {
        await renderer.dispose();
      });

      test('first paint triggers an immediate SDF build', () {
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox1, discs: <RevealDisc>[_disc()]),
        );
        expect(spy.buildCallCount, 1, reason: 'first paint must trigger an immediate SDF build');
      });

      test('same discs + different viewport triggers an IMMEDIATE rebuild for that viewport (no gesture debounce)', () async {
        final List<RevealDisc> discs = <RevealDisc>[_disc()];
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox1, discs: discs),
        );
        await spy.completeOldestBuild();
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox2, discs: discs),
        );
        expect(spy.buildCallCount, 2, reason: 'a stale SDF is pinned to the screen under the static sdfRect — the pan must rebuild now');
        expect(spy.builtViewports.last, equals(_bbox2), reason: 'the build is for the viewport being painted');
      });

      test('new disc triggers IMMEDIATE rebuild even when viewport also changed', () async {
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[_disc(id: 'rvd_a')],
          ),
        );
        await spy.completeOldestBuild();
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox2,
            discs: <RevealDisc>[
              _disc(id: 'rvd_a'),
              _disc(id: 'rvd_b', lat: 43.6),
            ],
          ),
        );
        expect(spy.buildCallCount, 2, reason: 'a new disc in the list must trigger an immediate rebuild');
      });

      test('viewport changes during an in-flight build coalesce into ONE follow-up built for the LATEST viewport', () async {
        final List<RevealDisc> discs = <RevealDisc>[_disc()];
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox1, discs: discs),
        );
        expect(spy.buildCallCount, 1);
        // Two more pan frames while build #1 is still pending — neither may start a build.
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox2, discs: discs),
        );
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox3, discs: discs),
        );
        expect(spy.buildCallCount, 1, reason: 'only one build in flight at a time');
        await spy.completeOldestBuild();
        expect(spy.buildCallCount, 2, reason: 'exactly one coalesced follow-up');
        expect(spy.builtViewports.last, equals(_bbox3), reason: 'the follow-up uses the most recent viewport, not the intermediate one');
        await spy.completeOldestBuild();
        await pumpEventQueue();
        expect(spy.buildCallCount, 2, reason: 'no further build once the follow-up resolved');
      });

      test('paints during an in-flight build coalesce into at most ONE follow-up getOrBuild', () async {
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[_disc(id: 'rvd_a')],
          ),
        );
        expect(spy.buildCallCount, 1);
        // Two disc-list changes while build #1 is still pending — neither may start a build.
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[
              _disc(id: 'rvd_a'),
              _disc(id: 'rvd_b', lat: 43.6),
            ],
          ),
        );
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[
              _disc(id: 'rvd_a'),
              _disc(id: 'rvd_b', lat: 43.6),
              _disc(id: 'rvd_c', lat: 43.4),
            ],
          ),
        );
        expect(spy.buildCallCount, 1, reason: 'only one build in flight at a time');
        await spy.completeOldestBuild();
        expect(spy.buildCallCount, 2, reason: 'exactly one coalesced follow-up build with the latest inputs');
        await spy.completeOldestBuild();
        await pumpEventQueue();
        expect(spy.buildCallCount, 2, reason: 'no further build once the follow-up resolved');
      });

      test('the previous SDF image stays in use while a rebuild is in flight (stale, never absent)', () async {
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[_disc(id: 'rvd_a')],
          ),
        );
        await spy.completeOldestBuild();
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[_disc(id: 'rvd_a')],
            elapsedMs: 16,
          ),
        );
        expect(seam.renders, hasLength(1), reason: 'shader path once the first build resolved');
        final ui.Image first = seam.renders.single.sdfImage;
        // New disc → build #2 in flight; this very paint must still draw with the first image.
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[
              _disc(id: 'rvd_a'),
              _disc(id: 'rvd_b', lat: 43.6),
            ],
            elapsedMs: 32,
          ),
        );
        expect(spy.buildCallCount, 2);
        expect(identical(seam.renders.last.sdfImage, first), isTrue, reason: 'stale image used during the rebuild');
        await spy.completeOldestBuild();
        _paintOnce(
          renderer,
          context: _ctx(
            viewport: _bbox1,
            discs: <RevealDisc>[
              _disc(id: 'rvd_a'),
              _disc(id: 'rvd_b', lat: 43.6),
            ],
            elapsedMs: 48,
          ),
        );
        expect(identical(seam.renders.last.sdfImage, first), isFalse, reason: 'the new image is picked up once resolved');
      });

      test('a fresh List holding the same discs is NOT a disc change (provider hands out a new list per query)', () async {
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox1, discs: <RevealDisc>[_disc()]),
        );
        await spy.completeOldestBuild();
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox1, discs: <RevealDisc>[_disc()]),
        );
        expect(spy.buildCallCount, 1, reason: 'same content, same viewport → nothing to do');
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox2, discs: <RevealDisc>[_disc()]),
        );
        expect(spy.buildCallCount, 2, reason: 'same content, new viewport → immediate rebuild');
      });

      test('sub-quantisation viewport drift reaches the cache but does not rebuild (PERF-08 layering)', () async {
        final List<RevealDisc> discs = <RevealDisc>[_disc()];
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox1, discs: discs),
        );
        await spy.completeOldestBuild();
        const double drift = 1e-6;
        final MirkViewportBbox drifted = MirkViewportBbox(south: 43.0 + drift, west: 5.0 + drift, north: 44.0 + drift, east: 6.0 + drift);
        _paintOnce(
          renderer,
          context: _ctx(viewport: drifted, discs: discs),
        );
        await pumpEventQueue();
        expect(spy.buildCallCount, 1, reason: 'the quantised key absorbs sub-1e-4° drift — cache hit, no rebuild');
      });

      test('dispose() while a build is in flight → no follow-up build, ever', () async {
        final List<RevealDisc> discs = <RevealDisc>[_disc()];
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox1, discs: discs),
        );
        _paintOnce(
          renderer,
          context: _ctx(viewport: _bbox2, discs: discs),
        );
        expect(spy.buildCallCount, 1, reason: 'the pan request is coalesced behind the in-flight build');
        await renderer.dispose();
        await spy.completeOldestBuild();
        await Future<void>.delayed(_wellAfterAnyTimer);
        expect(spy.buildCallCount, 1, reason: 'dispose must drop the coalesced request');
      });
    });
  }
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-012 regression tests: SDF rebuild debounce on viewport-only changes — rewritten by Phase
// 09.1 plan 09.1-05 on the new debounce point (the renderer's 200 ms viewport-only timer sits IN
// FRONT of `SdfCache.getOrBuild`).
//
// Scenarios (same names as the BUG-012 suite, plus the 09.1-05 must-haves):
// 1. First paint → immediate build.
// 2. Same discs + different viewport → NO immediate build; build after `kMirkFogSdfViewportDebounceMs`.
// 3. New disc → immediate build even when the viewport also changed.
// 4. dispose() cancels the timer (no late build).
// 5. Paints during an in-flight build coalesce into at most ONE follow-up `getOrBuild`.
// 6. The previous SDF stays in use while a rebuild is in flight (stale, never absent).
// 7. A fresh List with the same discs is NOT a disc change (the provider hands out a new list per query).
// 8. Sub-quantisation viewport drift reaches the cache after the debounce but does not rebuild.
//
// Strategy: a spy [RevealedSdfBuilder] (build count + completers) injected through
// `SdfCache(builder:)`, both renderers exercised through the same table.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
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

/// Spy builder — counts `buildFromDiscs` calls and lets the test decide when each build resolves.
class _SpySdfBuilder extends RevealedSdfBuilder {
  _SpySdfBuilder();

  int buildCallCount = 0;
  final List<Completer<ui.Image>> completers = <Completer<ui.Image>>[];

  @override
  Future<ui.Image> buildFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport}) {
    buildCallCount++;
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

/// Well past the debounce window.
const Duration _pastDebounce = Duration(milliseconds: kMirkFogSdfViewportDebounceMs + 50);

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
    group('BUG-012 — SDF debounce in front of SdfCache ($name)', () {
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

      test('same discs + different viewport does NOT trigger immediate rebuild', () async {
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
        expect(spy.buildCallCount, 1, reason: 'viewport-only change must debounce, not rebuild immediately');
      });

      test('viewport-only change triggers build after debounce delay', () async {
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
        expect(spy.buildCallCount, 1, reason: 'debounce has not fired yet');
        await Future<void>.delayed(_pastDebounce);
        expect(spy.buildCallCount, 2, reason: 'debounce timer must have triggered a rebuild');
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

      test('dispose cancels pending debounce timer (no late rebuild after dispose)', () async {
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
        expect(spy.buildCallCount, 1);
        await renderer.dispose();
        await Future<void>.delayed(_pastDebounce);
        expect(spy.buildCallCount, 1, reason: 'dispose must cancel the debounce timer');
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
        expect(spy.buildCallCount, 1, reason: 'same content, new viewport → debounced, not immediate');
        await Future<void>.delayed(_pastDebounce);
        expect(spy.buildCallCount, 2);
      });

      test('sub-quantisation viewport drift reaches the cache after the debounce but does not rebuild (PERF-08 layering)', () async {
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
        await Future<void>.delayed(_pastDebounce);
        expect(spy.buildCallCount, 1, reason: 'the quantised key absorbs sub-1e-4° drift — cache hit, no rebuild');
      });
    });
  }
}

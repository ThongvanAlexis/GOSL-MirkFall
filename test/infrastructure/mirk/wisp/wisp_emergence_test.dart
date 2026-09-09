// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-010 Option B Commit 5 + BUG-015 — wisp emergence on disc-id diff, rewritten by Phase 09.1
// plan 09.1-05 on `WispParticleSystem.spawnAtNewDisc`.
//
// The renderer keeps an append-only seen-id set as a cheap pre-filter and forwards each newly
// seen disc to the system; idempotence per id AND the 5 s warm-up (`kMirkFogWispWarmUpSeconds`,
// clocked from the SYSTEM's construction) live in the system. There is no renderer-side warm-up
// flag and no `resetWarmUp()`: a session start / resume or a style change rebuilds
// `activeMirkRendererProvider`, which creates a NEW renderer — hence a new system with a fresh
// stopwatch. The clock is a `FakeStopwatch` here.
//
// Scenarios (BUG-010 / BUG-015 names kept), run against BOTH shader renderers:
//  (a) During warm-up: seed discs spawn nothing.
//  (b) After warm-up: same disc list → nothing.
//  (c) After warm-up: one new disc → wisps along ITS perimeter only (radius ± 1 m).
//  (d) BUG-015: discs leave the viewport then re-enter → nothing (ids already seen).
//  (e) BUG-015: first paint with 0 discs, discs arrive during warm-up → nothing.
//  (f) BUG-015 root cause: discs scrolling in during warm-up are absorbed; a fresh disc after
//      warm-up DOES spawn.
//  (g) BUG-015 session restart: a second renderer (fresh clock) receiving the same discs is
//      back in warm-up; after its own 5 s a new disc spawns.
//  (h) Source reflection: no `_warmingUp` / `_firstPaint` / `resetWarmUp` in the renderers.

import 'dart:io';
import 'dart:ui' show Canvas, PictureRecorder;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle_system.dart';

import '../../../_helpers/fake_stopwatch.dart';
import '../../../_helpers/mirk_paint_context_builder.dart';
import '../_render_helpers.dart';

typedef _RendererFactory = MirkRenderer Function(WispParticleSystem wispSystem);

MirkRenderer _newAtmospheric(WispParticleSystem wispSystem) =>
    AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem, sdfCache: immediateStubSdfCache());

MirkRenderer _newHeavenly(WispParticleSystem wispSystem) =>
    HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig, wispSystem: wispSystem, sdfCache: immediateStubSdfCache());

/// Past the 5 s warm-up.
const int _postWarmUpMs = 6000;

final MirkViewportBbox _viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

MirkPaintContext _ctx({required List<RevealDisc> discs, int elapsedMs = 0}) => buildTestMirkPaintContext(
  zoomLevel: 14.0,
  sessionElapsed: Duration(milliseconds: elapsedMs),
  viewportBbox: _viewport,
  discs: discs,
);

RevealDisc _disc(String id, {double lat = 43.5, double lon = 5.5, double radiusMeters = 25.0}) =>
    RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: DateTime.utc(2026, 4, 26));

void _paint(MirkRenderer renderer, MirkPaintContext context) {
  final PictureRecorder recorder = PictureRecorder();
  renderer.paint(Canvas(recorder), kTestCanvasSize, context);
  recorder.endRecording().dispose();
}

void main() {
  for (final (String name, _RendererFactory newRenderer) in <(String, _RendererFactory)>[
    ('AtmosphericMirkRenderer', _newAtmospheric),
    ('HeavenlyCloudsMirkRenderer', _newHeavenly),
  ]) {
    group('BUG-010 / BUG-015 — wisp emergence via spawnAtNewDisc ($name)', () {
      late FakeStopwatch clock;
      late WispParticleSystem wispSystem;
      late MirkRenderer renderer;

      setUp(() {
        clock = FakeStopwatch();
        wispSystem = WispParticleSystem(rngSeed: 42, wallClock: clock);
        renderer = newRenderer(wispSystem);
      });

      tearDown(() async {
        await renderer.dispose();
      });

      /// Paints [seedDiscs] once during warm-up (ids ingested, nothing spawned), then opens the
      /// gate by advancing the SYSTEM's clock past `kMirkFogWispWarmUpSeconds`.
      void drainWarmUp(List<RevealDisc> seedDiscs) {
        _paint(renderer, _ctx(discs: seedDiscs, elapsedMs: 100));
        expect(wispSystem.activeCount, 0, reason: 'warm-up drain must not spawn');
        clock.advance(_postWarmUpMs);
      }

      test('(a) during warm-up: seed discs do NOT spawn wisps (resumed-session guard)', () {
        _paint(renderer, _ctx(discs: <RevealDisc>[_disc('rvd_a'), _disc('rvd_b', lat: 43.6), _disc('rvd_c', lat: 43.4)], elapsedMs: 100));
        expect(wispSystem.activeCount, 0, reason: 'during warm-up, discs are ingested silently');
      });

      test('(b) after warm-up: same disc list spawns no new wisps (steady state)', () {
        final List<RevealDisc> discs = <RevealDisc>[_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
        drainWarmUp(discs);
        _paint(renderer, _ctx(discs: discs, elapsedMs: _postWarmUpMs + 16));
        expect(wispSystem.activeCount, 0, reason: 'no new disc → no spawn');
      });

      test('(c) after warm-up: one new disc spawns wisps along ITS perimeter only', () {
        final List<RevealDisc> initial = <RevealDisc>[_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
        drainWarmUp(initial);
        final RevealDisc fresh = _disc('rvd_new', lat: 43.55, lon: 5.45);
        _paint(renderer, _ctx(discs: <RevealDisc>[...initial, fresh], elapsedMs: _postWarmUpMs + 32));
        // 2π · 25 / 8 ≈ 19.6 → ~20 wisps for ONE disc (no burst on the two seed discs).
        expect(wispSystem.activeCount, inInclusiveRange(18, 22));
        for (final WispParticle w in wispSystem.wisps) {
          expect(
            fresh.distanceMetersTo(w.position.latitude, w.position.longitude),
            closeTo(fresh.radiusMeters, 1.0),
            reason: 'every wisp sits on the NEW disc perimeter',
          );
        }
      });

      test('(d) BUG-015: discs leave viewport then re-enter — no spurious wisps', () {
        final List<RevealDisc> discs = <RevealDisc>[_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
        drainWarmUp(discs);
        _paint(renderer, _ctx(discs: <RevealDisc>[], elapsedMs: _postWarmUpMs + 16));
        expect(wispSystem.activeCount, 0);
        _paint(renderer, _ctx(discs: discs, elapsedMs: _postWarmUpMs + 32));
        expect(wispSystem.activeCount, 0, reason: 'discs leaving and re-entering the viewport are not newly emerged');
      });

      test('(e) BUG-015: first paint with 0 discs then discs arrive during warm-up — no spurious wisps', () {
        _paint(renderer, _ctx(discs: <RevealDisc>[]));
        expect(wispSystem.activeCount, 0);
        final List<RevealDisc> existing = <RevealDisc>[_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
        _paint(renderer, _ctx(discs: existing, elapsedMs: 100));
        expect(wispSystem.activeCount, 0, reason: 'discs arriving during warm-up are pre-existing, not newly emerged');
        clock.advance(_postWarmUpMs);
        _paint(renderer, _ctx(discs: existing, elapsedMs: _postWarmUpMs));
        expect(wispSystem.activeCount, 0, reason: 'exiting warm-up with the same disc set must not spawn');
      });

      test('(f) BUG-015 root cause: discs scrolling into the viewport during warm-up are absorbed; a fresh disc after warm-up spawns', () {
        _paint(renderer, _ctx(discs: <RevealDisc>[_disc('rvd_a')], elapsedMs: 100));
        clock.advance(400);
        _paint(renderer, _ctx(discs: <RevealDisc>[_disc('rvd_a'), _disc('rvd_b', lat: 43.6)], elapsedMs: 500));
        clock.advance(1500);
        final List<RevealDisc> four = <RevealDisc>[_disc('rvd_a'), _disc('rvd_b', lat: 43.6), _disc('rvd_c', lat: 43.4), _disc('rvd_d', lat: 43.3)];
        _paint(renderer, _ctx(discs: four, elapsedMs: 2000));
        expect(wispSystem.activeCount, 0, reason: 'all scrolled-in discs ingested without spawning');
        clock.advance(_postWarmUpMs);
        _paint(renderer, _ctx(discs: four, elapsedMs: _postWarmUpMs));
        expect(wispSystem.activeCount, 0, reason: 'discs seen during warm-up never burst once the gate opens');
        _paint(renderer, _ctx(discs: <RevealDisc>[...four, _disc('rvd_fresh_gps', lat: 43.45)], elapsedMs: _postWarmUpMs + 16));
        expect(wispSystem.activeCount, greaterThan(0), reason: 'a genuinely new GPS-fix disc after warm-up must spawn');
      });

      test('(g) BUG-015 session restart: a SECOND renderer with a fresh clock is back in warm-up — no resetWarmUp() needed', () async {
        // Renderer #1 (this group's) already past warm-up: a new disc spawns.
        clock.advance(_postWarmUpMs);
        final RevealDisc disc = _disc('rvd_a');
        _paint(renderer, _ctx(discs: <RevealDisc>[disc], elapsedMs: _postWarmUpMs));
        expect(wispSystem.activeCount, greaterThan(0));

        // Renderer #2 — what activeMirkRendererProvider creates on the next Tracking / style
        // change: new system, clock at 0. The SAME discs on its first paint must spawn nothing.
        final FakeStopwatch clockB = FakeStopwatch();
        final WispParticleSystem systemB = WispParticleSystem(rngSeed: 42, wallClock: clockB);
        final MirkRenderer rendererB = newRenderer(systemB);
        addTearDown(rendererB.dispose);
        _paint(rendererB, _ctx(discs: <RevealDisc>[disc]));
        expect(systemB.activeCount, 0, reason: 'a fresh renderer is in warm-up regardless of what the previous one saw');

        clockB.advance(_postWarmUpMs);
        _paint(rendererB, _ctx(discs: <RevealDisc>[disc, _disc('rvd_b', lat: 43.6)], elapsedMs: _postWarmUpMs));
        expect(systemB.activeCount, greaterThan(0), reason: 'after ITS OWN warm-up a new disc spawns on renderer #2');
      });
    });
  }

  group('BUG-015 — renderer-side warm-up state is gone (source reflection)', () {
    for (final String path in <String>[
      'lib/infrastructure/mirk/atmospheric_mirk_renderer.dart',
      'lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart',
    ]) {
      test('$path has no _warmingUp / _firstPaint / resetWarmUp and no MirkProjection import', () {
        final String source = File(path).readAsStringSync();
        expect(source, isNot(contains('_warmingUp')));
        expect(RegExp(r'\b_firstPaint\b').hasMatch(source), isFalse, reason: 'the boolean first-paint guard of BUG-015 it. 1 is gone');
        expect(source, isNot(contains('resetWarmUp')));
        expect(source, isNot(contains("import 'mirk_projection.dart'")), reason: 'wisps project through context.projectToScreen only');
        expect(source, contains('spawnAtNewDisc('));
        expect(source, contains('projectToScreen(wisp.position)'));
      });
    }
  });
}

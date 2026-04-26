// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-010 Option B Commit 5 — wisp emergence diff test.
//
// The atmospheric + heavenly_clouds renderers spawn wisps on the per-frame
// diff of the disc id set: a fix landing produces exactly one new id
// → renderer notices the new id → spawns N evenly-spaced wisps along
// the disc perimeter. The first paint is guarded so resuming a session
// does not spray wisps over already-revealed area.
//
// Tests cover:
//  (a) first paint with N discs → no wisps spawned, internal previous-id
//      set populated.
//  (b) second paint with the same disc list → no new wisps.
//  (c) third paint with one new disc → wisps spawned only for the new
//      disc.
//
// We exercise the atmospheric renderer directly (heavenly mirrors the
// same logic — keeping the test count tight). The renderer's
// WispParticleSystem is injected so we can inspect activeCount without
// reaching into private state.

import 'dart:ui' show Canvas, PictureRecorder, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle_system.dart';

const Size _canvasSize = Size(256, 256);

MirkPaintContext _ctx({required List<RevealDisc> discs, int elapsedMs = 0}) {
  return MirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: 1.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
    discs: discs,
  );
}

RevealDisc _disc(String id, {double lat = 43.5, double lon = 5.5, double radiusMeters = 25.0}) {
  return RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: DateTime.utc(2026, 4, 26));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-010 Option B Commit 5 — wisp emergence on disc-id diff', () {
    test('first paint with seed discs does NOT spawn wisps (resumed-session guard)', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);
      // Three discs already on disk (resumed session).
      final ctx = _ctx(discs: [_disc('rvd_a'), _disc('rvd_b', lat: 43.6), _disc('rvd_c', lat: 43.4)]);
      final recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, ctx);
      recorder.endRecording().dispose();
      expect(
        wispSystem.activeCount,
        0,
        reason:
            'first paint with N discs must seed the previous-id set without spawning — otherwise resuming a session sprays wisps over already-revealed area',
      );
    });

    test('second paint with same disc list spawns no new wisps (steady state)', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);
      final discs = [_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
      final ctx0 = _ctx(discs: discs);
      final ctx1 = _ctx(discs: discs, elapsedMs: 16);
      // First paint — seeds previous-id set.
      var recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, ctx0);
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0);
      // Second paint — same set; emergence diff produces no new ids.
      // Note: advance(dt) on the wisp system between paints decrements
      // life on existing wisps; with zero wisps to begin with, it stays
      // at zero.
      recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, ctx1);
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'no new disc → no wisp spawn → activeCount stays 0');
    });

    test('third paint with one new disc spawns wisps along ITS perimeter only', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);
      final initialDiscs = [_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
      // First paint — seed.
      var recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: initialDiscs));
      recorder.endRecording().dispose();
      // Second paint — same set, no spawns.
      recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: initialDiscs, elapsedMs: 16));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0);

      // Third paint — one extra disc emerges. Wisps spawn along its
      // perimeter; sample count = ceil(2π·25 / kMirkFogMetersPerWisp).
      // Some perimeter points may project off-canvas and get skipped;
      // we just assert a non-trivial count landed.
      final newDiscs = [...initialDiscs, _disc('rvd_new')];
      recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: newDiscs, elapsedMs: 32));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, greaterThan(0), reason: 'a newly-emerged disc must spawn at least one wisp on its perimeter');
      // Upper bound: never exceeds the full ceil(2π·radius / metersPerWisp).
      final expectedSampleCount = (2.0 * 3.1416 * 25.0 / kMirkFogMetersPerWisp).ceil();
      expect(
        wispSystem.activeCount,
        lessThanOrEqualTo(expectedSampleCount),
        reason: 'wisp count for a single disc emergence is bounded by its perimeter sample count',
      );
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-010 Option B Commit 5 — wisp emergence diff test.
//
// The atmospheric + heavenly_clouds renderers spawn wisps on the per-frame
// diff of the disc id set: a fix landing produces exactly one new id
// → renderer notices the new id → spawns N evenly-spaced wisps along
// the disc perimeter.
//
// BUG-015 root-cause fix: instead of a boolean first-paint guard, the
// renderer now has a time-based warm-up phase of
// `kMirkFogWispWarmUpSeconds` seconds. During warm-up, ALL discs that
// enter the viewport are silently ingested into the "already-seen" set
// without spawning wisps. This absorbs both async-delayed disc arrival
// AND the viewport animation (discs scrolling into view during the
// map-open zoom).
//
// Tests cover:
//  (a) During warm-up: N discs present → no wisps spawned, internal
//      previous-id set populated.
//  (b) After warm-up: same disc list → no new wisps.
//  (c) After warm-up: one new disc → wisps spawned only for the new
//      disc.
//  (d) BUG-015: discs leave viewport (discs=[]) then re-enter → no
//      spurious wisps spawned. The append-only previous-id set remembers
//      disc IDs even when they are temporarily absent from the viewport.
//  (e) BUG-015: first paint with 0 discs then discs arrive during
//      warm-up → no spurious wisps spawned.
//  (f) BUG-015 root-cause: discs scroll into viewport during warm-up
//      (viewport animation) → absorbed, no wisps.
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

/// Elapsed millis well past the warm-up threshold — ensures the
/// renderer has exited its ingestion-only phase.
final int _postWarmUpMs = (kMirkFogWispWarmUpSeconds * 1000).toInt() + 500;

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

/// Paints the renderer through the warm-up phase so subsequent paint()
/// calls operate in the live (diff-based) mode. Paints once during
/// warm-up with [seedDiscs], then once more past the warm-up threshold
/// to flip the flag.
void _drainWarmUp(AtmosphericMirkRenderer renderer, List<RevealDisc> seedDiscs) {
  // Paint during warm-up — ingests seed discs.
  var recorder = PictureRecorder();
  renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: seedDiscs, elapsedMs: 100));
  recorder.endRecording().dispose();

  // Paint past warm-up threshold — flips _warmingUp to false.
  recorder = PictureRecorder();
  renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: seedDiscs, elapsedMs: _postWarmUpMs));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-010 Option B Commit 5 — wisp emergence on disc-id diff', () {
    test('during warm-up: seed discs do NOT spawn wisps (resumed-session guard)', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);
      // Three discs already on disk (resumed session). sessionElapsed is
      // within the warm-up window.
      final ctx = _ctx(discs: [_disc('rvd_a'), _disc('rvd_b', lat: 43.6), _disc('rvd_c', lat: 43.4)], elapsedMs: 100);
      final recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, ctx);
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'during warm-up, discs are ingested silently — no wisp spawn');
    });

    test('after warm-up: same disc list spawns no new wisps (steady state)', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);
      final discs = [_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
      _drainWarmUp(renderer, discs);
      expect(wispSystem.activeCount, 0, reason: 'warm-up drain must not spawn wisps');

      // Post-warm-up paint with same disc list — emergence diff empty.
      final recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: discs, elapsedMs: _postWarmUpMs + 16));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'no new disc → no wisp spawn → activeCount stays 0');
    });

    test('after warm-up: one new disc spawns wisps along ITS perimeter only', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);
      final initialDiscs = [_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
      _drainWarmUp(renderer, initialDiscs);
      expect(wispSystem.activeCount, 0);

      // Post-warm-up paint with one extra disc — wisps spawn along its
      // perimeter. Sample count = ceil(2pi * 25 / kMirkFogMetersPerWisp).
      // Some perimeter points may project off-canvas and get skipped;
      // we just assert a non-trivial count landed.
      final newDiscs = [...initialDiscs, _disc('rvd_new')];
      final recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: newDiscs, elapsedMs: _postWarmUpMs + 32));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, greaterThan(0), reason: 'a newly-emerged disc must spawn at least one wisp on its perimeter');
      // Upper bound: never exceeds the full ceil(2pi * radius / metersPerWisp).
      final expectedSampleCount = (2.0 * 3.1416 * 25.0 / kMirkFogMetersPerWisp).ceil();
      expect(
        wispSystem.activeCount,
        lessThanOrEqualTo(expectedSampleCount),
        reason: 'wisp count for a single disc emergence is bounded by its perimeter sample count',
      );
    });

    test('BUG-015: discs leave viewport then re-enter — no spurious wisps', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);
      final discs = [_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
      _drainWarmUp(renderer, discs);
      expect(wispSystem.activeCount, 0);

      // User pans away — discs fall outside viewport bbox → empty list.
      var recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: <RevealDisc>[], elapsedMs: _postWarmUpMs + 16));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0);

      // User pans back — same discs re-enter viewport. Must NOT spawn
      // wisps because these discs were already seen.
      recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: discs, elapsedMs: _postWarmUpMs + 32));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'BUG-015: discs leaving and re-entering the viewport must not be treated as newly emerged');
    });

    test('BUG-015: first paint with 0 discs then discs arrive during warm-up — no spurious wisps', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);

      // First paint — disc provider has not resolved yet, 0 discs.
      var recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: <RevealDisc>[]));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0);

      // Second paint — disc provider resolves with existing discs. Still
      // within warm-up → ingested, not spawned.
      final existingDiscs = [_disc('rvd_a'), _disc('rvd_b', lat: 43.6)];
      recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: existingDiscs, elapsedMs: 100));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'BUG-015: discs arriving during warm-up must not spawn wisps — they are pre-existing, not newly emerged');

      // Third paint — past warm-up threshold, same discs. Warm-up ends,
      // no new disc to spawn.
      recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: existingDiscs, elapsedMs: _postWarmUpMs));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'BUG-015: exiting warm-up with the same disc set must not spawn wisps');
    });

    test('BUG-015 root-cause: discs scrolling into viewport during warm-up are absorbed', () async {
      final wispSystem = WispParticleSystem(rngSeed: 42);
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, wispSystem: wispSystem);
      addTearDown(renderer.dispose);

      // Simulates the viewport animation: disc set grows over several
      // warm-up frames as pre-existing discs scroll into view.
      var recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: [_disc('rvd_a')], elapsedMs: 100));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'warm-up: first disc ingested');

      // A second disc scrolls into viewport during animation.
      recorder = PictureRecorder();
      renderer.paint(Canvas(recorder), _canvasSize, _ctx(discs: [_disc('rvd_a'), _disc('rvd_b', lat: 43.6)], elapsedMs: 500));
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'warm-up: second disc ingested without spawning');

      // More discs keep arriving (user had a long session before).
      recorder = PictureRecorder();
      renderer.paint(
        Canvas(recorder),
        _canvasSize,
        _ctx(discs: [_disc('rvd_a'), _disc('rvd_b', lat: 43.6), _disc('rvd_c', lat: 43.4), _disc('rvd_d', lat: 43.3)], elapsedMs: 2000),
      );
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'warm-up: all scrolled-in discs ingested');

      // Warm-up ends — all 4 discs are in the previous-id set.
      recorder = PictureRecorder();
      renderer.paint(
        Canvas(recorder),
        _canvasSize,
        _ctx(discs: [_disc('rvd_a'), _disc('rvd_b', lat: 43.6), _disc('rvd_c', lat: 43.4), _disc('rvd_d', lat: 43.3)], elapsedMs: _postWarmUpMs),
      );
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, 0, reason: 'BUG-015 root-cause: discs that scrolled in during warm-up must not trigger wisps when warm-up ends');

      // NOW a genuinely new GPS-fix disc arrives — this one SHOULD spawn wisps.
      recorder = PictureRecorder();
      renderer.paint(
        Canvas(recorder),
        _canvasSize,
        _ctx(
          discs: [_disc('rvd_a'), _disc('rvd_b', lat: 43.6), _disc('rvd_c', lat: 43.4), _disc('rvd_d', lat: 43.3), _disc('rvd_fresh_gps')],
          elapsedMs: _postWarmUpMs + 16,
        ),
      );
      recorder.endRecording().dispose();
      expect(wispSystem.activeCount, greaterThan(0), reason: 'post-warm-up: genuinely new disc must spawn wisps');
    });
  });
}

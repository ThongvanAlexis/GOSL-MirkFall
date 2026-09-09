// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-05 — `WispParticleSystem` in world coordinates (POC WISP-02 / WISP-03 /
// WISP-05 port). Spawn on disc emergence (perimeter, idempotent per disc id), 5 s warm-up gate
// driven by an injected `FakeStopwatch`, m/s → degrees integration, LRU cap,
// `advanceFromElapsed` first-call baseline + dt clamp, spawn-rate accessor, clear().

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle_system.dart';

import '../../../_helpers/fake_stopwatch.dart';

const double _centreLat = 48.8566;
const double _centreLon = 2.3522;

/// Past the 5 s warm-up.
const int _postWarmUpMs = 6000;

RevealDisc _disc({String id = 'rvd_test_a', double lat = _centreLat, double lon = _centreLon, double radiusMeters = 25.0}) =>
    RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: DateTime.utc(2026, 5, 4, 12));

WispParticleSystem _warmSystem({int maxCount = kMirkFogWispMaxCount, int rngSeed = 1337}) => WispParticleSystem(
  maxCount: maxCount,
  rngSeed: rngSeed,
  wallClock: FakeStopwatch(initialMs: _postWarmUpMs),
);

void main() {
  group('09.1-05 — WispParticleSystem (WISP-02 / WISP-03 / WISP-05)', () {
    test('starts with zero active wisps', () {
      expect(_warmSystem().activeCount, 0);
    });

    test('spawnAtNewDisc emits ~20 wisps along a 25 m disc perimeter at 8 m spacing — WISP-02', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      // 2π · 25 / 8 ≈ 19.6 → 20; tolerance ±2 for rounding policy.
      expect(system.activeCount, inInclusiveRange(18, 22));
      // Every wisp sits on the perimeter: radius ± jitter (±0.5 m per axis → < 1 m).
      for (final WispParticle w in system.wisps) {
        expect(disc.distanceMetersTo(w.position.latitude, w.position.longitude), closeTo(disc.radiusMeters, 1.0));
      }
      // Distributed AROUND the centre, not collapsed on one side.
      final Iterable<double> latitudes = system.wisps.map((WispParticle w) => w.position.latitude);
      expect(latitudes.reduce(math.max), greaterThan(_centreLat));
      expect(latitudes.reduce(math.min), lessThan(_centreLat));
    });

    test('initial velocity is outward at kMirkWispDriftMetersPerSecond ± 20 % — WISP-02', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      final double metersPerDegreeLon = kMetersPerDegreeLat * math.cos(_centreLat * math.pi / 180.0);
      for (final WispParticle w in system.wisps) {
        final double speed = w.velocityMetersPerSecond.distance;
        expect(speed, inInclusiveRange(kMirkWispDriftMetersPerSecond * 0.8, kMirkWispDriftMetersPerSecond * 1.2));
        // Outward: velocity (east, north) points away from the centre.
        final double eastMeters = (w.position.longitude - _centreLon) * metersPerDegreeLon;
        final double northMeters = (w.position.latitude - _centreLat) * kMetersPerDegreeLat;
        final double dot = eastMeters * w.velocityMetersPerSecond.dx + northMeters * w.velocityMetersPerSecond.dy;
        expect(dot, greaterThan(0.0), reason: 'wisps stream OUT of the revealed disc');
      }
    });

    test('second spawnAtNewDisc with the same discId is idempotent (no double puff) — WISP-02', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      final int first = system.activeCount;
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      expect(system.activeCount, first);
    });

    test('cap respected; LRU evicts by lowest remaining life — WISP-02', () {
      const int testMaxCount = 5;
      final WispParticleSystem system = _warmSystem(maxCount: testMaxCount);
      for (int i = 0; i < 4; i++) {
        final RevealDisc disc = _disc(id: 'rvd_cap_$i', lat: _centreLat + i * 0.0001);
        system.spawnAtNewDisc(discId: disc.id, disc: disc);
      }
      expect(system.activeCount, testMaxCount, reason: 'exactly maxCount survive');
      expect(system.wisps.every((WispParticle w) => w.life == kMirkFogWispLifeSeconds), isTrue, reason: 'survivors are the freshest cohort');
    });

    test('LRU keeps the youngest: aged wisps are evicted before fresh ones', () {
      final WispParticleSystem system = _warmSystem(maxCount: 20);
      final RevealDisc first = _disc(id: 'rvd_old');
      system.spawnAtNewDisc(discId: first.id, disc: first);
      system.advance(0.5);
      final RevealDisc second = _disc(id: 'rvd_new', lat: _centreLat + 0.001);
      system.spawnAtNewDisc(discId: second.id, disc: second);
      expect(system.activeCount, 20);
      expect(system.wisps.every((WispParticle w) => w.life == kMirkFogWispLifeSeconds), isTrue, reason: 'the 20 fresh wisps win the budget');
    });

    test('warm-up: spawnAtNewDisc is a no-op for the first 5 s AND records the discId (post-warm-up re-call no-ops) — WISP-03 / BUG-015', () {
      final FakeStopwatch clock = FakeStopwatch();
      final WispParticleSystem system = WispParticleSystem(wallClock: clock);
      final RevealDisc disc = _disc(id: 'rvd_warmup');
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      expect(system.activeCount, 0, reason: 'warm-up gate suppresses spawn during the first ${kMirkFogWispWarmUpSeconds}s');

      clock.advance(_postWarmUpMs);
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      expect(system.activeCount, 0, reason: 'discId recorded during warm-up blocks the post-warm-up re-call');

      final RevealDisc fresh = _disc(id: 'rvd_fresh');
      system.spawnAtNewDisc(discId: fresh.id, disc: fresh);
      expect(system.activeCount, greaterThan(0), reason: 'a fresh discId after warm-up spawns normally');
    });

    test('warm-up boundary: exactly kMirkFogWispWarmUpSeconds is open, one ms before is closed', () {
      final int warmUpMs = (kMirkFogWispWarmUpSeconds * 1000).round();
      final WispParticleSystem closed = WispParticleSystem(wallClock: FakeStopwatch(initialMs: warmUpMs - 1));
      closed.spawnAtNewDisc(
        discId: 'rvd_a',
        disc: _disc(id: 'rvd_a'),
      );
      expect(closed.activeCount, 0);
      final WispParticleSystem open = WispParticleSystem(wallClock: FakeStopwatch(initialMs: warmUpMs));
      open.spawnAtNewDisc(
        discId: 'rvd_a',
        disc: _disc(id: 'rvd_a'),
      );
      expect(open.activeCount, greaterThan(0));
    });

    test('advance(dt) integrates m/s → degrees (dLat = dy/kMetersPerDegreeLat, dLon = dx/(kMetersPerDegreeLat·cos lat)) — WISP-02', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      final WispParticle w = system.wisps.first;
      final double lat0 = w.position.latitude;
      final double lon0 = w.position.longitude;
      const double dt = 0.1;
      system.advance(dt);
      // The curl acceleration contributes at most kMirkWispCurlAccel·dt² (~5e-3 m at dt 0.1) plus
      // the drag — small against a ~0.15 m drift step, so the drift term must dominate.
      final double cosLat = math.cos(lat0 * math.pi / 180.0);
      final double expectedDLat = w.velocityMetersPerSecond.dy * dt / kMetersPerDegreeLat;
      final double expectedDLon = w.velocityMetersPerSecond.dx * dt / (kMetersPerDegreeLat * cosLat);
      expect(w.position.latitude - lat0, closeTo(expectedDLat, 1e-9));
      expect(w.position.longitude - lon0, closeTo(expectedDLon, 1e-9));
      expect(w.life, closeTo(kMirkFogWispLifeSeconds - dt, 1e-12));
    });

    test('advance(dt) removes dead wisps after the loop (never mutates during iteration)', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      final int before = system.activeCount;
      system.advance(0.001);
      expect(system.activeCount, before, reason: 'tiny step kills nothing');
      for (int i = 0; i < 30; i++) {
        system.advance(0.1);
      }
      expect(system.activeCount, 0, reason: 'after 3 s simulated every wisp (maxLife 2.5 s) is gone');
    });

    test('advanceFromElapsed: first call is a baseline no-op; then integrates Δelapsed; clamps to kMirkWispMaxDtSeconds', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      final WispParticle w = system.wisps.first;
      final double lat0 = w.position.latitude;
      final double lon0 = w.position.longitude;

      system.advanceFromElapsed(const Duration(milliseconds: 100));
      expect(w.position.latitude, lat0, reason: 'first call records the baseline only');
      expect(w.position.longitude, lon0);
      expect(w.life, kMirkFogWispLifeSeconds);

      system.advanceFromElapsed(const Duration(milliseconds: 200));
      expect(w.life, closeTo(kMirkFogWispLifeSeconds - 0.1, 1e-12), reason: 'Δ = 100 ms integrated');

      system.advanceFromElapsed(const Duration(milliseconds: 5200));
      expect(w.life, closeTo(kMirkFogWispLifeSeconds - 0.1 - kMirkWispMaxDtSeconds, 1e-12), reason: 'a 5 s stale delta is clamped to kMirkWispMaxDtSeconds');

      system.advanceFromElapsed(const Duration(milliseconds: 5100));
      expect(
        w.life,
        closeTo(kMirkFogWispLifeSeconds - 0.1 - kMirkWispMaxDtSeconds, 1e-12),
        reason: 'a negative delta (clock went backwards) integrates nothing',
      );
    });

    test('spawnRatePerSecondAndReset returns spawns / interval and resets — WISP-05', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      final int spawned = system.activeCount;
      expect(system.spawnRatePerSecondAndReset(), closeTo(spawned.toDouble(), 1e-9));
      expect(system.spawnRatePerSecondAndReset(), 0.0, reason: 'counter reset');
      final RevealDisc other = _disc(id: 'rvd_b', lat: _centreLat + 0.001);
      system.spawnAtNewDisc(discId: other.id, disc: other);
      expect(system.spawnRatePerSecondAndReset(sinceInterval: const Duration(milliseconds: 500)), closeTo(spawned * 2.0, 1e-9));
    });

    test('clear() empties the list and forgets seen disc ids', () {
      final WispParticleSystem system = _warmSystem();
      final RevealDisc disc = _disc();
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      expect(system.activeCount, greaterThan(0));
      system.clear();
      expect(system.activeCount, 0);
      system.spawnAtNewDisc(discId: disc.id, disc: disc);
      expect(system.activeCount, greaterThan(0), reason: 'a cleared system treats the id as new again');
    });

    test('determinism: same rngSeed → identical positions and velocities', () {
      final WispParticleSystem a = _warmSystem(rngSeed: 42);
      final WispParticleSystem b = _warmSystem(rngSeed: 42);
      final RevealDisc disc = _disc();
      a.spawnAtNewDisc(discId: disc.id, disc: disc);
      b.spawnAtNewDisc(discId: disc.id, disc: disc);
      a.advance(0.1);
      b.advance(0.1);
      expect(a.wisps.map((WispParticle w) => w.position).toList(), b.wisps.map((WispParticle w) => w.position).toList());
      expect(a.wisps.map((WispParticle w) => w.velocityMetersPerSecond).toList(), b.wisps.map((WispParticle w) => w.velocityMetersPerSecond).toList());
    });

    test('curl anchor is the FIRST spawned disc: a far second disc integrates without NaN / blow-up', () {
      final WispParticleSystem system = _warmSystem(maxCount: 1000);
      final RevealDisc paris = _disc(id: 'rvd_paris');
      final RevealDisc marseille = _disc(id: 'rvd_marseille', lat: 43.2965, lon: 5.3698);
      system.spawnAtNewDisc(discId: paris.id, disc: paris);
      system.spawnAtNewDisc(discId: marseille.id, disc: marseille);
      for (int i = 0; i < 10; i++) {
        system.advance(0.1);
      }
      for (final WispParticle w in system.wisps) {
        expect(w.position.latitude.isFinite && w.position.longitude.isFinite, isTrue);
        expect(w.velocityMetersPerSecond.distance, lessThan(kMirkWispDriftMetersPerSecond * 2.0), reason: 'drag bounds the curl acceleration');
      }
    });
  });
}

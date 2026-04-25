// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 BUG-009 (TIER 2) — structural tests for WispParticleSystem.
//
// Tests cover the system's contract without pixel-by-pixel rendering
// (visual is tuned on real device walks):
//   - spawnAtCellCenter creates kMirkFogWispSpawnPerCell particles
//   - LRU eviction enforces the cap
//   - advance(dt) decrements life, eventually evicts dead particles
//   - render does not throw with empty / non-empty population
//   - clear empties the active list

import 'dart:ui' show Canvas, Color, Offset, PictureRecorder;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WispParticleSystem', () {
    test('starts with zero active wisps', () {
      final system = WispParticleSystem();
      expect(system.activeCount, equals(0));
    });

    test('spawnAtCellCenter creates kMirkFogWispSpawnPerCell wisps', () {
      final system = WispParticleSystem();
      system.spawnAtCellCenter(position: const Offset(100, 100), direction: const Offset(1, 0));
      expect(system.activeCount, equals(kMirkFogWispSpawnPerCell));
    });

    test('LRU eviction caps at maxCount when many cells reveal', () {
      final system = WispParticleSystem(maxCount: 10);
      // Spawn enough to overflow: 50 cells × 2 spawns each = 100 raw.
      for (var i = 0; i < 50; i++) {
        system.spawnAtCellCenter(position: Offset(i.toDouble(), i.toDouble()), direction: const Offset(1, 0));
      }
      expect(system.activeCount, equals(10), reason: 'cap must be enforced strictly — no soft overflow');
    });

    test('advance(dt) decrements life and evicts dead particles', () {
      final system = WispParticleSystem();
      system.spawnAtCellCenter(position: const Offset(50, 50), direction: const Offset(1, 0));
      expect(system.activeCount, greaterThan(0));
      // Advance by more than the configured wisp lifetime → all
      // particles die.
      system.advance(kMirkFogWispLifeSeconds * 2.0);
      expect(system.activeCount, equals(0), reason: 'after exceeding maxLife every wisp must be evicted');
    });

    test('advance(dt) leaves non-dead wisps in place', () {
      final system = WispParticleSystem();
      system.spawnAtCellCenter(position: const Offset(50, 50), direction: const Offset(1, 0));
      final initialCount = system.activeCount;
      // Tiny advance — no wisp should hit zero life.
      system.advance(0.001);
      expect(system.activeCount, equals(initialCount));
    });

    test('advance(dt) integrates position via velocity (wisps actually move)', () {
      final system = WispParticleSystem();
      system.spawnAtCellCenter(position: const Offset(100, 100), direction: const Offset(1, 0));
      final initialPositions = system.wisps.map((w) => w.position).toList();
      system.advance(0.5); // Half-second step.
      final newPositions = system.wisps.map((w) => w.position).toList();
      // Positions must have moved — direction (1, 0) × initial speed
      // ~18 px/s × 0.5s ≈ 9 px shift.
      var anyMoved = false;
      for (var i = 0; i < initialPositions.length && i < newPositions.length; i++) {
        if ((initialPositions[i] - newPositions[i]).distanceSquared > 0.01) {
          anyMoved = true;
          break;
        }
      }
      expect(anyMoved, isTrue, reason: 'wisps must have non-zero velocity → measurable position delta after half-second step');
    });

    test('render with zero active wisps does not throw', () {
      final system = WispParticleSystem();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => system.render(canvas, const Color(0xFFFFFFFF)), returnsNormally);
      recorder.endRecording().dispose();
    });

    test('render with active wisps does not throw', () {
      final system = WispParticleSystem();
      system.spawnAtCellCenter(position: const Offset(50, 50), direction: const Offset(1, 0));
      system.spawnAtCellCenter(position: const Offset(150, 150), direction: const Offset(0, 1));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => system.render(canvas, const Color(0xFFFFFFFF)), returnsNormally);
      recorder.endRecording().dispose();
    });

    test('clear() empties the active list', () {
      final system = WispParticleSystem();
      for (var i = 0; i < 5; i++) {
        system.spawnAtCellCenter(position: Offset(i.toDouble() * 10, i.toDouble() * 10), direction: const Offset(1, 0));
      }
      expect(system.activeCount, greaterThan(0));
      system.clear();
      expect(system.activeCount, equals(0));
    });

    test('determinism: same rng seed produces same wisp positions after spawn', () {
      final s1 = WispParticleSystem(rngSeed: 42);
      final s2 = WispParticleSystem(rngSeed: 42);
      s1.spawnAtCellCenter(position: const Offset(100, 100), direction: const Offset(1, 0));
      s2.spawnAtCellCenter(position: const Offset(100, 100), direction: const Offset(1, 0));
      expect(s1.wisps.first.position, equals(s2.wisps.first.position), reason: 'identical seeds must produce identical jitter');
    });

    test('age progresses 0 → 1 over maxLife', () {
      final system = WispParticleSystem();
      system.spawnAtCellCenter(position: const Offset(50, 50), direction: const Offset(1, 0));
      expect(system.wisps.first.age, lessThan(0.01), reason: 'fresh wisp age ≈ 0');
      system.advance(kMirkFogWispLifeSeconds * 0.5);
      expect(system.wisps.first.age, closeTo(0.5, 0.05), reason: 'half-life wisp age ≈ 0.5');
    });
  });
}

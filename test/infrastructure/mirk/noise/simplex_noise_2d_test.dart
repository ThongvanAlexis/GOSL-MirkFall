// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-02 Task 3 RED test suite for `SimplexNoise2D`.
//
// Drives the Ken Perlin 2001 hand-rolled simplex noise body (~60 LOC,
// public-domain algorithm, GOSL-licensed Dart port). Tests are written
// BEFORE the implementation lands — initial run throws UnimplementedError
// (Wave 0 stub), turns green once the body is in place.
//
// Pure-Dart suite — uses `package:test` (NOT `flutter_test`), runs via
// `dart test`. The simplex sampler has zero Flutter dependencies.

import 'dart:math' as math;

import 'package:mirkfall/infrastructure/mirk/noise/simplex_noise_2d.dart';
import 'package:test/test.dart';

void main() {
  group('09-02 — SimplexNoise2D (MIRK-04)', () {
    test('origin sample is finite', () {
      final noise = SimplexNoise2D(seed: 42);
      final sample = noise.noise2(0.0, 0.0);
      expect(sample.isFinite, isTrue);
    });

    test('1000 random samples in [0, 10]² stay within [-1.05, 1.05]', () {
      final noise = SimplexNoise2D(seed: 7);
      final rng = math.Random(42);
      double minSeen = double.infinity;
      double maxSeen = -double.infinity;
      for (int i = 0; i < 1000; i++) {
        final x = rng.nextDouble() * 10.0;
        final y = rng.nextDouble() * 10.0;
        final v = noise.noise2(x, y);
        if (v < minSeen) minSeen = v;
        if (v > maxSeen) maxSeen = v;
      }
      expect(minSeen, greaterThanOrEqualTo(-1.05));
      expect(maxSeen, lessThanOrEqualTo(1.05));
    });

    test('determinism: same seed produces identical sequence (instance equality)', () {
      final a = SimplexNoise2D(seed: 42);
      final b = SimplexNoise2D(seed: 42);
      // Sample the same 16-point grid; every value must match bit-for-bit.
      for (int i = 0; i < 16; i++) {
        final x = i * 0.37;
        final y = i * 0.59;
        expect(a.noise2(x, y), equals(b.noise2(x, y)), reason: 'seed=42 deterministic at ($x, $y)');
      }
    });

    test('determinism: identical (x, y) returns identical value across calls (statelessness)', () {
      final noise = SimplexNoise2D(seed: 99);
      final v1 = noise.noise2(1.5, 2.5);
      final v2 = noise.noise2(1.5, 2.5);
      expect(v1, equals(v2));
    });

    test('different seeds produce different output for at least one sample', () {
      final a = SimplexNoise2D(seed: 1);
      final b = SimplexNoise2D(seed: 2);
      bool diverged = false;
      for (int i = 0; i < 64; i++) {
        final x = i * 0.13;
        final y = i * 0.17;
        if (a.noise2(x, y) != b.noise2(x, y)) {
          diverged = true;
          break;
        }
      }
      expect(diverged, isTrue, reason: 'seeds 1 and 2 must produce at least one different sample over 64 points');
    });

    test('mean of 10 000 samples in [0, 100]² is in [-0.1, 0.1]', () {
      // Simplex noise has approximately zero mean over a large enough sample;
      // a hand-rolled implementation that drifts off-centre is a strong
      // signal of a coefficient or permutation-table bug.
      final noise = SimplexNoise2D(seed: 12345);
      final rng = math.Random(0xC0FFEE);
      double sum = 0.0;
      const int n = 10000;
      for (int i = 0; i < n; i++) {
        final x = rng.nextDouble() * 100.0;
        final y = rng.nextDouble() * 100.0;
        sum += noise.noise2(x, y);
      }
      final mean = sum / n;
      expect(mean, inInclusiveRange(-0.1, 0.1), reason: 'mean=$mean drifted outside the [-0.1, 0.1] band');
    });

    test('noise field is non-constant (the values actually vary)', () {
      // Guard against a stub / accidentally-constant implementation.
      final noise = SimplexNoise2D(seed: 5);
      final samples = <double>[for (int i = 0; i < 32; i++) noise.noise2(i * 0.31, i * 0.47)];
      final unique = samples.toSet();
      expect(unique.length, greaterThan(1), reason: 'noise2 returned the same value for 32 different inputs — constant function?');
    });
  });
}

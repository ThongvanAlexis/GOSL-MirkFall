// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/mirk/animation_helpers.dart';

/// Unit tests for [triangleWave] — the generic helper that animates
/// curlScale (and any future tunable adopting the same pattern).
void main() {
  group('triangleWave', () {
    test('at t=0 returns minV', () {
      final v = triangleWave(tSec: 0.0, period: 20.0, minV: 0.0, maxV: 10.0);
      expect(v, closeTo(0.0, 1e-12));
    });

    test('at t=period/4 (rising half) returns mid value (minV + maxV) / 2', () {
      final v = triangleWave(tSec: 5.0, period: 20.0, minV: 0.0, maxV: 10.0);
      expect(v, closeTo(5.0, 1e-12));
    });

    test('at t=period/2 returns maxV (the apex of the triangle)', () {
      final v = triangleWave(tSec: 10.0, period: 20.0, minV: 0.0, maxV: 10.0);
      expect(v, closeTo(10.0, 1e-12));
    });

    test('at t=3·period/4 (falling half) returns mid value', () {
      final v = triangleWave(tSec: 15.0, period: 20.0, minV: 0.0, maxV: 10.0);
      expect(v, closeTo(5.0, 1e-12));
    });

    test('at t=period returns minV (cycle restart)', () {
      final v = triangleWave(tSec: 20.0, period: 20.0, minV: 0.0, maxV: 10.0);
      expect(v, closeTo(0.0, 1e-12));
    });

    test('wraps past period (t=period + period/2 ≡ period/2 → maxV)', () {
      final v = triangleWave(tSec: 30.0, period: 20.0, minV: 0.0, maxV: 10.0);
      expect(v, closeTo(10.0, 1e-12));
    });

    test('respects non-zero minV and arbitrary maxV', () {
      // [2..8] over period 4. At t=2 (period/2) we expect maxV=8.
      final v = triangleWave(tSec: 2.0, period: 4.0, minV: 2.0, maxV: 8.0);
      expect(v, closeTo(8.0, 1e-12));
    });

    test('returns minV when period <= 0 (guard against div-by-zero in paint)', () {
      expect(triangleWave(tSec: 5.0, period: 0.0, minV: 1.0, maxV: 9.0), equals(1.0));
      expect(triangleWave(tSec: 5.0, period: -1.0, minV: 1.0, maxV: 9.0), equals(1.0));
    });

    test('output stays within [minV, maxV] across a fine sample of t', () {
      const minV = 0.0;
      const maxV = 10.0;
      const period = 20.0;
      // 200 samples over two full periods — every emitted value must
      // sit on the [minV..maxV] segment.
      for (var i = 0; i < 200; i++) {
        final tSec = (i / 200.0) * (period * 2.0);
        final v = triangleWave(tSec: tSec, period: period, minV: minV, maxV: maxV);
        expect(v, greaterThanOrEqualTo(minV));
        expect(v, lessThanOrEqualTo(maxV));
      }
    });
  });
}

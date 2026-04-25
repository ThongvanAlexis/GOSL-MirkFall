// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:test/test.dart';

/// Wave 0 scaffold for `computeRevealMask` bbox-first intersect correctness
/// (MIRK-01). The Phase 03 algebra suite at
/// `test/domain/reveal_calculator_test.dart` already covers the bytewise
/// merge — this file extends with the geometric reveal computation that
/// the Phase 09 streaming controller exercises end-to-end.
///
/// Bodies land in plan 09-02 once `computeRevealMask` ships its
/// production signature; until then every test is `skip:`-guarded so
/// `dart test` reports them as skipped rather than failing on a missing
/// import.
void main() {
  group('09-02 — computeRevealMask (MIRK-01)', () {
    test('single-tile reveal: fix at tile center → all 64×64 cells set within radius', () {
      // Wave 2 body: invoke computeRevealMask(fix, parentZoomTile)
      // with a fix at the tile center + 25 m radius, assert the
      // returned bitmap has the expected disc of set cells.
    }, skip: 'Wave 2 — plan 09-02');

    test('bbox-first short-circuit skips parent tiles outside fix bbox', () {
      // Wave 2 body: feed a parent tile far from the fix, assert
      // computeRevealMask returns null / empty without entering the
      // per-cell loop (observable via a counter or pure-result shape).
    }, skip: 'Wave 2 — plan 09-02');

    test('feather band at radius edge sets fractional alpha cells', () {
      // Wave 2 body: assert the outer ~10% of the radius produces
      // partially-set cells (matching kMirkFeatherFraction in
      // lib/config/constants.dart).
    }, skip: 'Wave 2 — plan 09-02');
  });
}

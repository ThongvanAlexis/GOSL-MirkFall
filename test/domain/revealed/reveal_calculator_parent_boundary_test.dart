// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:test/test.dart';

/// Wave 0 scaffold for the parent-tile boundary split case (MIRK-01).
///
/// When a fix lies near the edge of a zoom-14 parent tile, `computeRevealMask`
/// must split the reveal across two parent-tile bitmaps (each capturing the
/// portion of the disc that intersects its own tile). Bodies land in plan
/// 09-02; until then `skip:`-guarded so the suite stays green.
void main() {
  group('09-02 — computeRevealMask parent-tile boundary split (MIRK-01)', () {
    test('fix on east edge of parent tile produces two masks (east + west neighbour)', () {
      // Wave 2 body: place a fix at tile.lon + (tileWidth - epsilon),
      // assert returned list has two entries with distinct parent
      // tile coordinates and complementary covered cells.
    }, skip: 'Wave 2 — plan 09-02');

    test('fix on south edge produces north + south neighbour masks', () {
      // Wave 2 body: south-edge variant.
    }, skip: 'Wave 2 — plan 09-02');

    test('fix at parent tile corner produces up to 4 masks (one per quadrant)', () {
      // Wave 2 body: corner case — disc straddles 4 parent tiles.
    }, skip: 'Wave 2 — plan 09-02');
  });
}

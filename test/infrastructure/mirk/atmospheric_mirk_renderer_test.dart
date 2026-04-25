// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for `AtmosphericMirkRenderer` (MIRK-04 default builtin).
///
/// Bodies land in plan 09-04. Tests record two PictureRecorder frames at
/// different `update(elapsed)` deltas and assert the output bytes differ
/// (animation proof). Until 09-04 ships, every test is `skip:`-guarded.
void main() {
  group('09-04 — AtmosphericMirkRenderer (MIRK-04)', () {
    testWidgets('paint() output differs across frames (animation proof)', (tester) async {
      // Wave 3 body: render two frames via PictureRecorder + Canvas,
      // assert picture bytes differ. Golden-compatible tolerance.
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('noise respects kMirkNoiseScaleDefault by default', (tester) async {
      // Wave 3 body: instantiate with default config, assert the
      // sampled noise frequency matches the constant.
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('dispose() is idempotent', (tester) async {
      // Wave 3 body: instantiate, paint once, dispose twice, assert
      // no throw on second dispose call.
      // Wave 3 — plan 09-04
    }, skip: true);
  });
}

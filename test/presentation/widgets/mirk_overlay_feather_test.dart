// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for `MirkOverlay` feather rendering (MIRK-01).
///
/// Bodies land in plan 09-05. The overlay must render the reveal disc
/// with a feathered band (~10% of radius) around its edge so the
/// transition between fog and revealed area is gradient, not stepped.
void main() {
  group('09-05 — MirkOverlay feather (MIRK-01)', () {
    testWidgets('feather band width is ~10% of revealed radius', (tester) async {
      // Wave 4 body: render overlay with a single revealed tile,
      // sample alpha values along a radial line, assert the
      // gradient band width matches kMirkFeatherFraction * radius.
      // Wave 4 — plan 09-05
    }, skip: true);

    testWidgets('feather preserves full opacity at disc center', (tester) async {
      // Wave 4 body: sample center pixel alpha, assert == 0
      // (fully revealed, no fog).
      // Wave 4 — plan 09-05
    }, skip: true);

    testWidgets('feather reaches max opacity outside the disc', (tester) async {
      // Wave 4 body: sample pixel beyond radius + feather, assert
      // alpha matches the configured fog-overlay max opacity.
      // Wave 4 — plan 09-05
    }, skip: true);
  });
}

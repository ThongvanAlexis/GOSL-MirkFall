// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for `MirkOverlay` composition with the base map
/// (MAP-04 conformance + Phase 09 integration).
///
/// Bodies land in plan 09-05. The overlay sits ABOVE the MapLibre
/// platform view and BELOW the user-location puck (per
/// `kStyleLayerOrder` in lib/presentation/map_screen.dart). This suite
/// asserts the z-order + paint compositing.
void main() {
  group('09-05 — MirkOverlay composition (MAP-04)', () {
    testWidgets('overlay renders ABOVE base map tiles (z-order check)', (tester) async {
      // Wave 4 body: pump MapScreen with a single revealed tile,
      // sample pixels at fog regions, assert the fog colour is
      // visible (not transparent over base tiles).
      // Wave 4 — plan 09-05
    }, skip: true);

    testWidgets('overlay renders BELOW user-location puck (puck not occluded)', (tester) async {
      // Wave 4 body: place puck at fog area, assert puck pixels
      // are visible (overlay does not paint over them).
      // Wave 4 — plan 09-05
    }, skip: true);

    testWidgets('revealed area shows base map (not fog) through the disc', (tester) async {
      // Wave 4 body: sample pixels inside the reveal disc, assert
      // base map colours visible (not fog).
      // Wave 4 — plan 09-05
    }, skip: true);
  });
}

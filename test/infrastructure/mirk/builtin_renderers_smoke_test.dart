// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for the 4-builtin smoke suite (MIRK-06).
///
/// Bodies land in plan 09-04. Each of the 4 builtin renderers must
/// instantiate with its default config + run paint+update+dispose
/// without throw. Cheap canary that catches missing constructor
/// arguments / null derefs across the variant set in one place.
void main() {
  group('09-04 — Builtin renderers smoke (MIRK-06)', () {
    testWidgets('AtmosphericMirkRenderer instantiates + paint/update/dispose without throw', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('SolidFillMirkRenderer instantiates + paint/update/dispose without throw', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('CandlelightMirkRenderer instantiates + paint/update/dispose without throw', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('HeavenlyCloudsMirkRenderer instantiates + paint/update/dispose without throw', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);
  });
}

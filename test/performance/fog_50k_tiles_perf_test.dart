// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(<String>['mirk-perf'])
library;

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for the 50k-tile fog perf probe (SC#4).
///
/// Library-level `@Tags(['mirk-perf'])` excludes this from the default
/// `flutter test` run (same on-demand discipline as the Phase 07 `soak`
/// tag). Gate command:
///   flutter test --tags mirk-perf test/performance/fog_50k_tiles_perf_test.dart
///
/// Bodies land in plan 09-08 once the deterministic fixture builder
/// (`tool/fixtures/build_50k_tiles.dart`) ships its real output.
void main() {
  group('09-08 — 50k tiles perf (SC#4)', () {
    testWidgets('paint pass ≤ 16 ms on the 50k-row fixture', (tester) async {
      // Wave 7 body: load fifty_k_tiles_seed.sql into a Drift
      // NativeDatabase.memory(), pump MapScreen with the fixture,
      // measure paint pass duration via Timeline / Stopwatch around
      // a single frame, assert ≤ 16 ms (60 FPS budget).
      // Wave 7 — plan 09-08
    }, skip: true);

    testWidgets('viewport filtering keeps painted tile count under the perf budget', (tester) async {
      // Wave 7 body: assert at most ~150 tiles pass through the
      // viewport filter at zoom 14 with the 50k-row fixture loaded.
      // Wave 7 — plan 09-08
    }, skip: true);
  });
}

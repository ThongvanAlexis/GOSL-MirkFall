// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for `MirkRendererFactory` (MIRK-05 dispatcher).
///
/// Bodies land in plan 09-04. The factory takes a `MirkStyleConfig`
/// sealed union and dispatches exhaustively to the 6 renderer variants.
/// Tests verify each variant constructs the right concrete type +
/// `UnknownConfig` falls back safely.
void main() {
  group('09-04 — MirkRendererFactory (MIRK-05)', () {
    testWidgets('AtmosphericConfig → AtmosphericMirkRenderer', (tester) async {
      // Wave 3 body: factory(AtmosphericConfig(...)) instanceof
      // AtmosphericMirkRenderer.
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('SolidConfig → SolidFillMirkRenderer', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('CandlelightConfig → CandlelightMirkRenderer', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('HeavenlyConfig → HeavenlyCloudsMirkRenderer', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('ShaderConfig → ShaderMirkRenderer', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('UnknownConfig → fallback renderer (NoopMirkRenderer or sentinel)', (tester) async {
      // Wave 3 body: feed UnknownConfig.fromJson with an unknown
      // rendererType, assert factory returns a safe non-throwing
      // renderer (decision: NoopMirkRenderer per 09-RESEARCH).
      // Wave 3 — plan 09-04
    }, skip: true);
  });
}

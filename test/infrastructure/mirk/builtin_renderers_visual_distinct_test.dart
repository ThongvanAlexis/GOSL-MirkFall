// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for the visual-distinctness check across the 4 builtins
/// (MIRK-06).
///
/// Bodies land in plan 09-04. Each pair of builtin renderers must produce
/// distinct paint output at the same frame — a guard against accidental
/// duplicate variants (two configs collapsing to identical pixels). The
/// distinct-paint assertion uses a tolerance-aware byte diff, not strict
/// equality (alpha rounding is acceptable; structurally identical output
/// is not).
void main() {
  group('09-04 — Builtin renderers visual distinctness (MIRK-06)', () {
    testWidgets('Atmospheric vs Solid produce distinct paint output', (tester) async {
      // Wave 3 body: render both at frame t=0 with default configs,
      // assert byte-diff exceeds the noise floor.
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('Atmospheric vs Candlelight produce distinct paint output', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('Atmospheric vs HeavenlyClouds produce distinct paint output', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('Solid vs Candlelight produce distinct paint output', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('Solid vs HeavenlyClouds produce distinct paint output', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);

    testWidgets('Candlelight vs HeavenlyClouds produce distinct paint output', (tester) async {
      // Wave 3 — plan 09-04
    }, skip: true);
  });
}

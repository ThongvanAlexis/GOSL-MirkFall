// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for `MirkStyleSessionController` (MIRK-07).
///
/// Manages the active session's selected mirk style — burger-menu picker
/// calls into this controller, which persists to `t_sessions.mirk_style_id`.
/// Bodies land in plan 09-07.
void main() {
  group('09-07 — MirkStyleSessionController (MIRK-07)', () {
    testWidgets('select(styleId) writes mirk_style_id to t_sessions', (tester) async {
      // Wave 6 body: drive controller.select(styleId), assert
      // SessionStore.updateMirkStyle(...) was called with the
      // active session id + the chosen style id.
      // Wave 6 — plan 09-07
    }, skip: true);

    testWidgets('select(unknownStyleId) throws StyleNotFoundException', (tester) async {
      // Wave 6 body: feed a non-builtin, non-imported style id,
      // assert the controller surfaces the error without writing.
      // Wave 6 — plan 09-07
    }, skip: true);

    testWidgets('select(currentStyleId) is a no-op (idempotent)', (tester) async {
      // Wave 6 body: select the already-active style, assert no
      // store write — keeps audit logs clean and avoids redundant
      // Drift transactions.
      // Wave 6 — plan 09-07
    }, skip: true);
  });
}

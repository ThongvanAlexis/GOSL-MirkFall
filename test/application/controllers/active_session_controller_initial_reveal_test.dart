// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for the ActiveSessionController initial-reveal group
/// (MIRK-01: 20 m starter reveal at session start).
///
/// New file — kept ISOLATED from `active_session_controller_test.dart`
/// (Phase 05) so the initial-reveal group can grow independently
/// without coupling to the existing GPS lifecycle test setup.
///
/// Bodies land in plan 09-06. Two paths covered:
/// - First fix arrives within the wait window → merge with starter reveal.
/// - No fix within the wait window → starter reveal stays at last-known.
void main() {
  group('09-06 — ActiveSessionController initial reveal (MIRK-01)', () {
    testWidgets('session start with fix within window: 20 m disc revealed at fix location', (tester) async {
      // Wave 5 body: start session, deliver one fix, advance time
      // past kInitialRevealWaitMs, assert RevealedTileStore received
      // a 20 m-radius merge at the fix coordinates.
      // Wave 5 — plan 09-06
    }, skip: true);

    testWidgets('session start with no fix within window: 20 m disc at last-known position', (tester) async {
      // Wave 5 body: start session, deliver NO fix, advance time
      // past the wait window, assert merge falls back to the
      // last-known position from SharedPreferences (or app default).
      // Wave 5 — plan 09-06
    }, skip: true);

    testWidgets('starter reveal radius matches kInitialRevealRadiusMeters', (tester) async {
      // Wave 5 body: assert disc radius equals the constant.
      // Wave 5 — plan 09-06
    }, skip: true);
  });
}

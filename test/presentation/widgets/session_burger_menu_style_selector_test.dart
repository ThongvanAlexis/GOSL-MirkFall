// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave 0 scaffold for the burger-menu style selector (MIRK-07).
///
/// The session burger menu (existing widget — `session_burger_menu.dart`)
/// gains a "Style" submenu in plan 09-07 listing the 4 builtins + the
/// user-imported set. Bodies land in plan 09-07.
void main() {
  group('09-07 — SessionBurgerMenu style selector (MIRK-07)', () {
    testWidgets('opening the menu shows 4 builtin options', (tester) async {
      // Wave 6 body: pump SessionBurgerMenu under MaterialApp,
      // tap the burger icon, expect 4 builtin entries (atmospheric,
      // solid, candlelight, heavenly).
      // Wave 6 — plan 09-07
    }, skip: true);

    testWidgets('selecting a style invokes MirkStyleSessionController.select(styleId)', (tester) async {
      // Wave 6 body: tap a style entry, assert the fake controller
      // recorded one selectCalls entry with matching style id.
      // Wave 6 — plan 09-07
    }, skip: true);

    testWidgets('currently-selected style is visually marked (checkmark / radio)', (tester) async {
      // Wave 6 body: seed with a chosen style, open menu, assert
      // the matching entry shows the active-state visual marker.
      // Wave 6 — plan 09-07
    }, skip: true);

    testWidgets('imported user styles appear under their own header', (tester) async {
      // Wave 6 body: seed style repository with one user-imported
      // entry, assert it appears under "Importé" / "User" header
      // separate from builtins.
      // Wave 6 — plan 09-07
    }, skip: true);
  });
}

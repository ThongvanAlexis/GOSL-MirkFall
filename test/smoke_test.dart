// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/app.dart';
import 'package:mirkfall/config/constants.dart';

void main() {
  testWidgets('MirkFallApp pumps and renders the Phase 01 placeholder home', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MirkFallApp()));
    await tester.pump();

    expect(find.text('MirkFall — bootstrap OK'), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text(kAppName)), findsOneWidget);
  });
}

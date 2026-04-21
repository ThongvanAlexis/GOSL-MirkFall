// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/presentation/screens/style_import_placeholder_screen.dart';

void main() {
  group('StyleImportPlaceholderScreen', () {
    testWidgets('shows "En construction" copy', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StyleImportPlaceholderScreen()));
      expect(find.text('En construction — disponible en Phase 13'), findsOneWidget);
      expect(find.text('Importer un style de mirk'), findsOneWidget);
    });

    testWidgets('AppBar back arrow is visible when there is a prior route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StyleImportPlaceholderScreen())),
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Default AppBar leading is the back arrow (BackButton) when there
      // is something on the navigator stack.
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('En construction — disponible en Phase 13'), findsOneWidget);
    });
  });
}

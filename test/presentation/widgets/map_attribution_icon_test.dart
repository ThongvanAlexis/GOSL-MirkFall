// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/presentation/widgets/map_attribution_icon.dart';

void main() {
  group('MapAttributionIcon', () {
    testWidgets('renders an info icon by default', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MapAttributionIcon())),
      ));
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      // Bottom sheet is not yet visible.
      expect(find.text('Attribution'), findsNothing);
    });

    testWidgets('tap opens a bottom sheet listing OSM + Protomaps', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MapAttributionIcon())),
      ));
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('Attribution'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('© Protomaps'), findsOneWidget);
    });

    testWidgets('tapping a link copies the URL to the clipboard', (tester) async {
      // Install a fake clipboard capture on the platform channel.
      final List<MethodCall> clipboardCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add(call);
        }
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MapAttributionIcon())),
      ));
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('© OpenStreetMap contributors'));
      await tester.pump();

      expect(clipboardCalls, isNotEmpty);
      final Map<Object?, Object?> args = clipboardCalls.last.arguments as Map<Object?, Object?>;
      expect(args['text'], contains('openstreetmap.org/copyright'));
    });
  });
}

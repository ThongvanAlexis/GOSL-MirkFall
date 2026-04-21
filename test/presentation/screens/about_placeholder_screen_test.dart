// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/presentation/screens/about_placeholder_screen.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/about',
    routes: <RouteBase>[
      GoRoute(path: '/about', builder: (_, _) => child),
      GoRoute(path: '/debug', builder: (_, _) => const Scaffold(body: Text('debug'))),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('AboutPlaceholderScreen attribution block (Task 4 — MAP-03 SC#2)', () {
    testWidgets('renders both attribution lines exactly once', (tester) async {
      await tester.pumpWidget(_wrap(const AboutPlaceholderScreen()));
      await tester.pumpAndSettle();

      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('© Protomaps'), findsOneWidget);
    });

    testWidgets('tap on OpenStreetMap link copies the URL + shows snackbar', (tester) async {
      final List<MethodCall> clipboardCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(_wrap(const AboutPlaceholderScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('© OpenStreetMap contributors'));
      await tester.pump();

      expect(clipboardCalls, isNotEmpty);
      final Map<Object?, Object?> args = clipboardCalls.last.arguments as Map<Object?, Object?>;
      expect(args['text'], contains('openstreetmap.org/copyright'));
      // Snackbar surfaces the copied URL.
      expect(find.textContaining('URL copiée'), findsOneWidget);
    });

    testWidgets('tap on Protomaps link copies the URL', (tester) async {
      final List<MethodCall> clipboardCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(_wrap(const AboutPlaceholderScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('© Protomaps'));
      await tester.pump();

      expect(clipboardCalls, isNotEmpty);
      final Map<Object?, Object?> args = clipboardCalls.last.arguments as Map<Object?, Object?>;
      expect(args['text'], contains('protomaps.com'));
    });

    testWidgets('7-tap easter egg still fires on body area (unchanged Phase 01 behaviour)', (tester) async {
      await tester.pumpWidget(_wrap(const AboutPlaceholderScreen()));
      await tester.pumpAndSettle();

      // Tap on the body (non-link area) 7 times within the tap window.
      for (int i = 0; i < kAboutTapsToTriggerDebugMenu; i++) {
        // Tap on the title text — part of the body area fed into the
        // GestureDetector's onTap counter.
        await tester.tap(find.textContaining('Placeholder À propos'));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();

      // /debug route landed.
      expect(find.text('debug'), findsOneWidget);
    });

    testWidgets('tap on a link does NOT increment the easter-egg counter', (tester) async {
      // Install a no-op clipboard handler so taps don't error.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(_wrap(const AboutPlaceholderScreen()));
      await tester.pumpAndSettle();

      // 6 taps on the link — should NOT fire the counter (links consume
      // their own gesture). Then 1 body tap — counter is still at 1.
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('© OpenStreetMap contributors'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.textContaining('Placeholder À propos'));
      await tester.pumpAndSettle();

      // /debug must NOT have been reached — link taps did not increment.
      expect(find.text('debug'), findsNothing);
    });
  });
}

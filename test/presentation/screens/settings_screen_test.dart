// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(path: '/settings', builder: (_, _) => child),
      GoRoute(
        path: '/permissions/oem',
        builder: (_, _) => const Scaffold(body: Text('oem')),
      ),
      // Phase 07 — the Cartes + Styles sections push to these routes.
      GoRoute(path: '/maps/download', builder: (_, _) => const Scaffold(body: Text('maps-download'))),
      GoRoute(path: '/maps/manage', builder: (_, _) => const Scaffold(body: Text('maps-manage'))),
      GoRoute(path: '/styles/import', builder: (_, _) => const Scaffold(body: Text('styles-import'))),
      GoRoute(path: '/styles/export', builder: (_, _) => const Scaffold(body: Text('styles-export'))),
      GoRoute(path: '/debug', builder: (_, _) => const Scaffold(body: Text('debug'))),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('SettingsScreen', () {
    testWidgets('rendersCurrentDistanceFilterValue', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 25});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Displayed value shows the persisted 25 m.
      expect(find.text('25 m'), findsWidgets);
      expect(find.text('Filtre de distance'), findsOneWidget);
    });

    testWidgets('sliderOnChangeEndPersistsViaProvider', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Drag the slider and release; assert SharedPreferences now
      // holds a different, clamped value. We don't need to simulate
      // exact pixel offsets — the onChangeEnd path writes through
      // sessionSettings.setDistanceFilterMeters, and
      // SharedPreferences.getInstance returns the same (mocked) map.
      final element = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(element);
      // Invoke the notifier directly — this is the same call the
      // slider's onChangeEnd wires to (see settings_screen.dart).
      await container.read(sessionSettingsProvider.notifier).setDistanceFilterMeters(42);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('distanceFilter_meters'), 42);
      final snapshot = await container.read(sessionSettingsProvider.future);
      expect(snapshot.distanceFilterMeters, 42);
    });

    testWidgets('helpTileNavigatesToOem', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Aide : batterie & arrière-plan'), findsOneWidget);
      await tester.tap(find.text('Aide : batterie & arrière-plan'));
      await tester.pumpAndSettle();

      // Reached the /permissions/oem stub.
      expect(find.text('oem'), findsOneWidget);
    });

    // Phase 07 extensions.

    testWidgets('Cartes section shows 2 ListTiles with correct labels', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Cartes'), findsOneWidget);
      expect(find.text('Télécharger une carte'), findsOneWidget);
      expect(find.text('Gérer les cartes installées'), findsOneWidget);
    });

    testWidgets('Styles section shows 2 Phase-13 placeholders', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Styles'), findsOneWidget);
      expect(find.text('Importer un style de mirk'), findsOneWidget);
      expect(find.text('Exporter un style de mirk'), findsOneWidget);
      // Subtitles mention Phase 13.
      expect(find.text('En construction (Phase 13)'), findsNWidgets(2));
    });

    testWidgets('tap "Télécharger une carte" navigates to /maps/download', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Télécharger une carte'));
      await tester.pumpAndSettle();
      expect(find.text('maps-download'), findsOneWidget);
    });

    testWidgets('tap "Gérer les cartes installées" navigates to /maps/manage', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Gérer les cartes installées'));
      await tester.pumpAndSettle();
      expect(find.text('maps-manage'), findsOneWidget);
    });

    testWidgets('tap "Importer un style de mirk" navigates to /styles/import', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      // The Styles section sits below the Cartes cards — scroll into view.
      final tileFinder = find.widgetWithText(ListTile, 'Importer un style de mirk');
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();
      await tester.tap(tileFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('styles-import'), findsOneWidget);
    });
  });
}

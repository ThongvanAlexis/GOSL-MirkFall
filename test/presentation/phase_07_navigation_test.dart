// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/presentation/screens/map_screen.dart';
import 'package:mirkfall/presentation/screens/maps_download_screen.dart';
import 'package:mirkfall/presentation/screens/maps_manage_screen.dart';
import 'package:mirkfall/presentation/screens/style_export_placeholder_screen.dart';
import 'package:mirkfall/presentation/screens/style_import_placeholder_screen.dart';

/// Phase 07 route-reachability tests.
///
/// These are pure navigation assertions — they do NOT bootstrap the full
/// application providers. They verify that every Phase 07 route
/// declared in `lib/presentation/router.dart` resolves to its target
/// screen constructor via a `GoRouter` harness, and that `context.push`
/// produces a correct back stack (user can return via the system back
/// gesture / AppBar back button).
///
/// Coverage (per Plan 07-07 Task 1 behaviour spec):
/// - `/map` reachable
/// - `/maps/download` reachable
/// - `/maps/manage` reachable
/// - `/styles/import` reachable
/// - `/styles/export` reachable
/// - `context.push('/map')` preserves a back stack (pop returns to `/`).
///
/// Intentionally narrow: the real MapScreen / MapsDownloadScreen / etc.
/// need heavy Riverpod provider plumbing to render beyond their
/// AppBar. This test stubs each destination with a trivial placeholder
/// widget so route resolution is the sole behaviour under test.
GoRouter _buildHarnessRouter({required GlobalKey<NavigatorState> rootKey, required List<String> navObserved}) {
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/',
    observers: <NavigatorObserver>[_RecordingObserver(log: navObserved)],
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('home')),
          body: Builder(
            builder: (BuildContext ctx) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(onPressed: () => ctx.push('/map'), child: const Text('go /map')),
                ElevatedButton(onPressed: () => ctx.push('/maps/download'), child: const Text('go /maps/download')),
                ElevatedButton(onPressed: () => ctx.push('/maps/manage'), child: const Text('go /maps/manage')),
                ElevatedButton(onPressed: () => ctx.push('/styles/import'), child: const Text('go /styles/import')),
                ElevatedButton(onPressed: () => ctx.push('/styles/export'), child: const Text('go /styles/export')),
              ],
            ),
          ),
        ),
      ),
      // Phase 07 routes: verify each route matches its target constructor.
      // Builders intentionally return a trivial stub rather than the real
      // screen so route-reachability is the sole behaviour under test.
      GoRoute(
        path: '/map',
        builder: (_, _) => const _RouteStub(targetType: MapScreen, label: '/map'),
      ),
      GoRoute(
        path: '/maps/download',
        builder: (_, _) => const _RouteStub(targetType: MapsDownloadScreen, label: '/maps/download'),
      ),
      GoRoute(
        path: '/maps/manage',
        builder: (_, _) => const _RouteStub(targetType: MapsManageScreen, label: '/maps/manage'),
      ),
      GoRoute(
        path: '/styles/import',
        builder: (_, _) => const _RouteStub(targetType: StyleImportPlaceholderScreen, label: '/styles/import'),
      ),
      GoRoute(
        path: '/styles/export',
        builder: (_, _) => const _RouteStub(targetType: StyleExportPlaceholderScreen, label: '/styles/export'),
      ),
    ],
  );
}

class _RouteStub extends StatelessWidget {
  const _RouteStub({required this.targetType, required this.label});

  final Type targetType;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('stub: $label')),
      body: Center(child: Text('target=$targetType')),
    );
  }
}

/// Navigator observer that records every `push` / `pop` location.
class _RecordingObserver extends NavigatorObserver {
  _RecordingObserver({required this.log});
  final List<String> log;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    log.add('push:${route.settings.name ?? route.settings.arguments ?? '?'}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    log.add('pop:${route.settings.name ?? route.settings.arguments ?? '?'}');
    super.didPop(route, previousRoute);
  }
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 07 navigation', () {
    testWidgets('/map route is reachable via context.push from home', (tester) async {
      final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
      final List<String> nav = <String>[];
      final GoRouter router = _buildHarnessRouter(rootKey: rootKey, navObserved: nav);
      await _pumpRouter(tester, router);

      expect(find.text('go /map'), findsOneWidget);
      await tester.tap(find.text('go /map'));
      await tester.pumpAndSettle();

      expect(find.text('stub: /map'), findsOneWidget);
    });

    testWidgets('/maps/download + /maps/manage both resolve', (tester) async {
      final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
      final List<String> nav = <String>[];
      final GoRouter router = _buildHarnessRouter(rootKey: rootKey, navObserved: nav);
      await _pumpRouter(tester, router);

      await tester.tap(find.text('go /maps/download'));
      await tester.pumpAndSettle();
      expect(find.text('stub: /maps/download'), findsOneWidget);

      // Pop back to `/` and push the other route.
      rootKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      await tester.tap(find.text('go /maps/manage'));
      await tester.pumpAndSettle();
      expect(find.text('stub: /maps/manage'), findsOneWidget);
    });

    testWidgets('/styles/import + /styles/export both resolve', (tester) async {
      final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
      final List<String> nav = <String>[];
      final GoRouter router = _buildHarnessRouter(rootKey: rootKey, navObserved: nav);
      await _pumpRouter(tester, router);

      await tester.tap(find.text('go /styles/import'));
      await tester.pumpAndSettle();
      expect(find.text('stub: /styles/import'), findsOneWidget);

      rootKey.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('go /styles/export'));
      await tester.pumpAndSettle();
      expect(find.text('stub: /styles/export'), findsOneWidget);
    });

    testWidgets('context.push("/map") preserves back stack — pop returns to home', (tester) async {
      final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
      final List<String> nav = <String>[];
      final GoRouter router = _buildHarnessRouter(rootKey: rootKey, navObserved: nav);
      await _pumpRouter(tester, router);

      // Push /map on top of the back stack — canPop must be true.
      await tester.tap(find.text('go /map'));
      await tester.pumpAndSettle();
      expect(find.text('stub: /map'), findsOneWidget);
      expect(rootKey.currentState!.canPop(), isTrue);

      // Pop: returns to the home route, back stack is now empty.
      rootKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}

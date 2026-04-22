// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/presentation/screens/permission_denied_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/permissions/denied',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/permissions/denied', builder: (_, _) => child),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

/// Pushes [child] onto an initial host route + captures the pop result
/// so a test can assert what the denied screen returned.
Widget _wrapWithHostRoute(Widget child, void Function(Object?) onDeniedPopped) {
  final router = GoRouter(
    initialLocation: '/host',
    routes: <RouteBase>[
      GoRoute(
        path: '/host',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: FilledButton(
                onPressed: () async {
                  final Object? result = await ctx.push<bool>('/permissions/denied');
                  onDeniedPopped(result);
                },
                child: const Text('open denied'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(path: '/permissions/denied', builder: (_, _) => child),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('PermissionDeniedScreen', () {
    testWidgets('openSettingsInvokesHandler', (tester) async {
      int invocations = 0;
      await tester.pumpWidget(
        _wrap(
          PermissionDeniedScreen(
            openLocationSettingsFn: () async {
              invocations++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ouvrir les paramètres'));
      await tester.pumpAndSettle();

      expect(invocations, 1);
    });

    testWidgets('retourNavigatesHome', (tester) async {
      await tester.pumpWidget(_wrap(const PermissionDeniedScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('grantDetectedOnResumePopsTrue', (tester) async {
      Object? popResult = _unset;
      PermissionStatus currentStatus = PermissionStatus.denied;
      await tester.pumpWidget(_wrapWithHostRoute(PermissionDeniedScreen(checkLocationPermissionFn: () async => currentStatus), (r) => popResult = r));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open denied'));
      await tester.pumpAndSettle();
      expect(find.text('Localisation refusée'), findsOneWidget);

      // Simulate: user flips the permission to Allow in system settings,
      // then MirkFall comes back to the foreground.
      currentStatus = PermissionStatus.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(popResult, isTrue);
    });

    testWidgets('resumeWithoutGrantKeepsScreenOpen', (tester) async {
      Object? popResult = _unset;
      await tester.pumpWidget(_wrapWithHostRoute(PermissionDeniedScreen(checkLocationPermissionFn: () async => PermissionStatus.denied), (r) => popResult = r));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open denied'));
      await tester.pumpAndSettle();
      expect(find.text('Localisation refusée'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Still on the denied screen; no pop happened.
      expect(find.text('Localisation refusée'), findsOneWidget);
      expect(popResult, same(_unset));
    });

    testWidgets('retourPopsFalse', (tester) async {
      Object? popResult = _unset;
      await tester.pumpWidget(_wrapWithHostRoute(const PermissionDeniedScreen(), (r) => popResult = r));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open denied'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(popResult, isFalse);
    });
  });
}

/// Sentinel used by the tests above to distinguish "never popped" from
/// "popped with null".
const Object _unset = Object();

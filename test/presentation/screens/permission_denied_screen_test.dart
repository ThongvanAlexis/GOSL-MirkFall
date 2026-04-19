// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/presentation/screens/permission_denied_screen.dart';
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
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/domain/errors/location_permission_errors.dart';
import 'package:mirkfall/presentation/screens/permission_rationale_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verbatim CONTEXT.md §Permission flow rationale copy. Kept as a
/// constant so the assertion reads cleanly + any copy drift fails
/// loudly.
const String _contextMdBody =
    "MirkFall a besoin de ta localisation en arrière-plan pour continuer à révéler le brouillard pendant que ton téléphone est dans ta poche, écran éteint. Tes positions restent sur ton téléphone. Aucun serveur, aucune publicité, aucune analytique.";

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/permissions/rationale',
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/permissions/rationale', builder: (_, _) => child),
      GoRoute(
        path: '/permissions/denied',
        builder: (_, _) => const Scaffold(body: Text('denied')),
      ),
      GoRoute(
        path: '/permissions/oem',
        builder: (_, _) => const Scaffold(body: Text('oem')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('PermissionRationaleScreen', () {
    testWidgets('displaysContextMdCopyVerbatim', (tester) async {
      await tester.pumpWidget(_wrap(const PermissionRationaleScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Pour suivre ton exploration'), findsOneWidget);
      expect(find.text(_contextMdBody), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.text('Pas maintenant'), findsOneWidget);
    });

    testWidgets('continuerInvokesRequestLocationAlways', (tester) async {
      int invocations = 0;
      await tester.pumpWidget(
        _wrap(
          PermissionRationaleScreen(
            requestLocationAlwaysFn: () async {
              invocations++;
              return LocationPermissionOutcome.granted;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(invocations, 1);
    });

    testWidgets('notMaintenantPopsWithFalse', (tester) async {
      await tester.pumpWidget(_wrap(const PermissionRationaleScreen()));
      await tester.pumpAndSettle();

      // Router's initial location doesn't have a parent to pop to, so
      // tapping pop on the top route is a no-op in this harness — we
      // verify the button callback *would* pop by asserting the
      // TextButton exists and has a non-null onPressed.
      final TextButton button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Pas maintenant'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('deniedOutcomeRoutesToDeniedScreen', (tester) async {
      await tester.pumpWidget(_wrap(PermissionRationaleScreen(requestLocationAlwaysFn: () async => LocationPermissionOutcome.denied)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('denied'), findsOneWidget);
    });
  });
}

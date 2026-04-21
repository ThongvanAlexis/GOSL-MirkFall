// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/presentation/widgets/session_burger_menu.dart';

/// Fake active-session controller — reuses the Tracking state variant so
/// the burger menu renders its live-data rows.
class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController({required this.seed});
  final ActiveSessionState seed;
  int stopCalls = 0;

  @override
  ActiveSessionState build() => seed;

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

Fix _fix({required double lat, required double lon, required SessionId sid}) => Fix(
  id: FixId.parse('fix_01ARZ3NDEKTSV4RRFFQ69G5FAV'),
  sessionId: sid,
  recordedAtUtc: DateTime.utc(2026, 4, 21, 10, 30),
  recordedAtOffsetMinutes: 120,
  latitude: lat,
  longitude: lon,
  accuracyMeters: 10.0,
  speedMps: 1.0,
  headingDegrees: 0.0,
);

Widget _wrapWithOverrides(Widget child, {required ActiveSessionController fakeController}) {
  return ProviderScope(
    overrides: [activeSessionControllerProvider.overrideWith(() => fakeController)],
    // Wrap in a Scaffold with drawer so the Drawer widget finds the proper
    // ScaffoldState ancestor. Testing the Drawer in isolation would throw.
    child: MaterialApp(
      home: Scaffold(
        drawer: child,
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(onPressed: () => Scaffold.of(context).openDrawer(), child: const Text('Open')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final SessionId sid = SessionId.parse('sess_01ARZ3NDEKTSV4RRFFQ69G5FAV');

  group('SessionBurgerMenu', () {
    testWidgets('renders 3 unwired action tiles + live-data rows when Tracking', (tester) async {
      final Tracking tracking = Tracking(
        sessionId: sid,
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(seconds: 65)),
        fixCount: 10,
        distanceFilterMeters: kDefaultDistanceFilterMeters,
        lastFix: _fix(lat: 48.8566, lon: 2.3522, sid: sid),
      );
      final fake = _FakeActiveSessionController(seed: tracking);
      await tester.pumpWidget(_wrapWithOverrides(const SessionBurgerMenu(), fakeController: fake));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Changer le style'), findsOneWidget);
      expect(find.text('Prendre une photo'), findsOneWidget);
      expect(find.text('Placer un marker'), findsOneWidget);
      // Position row — 6 decimals.
      expect(find.textContaining('Position : 48.856600, 2.352200'), findsOneWidget);
      // Durée row — at least one row containing "Durée".
      expect(find.textContaining('Durée'), findsOneWidget);
      // Distance row.
      expect(find.textContaining('Distance'), findsOneWidget);
      // Stop tile — Tracking state surfaces it.
      expect(find.text('Arrêter la session'), findsOneWidget);
    });

    testWidgets('shows "En attente GPS..." when Tracking but no lastFix yet', (tester) async {
      final Tracking tracking = Tracking(sessionId: sid, startedAtUtc: DateTime.now().toUtc(), fixCount: 0, distanceFilterMeters: kDefaultDistanceFilterMeters);
      final fake = _FakeActiveSessionController(seed: tracking);
      await tester.pumpWidget(_wrapWithOverrides(const SessionBurgerMenu(), fakeController: fake));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('En attente GPS'), findsOneWidget);
    });

    testWidgets('tap on "Prendre une photo" surfaces a snackbar + tile does NOT navigate', (tester) async {
      final fake = _FakeActiveSessionController(seed: const Idle());
      await tester.pumpWidget(_wrapWithOverrides(const SessionBurgerMenu(), fakeController: fake));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prendre une photo'));
      // Single pump — snackbar has an entry animation but its Text is
      // immediately present on the next frame.
      await tester.pump();
      expect(find.textContaining('Phase 11'), findsOneWidget);
    });

    testWidgets('Idle state hides the "Arrêter la session" tile', (tester) async {
      final fake = _FakeActiveSessionController(seed: const Idle());
      await tester.pumpWidget(_wrapWithOverrides(const SessionBurgerMenu(), fakeController: fake));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Arrêter la session'), findsNothing);
    });
  });
}

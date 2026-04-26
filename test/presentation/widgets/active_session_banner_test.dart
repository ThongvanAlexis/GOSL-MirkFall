// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/fix_store_provider.dart';
import 'package:mirkfall/application/providers/location_stream_provider.dart';
import 'package:mirkfall/application/providers/revealed_disc_store_provider.dart';
import 'package:mirkfall/application/providers/revealed_tile_store_provider.dart';
import 'package:mirkfall/application/providers/session_notification_service_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';
import 'package:mirkfall/presentation/widgets/active_session_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_revealed_disc_store.dart';
import '../../helpers/fake_location_stream.dart';
import '../../helpers/no_op_revealed_tile_store.dart';
import '../screens/session_list_screen_test.dart' show FakeFixStore, FakeSessionStore;

/// Minimal notification fake — satisfies the [SessionNotificationService]
/// concrete contract without touching a real `LocalNotificationsPort`.
class _FakeNotificationService implements SessionNotificationService {
  int initializeCount = 0;
  int dismissCount = 0;

  @override
  Future<void> initialize() async => initializeCount++;

  @override
  Future<void> dismiss() async => dismissCount++;

  @override
  Future<void> showResumeNotification(SessionId id, String name) async {}
}

GoRouter _buildRouter(Widget bannerChild) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Column(
            children: <Widget>[
              bannerChild,
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/sessions/:id',
        builder: (_, state) => Scaffold(body: Text('detail:${state.pathParameters['id']}')),
      ),
    ],
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
  });

  group('ActiveSessionBanner', () {
    testWidgets('rendersEmptyOnIdle', (tester) async {
      final sessionStore = FakeSessionStore();
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith((ref) async => sessionStore),
            fixStoreProvider.overrideWith((ref) async => fixStore),
            locationStreamProvider.overrideWith((ref) => locationStream),
            sessionNotificationServiceProvider.overrideWith((ref) => notificationService),
            // BUG-009 follow-up (2026-04-25) — start() now awaits
            // `revealedTileStoreProvider.future`. Tests that drive
            // start() must override or path_provider hangs.
            revealedTileStoreProvider.overrideWith((ref) async => const NoOpRevealedTileStore()),
            revealedDiscStoreProvider.overrideWith((ref) async => FakeRevealedDiscStore()),
          ],
          child: MaterialApp.router(routerConfig: _buildRouter(const ActiveSessionBanner())),
        ),
      );
      // Phase 06 Should #17 (Agent #3 #2) — bounded pump.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Banner collapses to SizedBox.shrink in Idle — no visible text.
      expect(find.text('Session active'), findsNothing);
    });

    testWidgets('rendersBannerOnTracking', (tester) async {
      const sessionId = SessionId('sess_00000000000000000000000001');
      final seeded = Session(
        id: sessionId,
        displayName: 'Balade',
        status: SessionStatus.stopped,
        startedAtUtc: DateTime.utc(2026, 4, 19, 10),
        startedAtOffsetMinutes: 120,
      );
      final sessionStore = FakeSessionStore(<Session>[seeded]);
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith((ref) async => sessionStore),
            fixStoreProvider.overrideWith((ref) async => fixStore),
            locationStreamProvider.overrideWith((ref) => locationStream),
            sessionNotificationServiceProvider.overrideWith((ref) => notificationService),
            // BUG-009 follow-up (2026-04-25) — start() now awaits
            // `revealedTileStoreProvider.future`. Tests that drive
            // start() must override or path_provider hangs.
            revealedTileStoreProvider.overrideWith((ref) async => const NoOpRevealedTileStore()),
            revealedDiscStoreProvider.overrideWith((ref) async => FakeRevealedDiscStore()),
          ],
          child: MaterialApp.router(routerConfig: _buildRouter(const ActiveSessionBanner())),
        ),
      );
      // Phase 06 Should #17 (Agent #3 #2) — bounded pump instead of
      // pumpAndSettle. The banner itself has no ticker today, but
      // pumpAndSettle would deadlock the moment a future sibling
      // (chrono, live fix counter) adds a Stream.periodic. Matches
      // session_detail_screen_test's bounded-pump pattern.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Grab the container and trigger start.
      final element = tester.element(find.byType(ActiveSessionBanner));
      final container = ProviderScope.containerOf(element);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.text('Session active'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    });

    testWidgets('stopAffordanceExposesNonNullOnPressedDuringTracking', (tester) async {
      // This test verifies the banner's Stop IconButton is wired
      // (onPressed non-null) whenever state is [Tracking]. The full
      // end-to-end `tap -> controller.stop() -> state=Idle` chain is
      // covered at the controller level by
      // `test/application/controllers/active_session_controller_test.dart`
      // (`stopCancelsSubscriptionAndDeactivates`); duplicating the
      // async chain in a widget test hits test-framework settle
      // timeouts because the long-lived sessionList broadcast stream
      // keeps pumpAndSettle from returning.
      const sessionId = SessionId('sess_00000000000000000000000001');
      final seeded = Session(
        id: sessionId,
        displayName: 'Balade',
        status: SessionStatus.stopped,
        startedAtUtc: DateTime.utc(2026, 4, 19, 10),
        startedAtOffsetMinutes: 120,
      );
      final sessionStore = FakeSessionStore(<Session>[seeded]);
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith((ref) async => sessionStore),
            fixStoreProvider.overrideWith((ref) async => fixStore),
            locationStreamProvider.overrideWith((ref) => locationStream),
            sessionNotificationServiceProvider.overrideWith((ref) => notificationService),
            // BUG-009 follow-up (2026-04-25) — start() now awaits
            // `revealedTileStoreProvider.future`. Tests that drive
            // start() must override or path_provider hangs.
            revealedTileStoreProvider.overrideWith((ref) async => const NoOpRevealedTileStore()),
            revealedDiscStoreProvider.overrideWith((ref) async => FakeRevealedDiscStore()),
          ],
          child: MaterialApp.router(routerConfig: _buildRouter(const ActiveSessionBanner())),
        ),
      );
      // Phase 06 Should #17 (Agent #3 #2) — bounded pump (see sibling
      // test's rationale). Matches session_detail_screen_test:125-127.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final element = tester.element(find.byType(ActiveSessionBanner));
      final container = ProviderScope.containerOf(element);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byType(IconButton), findsOneWidget);
      final IconButton button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNotNull, reason: 'Stop affordance must be active during Tracking');
      expect(button.tooltip, 'Arrêter la session');
    });
  });
}

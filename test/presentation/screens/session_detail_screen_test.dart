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
import 'package:mirkfall/application/providers/session_notification_service_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';
import 'package:mirkfall/presentation/screens/session_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_location_stream.dart';
import 'session_list_screen_test.dart' show FakeFixStore, FakeSessionStore, buildSession;

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

Widget _pumpWrap({
  required SessionId sessionId,
  required FakeSessionStore sessionStore,
  required FakeFixStore fixStore,
  required FakeLocationStream locationStream,
  required _FakeNotificationService notificationService,
}) {
  final router = GoRouter(
    initialLocation: '/sessions/${sessionId.value}',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/sessions/:id',
        builder: (_, state) => SessionDetailScreen(sessionId: SessionId(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/permissions/rationale',
        builder: (_, _) => const Scaffold(body: Text('rationale')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith((ref) async => sessionStore),
      fixStoreProvider.overrideWith((ref) async => fixStore),
      locationStreamProvider.overrideWith((ref) => locationStream),
      sessionNotificationServiceProvider.overrideWith((ref) => notificationService),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5, 'permission_flow_completed': true});
  });

  group('SessionDetailScreen', () {
    testWidgets('rendersSummaryCardWhenIdle', (tester) async {
      const sessionId = SessionId('sess_00000000000000000000000001');
      final session = buildSession(id: sessionId.value, displayName: 'Ma session', startedAtUtc: DateTime.utc(2026, 4, 19, 9));
      final sessionStore = FakeSessionStore(<Session>[session]);
      addTearDown(sessionStore.disposeController);

      await tester.pumpWidget(
        _pumpWrap(
          sessionId: sessionId,
          sessionStore: sessionStore,
          fixStore: FakeFixStore(),
          locationStream: FakeLocationStream(),
          notificationService: _FakeNotificationService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Démarrer'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets('rendersStatusDashboardWhenActive', (tester) async {
      const sessionId = SessionId('sess_00000000000000000000000002');
      final session = buildSession(id: sessionId.value, displayName: 'Ma live', startedAtUtc: DateTime.utc(2026, 4, 19, 9));
      final sessionStore = FakeSessionStore(<Session>[session]);
      addTearDown(sessionStore.disposeController);

      final widgetTree = _pumpWrap(
        sessionId: sessionId,
        sessionStore: sessionStore,
        fixStore: FakeFixStore(),
        locationStream: FakeLocationStream(),
        notificationService: _FakeNotificationService(),
      );
      await tester.pumpWidget(widgetTree);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Grab container and kick start.
      final element = tester.element(find.byType(SessionDetailScreen));
      final container = ProviderScope.containerOf(element);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);
      // The _ChronoCard uses a Stream.periodic(1s) which makes
      // pumpAndSettle block indefinitely — pump bounded frames
      // instead to observe the Tracking state reaching the UI.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Dashboard signal: Durée + Arrêter button.
      expect(find.text('Durée'), findsOneWidget);
      expect(find.text('Arrêter'), findsOneWidget);
    });

    testWidgets('stopButtonExistsAndIsWiredToControllerStop', (tester) async {
      // Wiring check — the Arrêter FilledButton on the tracking
      // dashboard must surface a non-null onPressed when in Tracking
      // state. The full async start-then-stop round-trip is covered by
      // `test/application/controllers/active_session_controller_test.dart`
      // `stopCancelsSubscriptionAndDeactivates`; widget tests around
      // live tracking state hit pump/settle pathology because
      // `_ChronoCard` spins `Stream.periodic(1s)`.
      const sessionId = SessionId('sess_00000000000000000000000003');
      final session = buildSession(id: sessionId.value, displayName: 'Ma live');
      final sessionStore = FakeSessionStore(<Session>[session]);
      addTearDown(sessionStore.disposeController);

      await tester.pumpWidget(
        _pumpWrap(
          sessionId: sessionId,
          sessionStore: sessionStore,
          fixStore: FakeFixStore(),
          locationStream: FakeLocationStream(),
          notificationService: _FakeNotificationService(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final element = tester.element(find.byType(SessionDetailScreen));
      final container = ProviderScope.containerOf(element);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Affordance visible and has a handler.
      final Finder stopButton = find.widgetWithText(FilledButton, 'Arrêter');
      expect(stopButton, findsOneWidget);
      final FilledButton b = tester.widget<FilledButton>(stopButton);
      expect(b.onPressed, isNotNull, reason: 'Arrêter button must be wired during Tracking');
    });

    testWidgets('deleteBlockedWhenActiveShowsError', (tester) async {
      const sessionId = SessionId('sess_00000000000000000000000004');
      final session = buildSession(id: sessionId.value, displayName: 'Live', status: SessionStatus.active);
      final sessionStore = FakeSessionStore(<Session>[session]);
      addTearDown(sessionStore.disposeController);

      await tester.pumpWidget(
        _pumpWrap(
          sessionId: sessionId,
          sessionStore: sessionStore,
          fixStore: FakeFixStore(),
          locationStream: FakeLocationStream(),
          notificationService: _FakeNotificationService(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete from summary (available because controller is Idle —
      // we set the session status=active in the store to simulate an
      // orphan row; UI blocks delete based on session.status).
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      // Inline error surfaces.
      expect(find.textContaining("Arrête la session d'abord"), findsOneWidget);
      // Session was NOT removed from the store.
      expect(sessionStore.deletes, isEmpty);
    });

    testWidgets('deleteOnStoppedInvokesSessionStore', (tester) async {
      const sessionId = SessionId('sess_00000000000000000000000005');
      final session = buildSession(id: sessionId.value, displayName: 'Dead');
      final sessionStore = FakeSessionStore(<Session>[session]);
      addTearDown(sessionStore.disposeController);

      await tester.pumpWidget(
        _pumpWrap(
          sessionId: sessionId,
          sessionStore: sessionStore,
          fixStore: FakeFixStore(),
          locationStream: FakeLocationStream(),
          notificationService: _FakeNotificationService(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      // Confirm dialog then confirm.
      expect(find.text('Supprimer la session ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(sessionStore.deletes, <SessionId>[sessionId]);
    });

    testWidgets('renameDialogPersistsNewDisplayName', (tester) async {
      const sessionId = SessionId('sess_00000000000000000000000006');
      final session = buildSession(id: sessionId.value, displayName: 'Ancien nom');
      final sessionStore = FakeSessionStore(<Session>[session]);
      addTearDown(sessionStore.disposeController);

      await tester.pumpWidget(
        _pumpWrap(
          sessionId: sessionId,
          sessionStore: sessionStore,
          fixStore: FakeFixStore(),
          locationStream: FakeLocationStream(),
          notificationService: _FakeNotificationService(),
        ),
      );
      await tester.pumpAndSettle();

      // Open overflow, select rename.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renommer'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Nouveau nom');
      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(sessionStore.updates.any((s) => s.id == sessionId && s.displayName == 'Nouveau nom'), isTrue);
    });
  });
}

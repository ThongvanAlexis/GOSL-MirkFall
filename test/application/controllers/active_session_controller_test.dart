// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/boot_watchdog_provider.dart';
import 'package:mirkfall/application/providers/fix_store_provider.dart';
import 'package:mirkfall/application/providers/location_stream_provider.dart';
import 'package:mirkfall/application/providers/session_notification_service_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/errors/concurrent_errors.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/fixes/fix_store.dart';
import 'package:mirkfall/domain/gps/gps_errors.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';
import 'package:mirkfall/infrastructure/platform/ios_significant_change_watchdog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_location_stream.dart';

/// Captures activate/deactivate calls. Seed with an in-memory map of
/// sessions so `requireById` can hydrate without an AppDatabase.
class _FakeSessionStore implements SessionStore {
  _FakeSessionStore(this._sessionById);

  final Map<SessionId, Session> _sessionById;
  final List<SessionId> activatedIds = <SessionId>[];
  final List<SessionId> deactivatedIds = <SessionId>[];
  bool throwConcurrentOnActivate = false;

  @override
  Future<void> activate(SessionId id) async {
    if (throwConcurrentOnActivate) {
      throw ConcurrentActivationException(attemptedId: id);
    }
    activatedIds.add(id);
    final existing = _sessionById[id];
    if (existing != null) {
      _sessionById[id] = existing.copyWith(status: SessionStatus.active);
    }
  }

  @override
  Future<void> deactivate(SessionId id) async {
    deactivatedIds.add(id);
    final existing = _sessionById[id];
    if (existing != null) {
      _sessionById[id] = existing.copyWith(status: SessionStatus.stopped);
    }
  }

  @override
  Future<Session> requireById(SessionId id) async {
    final row = _sessionById[id];
    if (row == null) {
      throw StateError('Test setup: no session seeded for $id');
    }
    return row;
  }

  @override
  Future<Session?> findById(SessionId id) async => _sessionById[id];

  @override
  Future<Session?> findActive() async {
    for (final session in _sessionById.values) {
      if (session.status == SessionStatus.active) return session;
    }
    return null;
  }

  @override
  Future<List<Session>> listAll() async => _sessionById.values.toList(growable: false);

  @override
  Stream<List<Session>> watchAll() => Stream<List<Session>>.value(_sessionById.values.toList(growable: false));

  @override
  Future<void> insert(Session session) async => _sessionById[session.id] = session;

  @override
  Future<void> update(Session session) async => _sessionById[session.id] = session;

  @override
  Future<void> delete(SessionId id) async => _sessionById.remove(id);
}

/// Records every [Fix] inserted and satisfies the reader methods with
/// an in-memory list.
class _FakeFixStore implements FixStore {
  final List<Fix> inserts = <Fix>[];

  /// When non-null, the next [insert] throws this error instead of
  /// recording the fix. Lets tests exercise the DB-write-failure path
  /// (disk full, SQLITE_BUSY, schema drift) without a real Drift stack.
  Object? throwOnInsert;

  @override
  Future<void> insert(Fix fix) async {
    final err = throwOnInsert;
    if (err != null) throw err;
    inserts.add(fix);
  }

  @override
  Future<List<Fix>> listBySession(SessionId sessionId) async => inserts.where((f) => f.sessionId == sessionId).toList(growable: false);

  @override
  Stream<List<Fix>> watchBySession(SessionId sessionId) => Stream<List<Fix>>.value(inserts.where((f) => f.sessionId == sessionId).toList(growable: false));

  @override
  Future<int> countBySession(SessionId sessionId) async => inserts.where((f) => f.sessionId == sessionId).length;

  @override
  Future<void> deleteAllForSession(SessionId sessionId) async => inserts.removeWhere((f) => f.sessionId == sessionId);
}

/// Port fake — counts initialize/dismiss/showResumeNotification calls
/// without touching a notification plugin.
class _FakeNotificationService implements SessionNotificationService {
  int initializeCount = 0;
  int dismissCount = 0;
  int showResumeCount = 0;

  @override
  Future<void> initialize() async => initializeCount++;

  @override
  Future<void> dismiss() async => dismissCount++;

  @override
  Future<void> showResumeNotification(SessionId sessionId, String sessionDisplayName) async => showResumeCount++;
}

/// Fake iOS significant-change watchdog — records start/stop calls so tests
/// can assert the controller invokes them at the right transitions without
/// touching CLLocationManager.
class _FakeIosSignificantChangeWatchdog implements IosSignificantChangeWatchdog {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> startMonitoring() async => startCount++;

  @override
  Future<void> stopMonitoring() async => stopCount++;
}

Session _buildSession(SessionId id, {SessionStatus status = SessionStatus.stopped, String displayName = 'Test session'}) =>
    Session(id: id, displayName: displayName, status: status, startedAtUtc: DateTime.utc(2026, 4, 19, 10), startedAtOffsetMinutes: 120);

Fix _buildFix({required SessionId sessionId, String id = 'fix_01HR0000000000000000000A', int epochMs = 1745056800000}) => Fix(
  id: FixId(id),
  sessionId: sessionId,
  recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
  recordedAtOffsetMinutes: 120,
  latitude: 48.8566,
  longitude: 2.3522,
  accuracyMeters: 5.0,
);

ProviderContainer _buildContainer({
  required _FakeSessionStore sessionStore,
  required _FakeFixStore fixStore,
  required FakeLocationStream locationStream,
  required _FakeNotificationService notificationService,
  _FakeIosSignificantChangeWatchdog? iosWatchdog,
}) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWith((ref) async => sessionStore),
      fixStoreProvider.overrideWith((ref) async => fixStore),
      locationStreamProvider.overrideWith((ref) => locationStream),
      sessionNotificationServiceProvider.overrideWith((ref) => notificationService),
      iosSignificantChangeWatchdogProvider.overrideWith((ref) => iosWatchdog ?? _FakeIosSignificantChangeWatchdog()),
    ],
  );
}

void main() {
  // SessionSettings reads SharedPreferences.getInstance(); mock binding
  // is required at the suite level. Seeded per-test to guarantee the
  // distanceFilter_meters value.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('ActiveSessionController', () {
    test('buildReturnsIdle', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      final sessionStore = _FakeSessionStore(<SessionId, Session>{});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      final state = await container.read(activeSessionControllerProvider.future);
      expect(state, isA<Idle>());
    });

    test('startTransitionsToTracking', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId, displayName: 'Balade de test')});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      // Prime controller.
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);

      final state = container.read(activeSessionControllerProvider).value;
      expect(state, isA<Tracking>());
      final tracking = state! as Tracking;
      expect(tracking.sessionId, sessionId);
      expect(tracking.distanceFilterMeters, 5);
      expect(tracking.fixCount, 0);
      expect(tracking.lastFix, isNull);
      expect(locationStream.capturedSessionId, sessionId);
      expect(locationStream.capturedDisplayName, 'Balade de test');
      expect(locationStream.capturedDistanceFilter, 5);
    });

    test('startActivatesSessionInStore', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);

      expect(sessionStore.activatedIds, <SessionId>[sessionId]);
    });

    test('startInitializesNotification', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);

      expect(notificationService.initializeCount, 1);
    });

    test('startPropagatesConcurrentActivationAsAsyncError', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)})..throwConcurrentOnActivate = true;
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);

      // Controller rethrows so the caller (Plan 05-04 UI) can chain
      // stop()+start(); the state settles on AsyncError carrying the
      // ConcurrentActivationException.
      await expectLater(container.read(activeSessionControllerProvider.notifier).start(sessionId), throwsA(isA<ConcurrentActivationException>()));

      final asyncValue = container.read(activeSessionControllerProvider);
      expect(asyncValue.hasError, isTrue);
      expect(asyncValue.error, isA<ConcurrentActivationException>());
    });

    test('acceptedFixIsPersistedAndFixCountIncrements', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);

      final fix = _buildFix(sessionId: sessionId);
      locationStream.emit(fix);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(activeSessionControllerProvider).value;
      expect(state, isA<Tracking>());
      final tracking = state! as Tracking;
      expect(tracking.fixCount, 1);
      expect(tracking.lastFix, fix);
      expect(fixStore.inserts, <Fix>[fix]);
    });

    test('stopCancelsSubscriptionAndDeactivates', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);
      await container.read(activeSessionControllerProvider.notifier).stop();

      final state = container.read(activeSessionControllerProvider).value;
      expect(state, isA<Idle>());
      expect(sessionStore.deactivatedIds, <SessionId>[sessionId]);
      expect(locationStream.isDisposed, isTrue);
      expect(notificationService.dismissCount, greaterThanOrEqualTo(1));
    });

    test('startInvokesIosSignificantChangeWatchdog', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();
      final iosWatchdog = _FakeIosSignificantChangeWatchdog();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
        iosWatchdog: iosWatchdog,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);

      expect(iosWatchdog.startCount, 1);
      expect(iosWatchdog.stopCount, 0);
    });

    test('stopInvokesIosSignificantChangeWatchdogStopMonitoring', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();
      final iosWatchdog = _FakeIosSignificantChangeWatchdog();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
        iosWatchdog: iosWatchdog,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);
      await container.read(activeSessionControllerProvider.notifier).stop();

      expect(iosWatchdog.startCount, 1);
      expect(iosWatchdog.stopCount, 1);
    });

    test('streamErrorSurfacesViaAsyncError', () async {
      // Row #37 cleanup (2026-04-23): stream-level GpsError no longer
      // folds into `AsyncData(ErrorState)` — it surfaces through the
      // same `AsyncError` channel as every other exception. UI
      // consumers pattern-match on `asyncValue.error`'s runtime type.
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);

      locationStream.emitError(const LocationServiceDisabledException());
      await Future<void>.delayed(Duration.zero);

      final asyncValue = container.read(activeSessionControllerProvider);
      expect(asyncValue.hasError, isTrue, reason: 'GpsError on the stream must surface via AsyncError (row #37)');
      expect(asyncValue.error, isA<LocationServiceDisabledException>());
    });

    test('startGpsErrorSurfacesViaAsyncErrorAndDeactivates', () async {
      // Phase 06 Blocker #1 regression guard: a failure AFTER
      // activate() must roll the DB row back to stopped so a retry is
      // not blocked by the partial-unique-index on active sessions.
      // Row #37 (2026-04-23): GpsError now propagates via AsyncError
      // rather than a dedicated ErrorState variant — consolidates on
      // the same error channel as non-GpsError exceptions.
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream()..throwGpsOnPositions = const LocationServiceDisabledException();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await expectLater(container.read(activeSessionControllerProvider.notifier).start(sessionId), throwsA(isA<LocationServiceDisabledException>()));

      final asyncValue = container.read(activeSessionControllerProvider);
      expect(asyncValue.hasError, isTrue, reason: 'GpsError during start must surface via AsyncError (row #37)');
      expect(asyncValue.error, isA<LocationServiceDisabledException>());
      expect(sessionStore.activatedIds, <SessionId>[sessionId], reason: 'activate must have been called');
      expect(sessionStore.deactivatedIds, <SessionId>[sessionId], reason: 'rollback must deactivate on partial-activation failure');
    });

    test('stopIsReentrantSafe', () async {
      // Phase 06 Should #4 regression guard: two concurrent stop() calls
      // must not produce two deactivate() calls on the session store.
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      final notifier = container.read(activeSessionControllerProvider.notifier);
      await notifier.start(sessionId);

      // Fire two overlapping stop()s. The second MUST short-circuit
      // rather than issue a second deactivate.
      await Future.wait<void>([notifier.stop(), notifier.stop()]);

      expect(sessionStore.deactivatedIds, <SessionId>[sessionId], reason: 'overlapping stop() calls must coalesce to a single deactivate');
      expect(container.read(activeSessionControllerProvider).value, isA<Idle>());
    });

    test('onFixDbInsertFailureTransitionsToAsyncError', () async {
      // Phase 06 Should #7 regression guard: fixStore.insert() throwing
      // mid-Tracking must not escape into the zone handler; the
      // controller drains to the error path and AsyncError settles.
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(sessionId)});
      final fixStore = _FakeFixStore()..throwOnInsert = StateError('disk full');
      final locationStream = FakeLocationStream();
      final notificationService = _FakeNotificationService();

      final container = _buildContainer(
        sessionStore: sessionStore,
        fixStore: fixStore,
        locationStream: locationStream,
        notificationService: notificationService,
      );
      addTearDown(container.dispose);

      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(sessionId);

      locationStream.emit(_buildFix(sessionId: sessionId));
      await Future<void>.delayed(Duration.zero);

      final asyncValue = container.read(activeSessionControllerProvider);
      expect(asyncValue.hasError, isTrue, reason: 'DB insert failure during Tracking must surface as AsyncError');
      expect(asyncValue.error, isA<StateError>());
    });
  });
}

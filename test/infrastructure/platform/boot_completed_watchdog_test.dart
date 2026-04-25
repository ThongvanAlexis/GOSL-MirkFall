// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/errors/session_errors.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';
import 'package:mirkfall/infrastructure/platform/boot_completed_watchdog.dart';

/// Covers GPS-06 — boot / significant-change auto-resume path.
///
/// Pure-Dart watchdog: given a SessionStore snapshot, decide whether to
/// fire the "tap to resume" local notification. The native-side glue
/// (Android BroadcastReceiver + iOS CLLocationManager delegate) is
/// validated manually via the Plan 05-06 real-device POC; this test
/// suite covers the Dart logic in isolation.
void main() {
  group('BootCompletedWatchdog', () {
    test('schedulesNotifOnActiveSession', () async {
      const sessionId = SessionId('sess_01HR0000000000000000000A');
      final activeSession = _buildSession(sessionId, status: SessionStatus.active, displayName: 'Balade de test');

      final sessionStore = _FakeSessionStore(sessions: [activeSession]);
      final notificationService = _FakeNotificationService();

      final watchdog = BootCompletedWatchdog(sessionStore, notificationService);
      await watchdog.run();

      expect(notificationService.resumeCount, 1);
      expect(notificationService.lastSessionId, sessionId);
      expect(notificationService.lastDisplayName, 'Balade de test');
    });

    test('noopWhenNoActiveSession', () async {
      // Seed only a stopped session (status=stopped is the default).
      const sessionId = SessionId('sess_01HR0000000000000000000B');
      final stoppedSession = _buildSession(sessionId);

      final sessionStore = _FakeSessionStore(sessions: [stoppedSession]);
      final notificationService = _FakeNotificationService();

      final watchdog = BootCompletedWatchdog(sessionStore, notificationService);
      await watchdog.run();

      expect(notificationService.resumeCount, 0);
    });

    test('idempotentOnMultipleRunsSameSession', () async {
      // Notification id 1001 is stable so the user only ever sees one
      // notification even if the watchdog fires twice in a row — but the
      // service call count still increments per run.
      const sessionId = SessionId('sess_01HR0000000000000000000C');
      final activeSession = _buildSession(sessionId, status: SessionStatus.active);

      final sessionStore = _FakeSessionStore(sessions: [activeSession]);
      final notificationService = _FakeNotificationService();

      final watchdog = BootCompletedWatchdog(sessionStore, notificationService);
      await watchdog.run();
      await watchdog.run();

      expect(notificationService.resumeCount, 2);
    });

    test('swallowsErrorsInsteadOfCrashing', () async {
      // Native side (BroadcastReceiver, CLLocationManager delegate) must
      // never observe an unhandled exception — the watchdog logs + swallows
      // so the receiver's pendingResult.finish() always fires cleanly.
      final sessionStore = _FakeSessionStore.throwing();
      final notificationService = _FakeNotificationService();

      final watchdog = BootCompletedWatchdog(sessionStore, notificationService);

      // Must complete without rethrow.
      await watchdog.run();

      expect(notificationService.resumeCount, 0);
    });
  });
}

Session _buildSession(SessionId id, {SessionStatus status = SessionStatus.stopped, String displayName = 'Test session'}) =>
    Session(id: id, displayName: displayName, status: status, startedAtUtc: DateTime.utc(2026, 4, 19, 10), startedAtOffsetMinutes: 120);

/// Minimal SessionStore fake — seeds a fixed list of sessions + optionally
/// throws on `listAll()` to exercise the error-swallowing contract.
class _FakeSessionStore implements SessionStore {
  _FakeSessionStore({this.sessions = const <Session>[]}) : _throwOnList = false;
  _FakeSessionStore.throwing() : sessions = const <Session>[], _throwOnList = true;

  final List<Session> sessions;
  final bool _throwOnList;

  @override
  Future<List<Session>> listAll() async {
    if (_throwOnList) {
      throw StateError('Simulated DB-open failure');
    }
    return sessions;
  }

  @override
  Future<Session?> findActive() async {
    for (final s in sessions) {
      if (s.status == SessionStatus.active) return s;
    }
    return null;
  }

  @override
  Future<Session?> findById(SessionId id) async {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<Session> requireById(SessionId id) async {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    throw SessionNotFoundException(id: id);
  }

  @override
  Stream<List<Session>> watchAll() => Stream<List<Session>>.value(sessions);

  @override
  Future<void> insert(Session session) async {}

  @override
  Future<void> update(Session session) async {}

  @override
  Future<void> delete(SessionId id) async {}

  @override
  Future<void> activate(SessionId id) async {}

  @override
  Future<void> deactivate(SessionId id) async {}

  @override
  Future<void> updateMirkStyle({required SessionId sessionId, required MirkStyleId? mirkStyleId}) async {}
}

/// Minimal SessionNotificationService fake — counts `showResumeNotification`
/// calls + captures the last arguments.
class _FakeNotificationService implements SessionNotificationService {
  int resumeCount = 0;
  SessionId? lastSessionId;
  String? lastDisplayName;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dismiss() async {}

  @override
  Future<void> showResumeNotification(SessionId sessionId, String sessionDisplayName) async {
    resumeCount += 1;
    lastSessionId = sessionId;
    lastDisplayName = sessionDisplayName;
  }
}

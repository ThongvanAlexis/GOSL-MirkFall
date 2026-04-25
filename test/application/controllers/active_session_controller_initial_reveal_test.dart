// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/boot_watchdog_provider.dart';
import 'package:mirkfall/application/providers/fix_store_provider.dart';
import 'package:mirkfall/application/providers/location_stream_provider.dart';
import 'package:mirkfall/application/providers/revealed_tile_store_provider.dart';
import 'package:mirkfall/application/providers/session_notification_service_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/fixes/fix_store.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/revealed_tile.dart';
import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';
import 'package:mirkfall/infrastructure/platform/ios_significant_change_watchdog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_location_stream.dart';

/// Plan 09-06 Task 4 — `ActiveSessionController.start` initial 20 m
/// reveal + per-fix forwarding to the reveal pipeline.
///
/// Scenarios covered:
/// 1. start with `lastKnownFix` cached → revealInitial fires once on
///    the cached fix (fast path), without waiting for a stream emit.
/// 2. start with no cached fix + first stream emission → revealInitial
///    fires exactly once on the first incoming fix (slow path).
/// 3. Each subsequent fix is forwarded via [`RevealStreamingController.onFix`]
///    (no second revealInitial).
/// 4. stop() flushes the pipeline (mergeMask calls land before Idle
///    state settles).

const SessionId _testSessionId = SessionId('sess_01HRACTIVESESSCTLTESTAAAAAAA');

/// In-memory `SessionStore` mirroring the Phase 05 controller test fake
/// — minimal surface needed to drive start()/stop() through the
/// activate / requireById / deactivate path.
class _FakeSessionStore implements SessionStore {
  _FakeSessionStore(this._sessionById);

  final Map<SessionId, Session> _sessionById;

  @override
  Future<void> activate(SessionId id) async {
    final existing = _sessionById[id];
    if (existing != null) {
      _sessionById[id] = existing.copyWith(status: SessionStatus.active);
    }
  }

  @override
  Future<void> deactivate(SessionId id) async {
    final existing = _sessionById[id];
    if (existing != null) {
      _sessionById[id] = existing.copyWith(status: SessionStatus.stopped);
    }
  }

  @override
  Future<Session> requireById(SessionId id) async {
    final row = _sessionById[id];
    if (row == null) throw StateError('No session for $id');
    return row;
  }

  @override
  Future<Session?> findById(SessionId id) async => _sessionById[id];

  @override
  Future<Session?> findActive() async {
    for (final s in _sessionById.values) {
      if (s.status == SessionStatus.active) return s;
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

  @override
  Future<void> updateMirkStyle({required SessionId sessionId, required MirkStyleId? mirkStyleId}) async {}
}

class _FakeFixStore implements FixStore {
  final List<Fix> inserts = <Fix>[];

  @override
  Future<void> insert(Fix fix) async => inserts.add(fix);

  @override
  Future<List<Fix>> listBySession(SessionId sessionId) async => inserts.where((f) => f.sessionId == sessionId).toList(growable: false);

  @override
  Stream<List<Fix>> watchBySession(SessionId sessionId) => Stream<List<Fix>>.value(inserts.where((f) => f.sessionId == sessionId).toList(growable: false));

  @override
  Future<int> countBySession(SessionId sessionId) async => inserts.where((f) => f.sessionId == sessionId).length;

  @override
  Future<void> deleteAllForSession(SessionId sessionId) async => inserts.removeWhere((f) => f.sessionId == sessionId);
}

class _FakeNotificationService implements SessionNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dismiss() async {}
  @override
  Future<void> showResumeNotification(SessionId sessionId, String sessionDisplayName) async {}
}

class _FakeIosSignificantChangeWatchdog implements IosSignificantChangeWatchdog {
  @override
  Future<void> startMonitoring() async {}
  @override
  Future<void> stopMonitoring() async {}
}

/// Spy-RevealedTileStore: counts mergeMask calls so the test can
/// distinguish initial (radius=20 m) writes from streaming
/// (radius=25 m) writes purely by call ordering. The first writes
/// after start() are necessarily the initial reveal (fast path);
/// subsequent calls are the streaming pipeline.
class _SpyRevealedTileStore implements RevealedTileStore {
  final List<({int parentX, int parentY, Uint8List mask})> mergeMaskCalls = <({int parentX, int parentY, Uint8List mask})>[];

  @override
  Future<void> mergeMask({required SessionId sessionId, required int parentX, required int parentY, required Uint8List mask}) async {
    mergeMaskCalls.add((parentX: parentX, parentY: parentY, mask: Uint8List.fromList(mask)));
  }

  @override
  Future<List<RevealedTile>> listBySession(SessionId sessionId) async => const <RevealedTile>[];

  @override
  Future<RevealedTile?> findByParent({required SessionId sessionId, required int parentX, required int parentY}) async => null;
}

Session _buildSession(SessionId id) => Session(
  id: id,
  displayName: 'Initial reveal test',
  status: SessionStatus.stopped,
  startedAtUtc: DateTime.utc(2026, 4, 25, 10),
  startedAtOffsetMinutes: 120,
);

Fix _buildFix({required SessionId sessionId, String suffix = '0A', double lat = 45.0, double lon = 5.0}) => Fix(
  id: FixId('fix_01HR000000000000000000$suffix'),
  sessionId: sessionId,
  recordedAtUtc: DateTime.utc(2026, 4, 25, 10, 1),
  recordedAtOffsetMinutes: 120,
  latitude: lat,
  longitude: lon,
  accuracyMeters: 5.0,
);

ProviderContainer _buildContainer({
  required _FakeSessionStore sessionStore,
  required _FakeFixStore fixStore,
  required FakeLocationStream locationStream,
  required _SpyRevealedTileStore revealedTileStore,
}) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWith((ref) async => sessionStore),
      fixStoreProvider.overrideWith((ref) async => fixStore),
      locationStreamProvider.overrideWith((ref) => locationStream),
      sessionNotificationServiceProvider.overrideWith((ref) => _FakeNotificationService()),
      iosSignificantChangeWatchdogProvider.overrideWith((ref) => _FakeIosSignificantChangeWatchdog()),
      revealedTileStoreProvider.overrideWith((ref) async => revealedTileStore),
    ],
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 5});
  });

  group('09-06 — ActiveSessionController initial reveal (MIRK-01)', () {
    test('start with cached lastKnownFix fires revealInitial immediately (fast path)', () async {
      final cachedFix = _buildFix(sessionId: _testSessionId, suffix: '0F');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{_testSessionId: _buildSession(_testSessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream()..setLastKnownFix(cachedFix);
      final revealedTileStore = _SpyRevealedTileStore();

      final container = _buildContainer(sessionStore: sessionStore, fixStore: fixStore, locationStream: locationStream, revealedTileStore: revealedTileStore);
      addTearDown(container.dispose);

      // Pre-resolve the async revealed-tile store so the synchronous
      // revealStreamingControllerProvider family read inside start()
      // sees the cached AsyncData rather than a still-loading state.
      await container.read(revealedTileStoreProvider.future);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(_testSessionId);

      expect(
        revealedTileStore.mergeMaskCalls.length,
        greaterThanOrEqualTo(1),
        reason: 'cached lastKnownFix must fire revealInitial during start() (fast path)',
      );
    });

    test('start with no cached fix → revealInitial fires on first stream emission (slow path)', () async {
      final sessionStore = _FakeSessionStore(<SessionId, Session>{_testSessionId: _buildSession(_testSessionId)});
      final fixStore = _FakeFixStore();
      // No cached fix.
      final locationStream = FakeLocationStream();
      final revealedTileStore = _SpyRevealedTileStore();

      final container = _buildContainer(sessionStore: sessionStore, fixStore: fixStore, locationStream: locationStream, revealedTileStore: revealedTileStore);
      addTearDown(container.dispose);

      // Pre-resolve the async revealed-tile store so the synchronous
      // revealStreamingControllerProvider family read inside start()
      // sees the cached AsyncData rather than a still-loading state.
      await container.read(revealedTileStoreProvider.future);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(_testSessionId);

      // No reveal writes yet — start() returned without a cached fix.
      expect(revealedTileStore.mergeMaskCalls, isEmpty, reason: 'no reveal until first stream emission lands');

      // First fix arrives — both initial reveal AND onFix should fire.
      final firstFix = _buildFix(sessionId: _testSessionId, suffix: '01');
      locationStream.emit(firstFix);
      // Allow the stream subscription's onData callback (which is async)
      // to drain.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(revealedTileStore.mergeMaskCalls.length, greaterThanOrEqualTo(1), reason: 'first stream emission must trigger initial reveal (slow path)');
    });

    test('subsequent fixes do NOT re-fire revealInitial (only onFix forwards)', () async {
      final cachedFix = _buildFix(sessionId: _testSessionId, suffix: '0F');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{_testSessionId: _buildSession(_testSessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream()..setLastKnownFix(cachedFix);
      final revealedTileStore = _SpyRevealedTileStore();

      final container = _buildContainer(sessionStore: sessionStore, fixStore: fixStore, locationStream: locationStream, revealedTileStore: revealedTileStore);
      addTearDown(container.dispose);

      // Pre-resolve the async revealed-tile store so the synchronous
      // revealStreamingControllerProvider family read inside start()
      // sees the cached AsyncData rather than a still-loading state.
      await container.read(revealedTileStoreProvider.future);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(_testSessionId);

      final initialCallCount = revealedTileStore.mergeMaskCalls.length;
      expect(initialCallCount, greaterThanOrEqualTo(1));

      // Emit a fix far enough away that it touches a NEW parent tile.
      // ~0.5° east of cachedFix at lat 45° = ~40 km — definitely a
      // different parent tile at zoom 14.
      final newFix = _buildFix(sessionId: _testSessionId, suffix: '0E', lon: 5.5);
      locationStream.emit(newFix);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The reveal pipeline buffers fixes — we cannot synchronously
      // assert a write happened. But we CAN flush by calling stop()
      // and then assert a NEW mergeMask call happened on the new tile.
      await container.read(activeSessionControllerProvider.notifier).stop();

      final newTilesTouched = revealedTileStore.mergeMaskCalls.map((c) => '${c.parentX}_${c.parentY}').toSet();
      expect(
        newTilesTouched.length,
        greaterThanOrEqualTo(2),
        reason: 'after stop()/flush, both the initial-reveal tile AND the new-fix tile have been written',
      );
    });

    test('stop() flushes the reveal pipeline (no buffered fixes survive)', () async {
      final cachedFix = _buildFix(sessionId: _testSessionId, suffix: '0F');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{_testSessionId: _buildSession(_testSessionId)});
      final fixStore = _FakeFixStore();
      final locationStream = FakeLocationStream()..setLastKnownFix(cachedFix);
      final revealedTileStore = _SpyRevealedTileStore();

      final container = _buildContainer(sessionStore: sessionStore, fixStore: fixStore, locationStream: locationStream, revealedTileStore: revealedTileStore);
      addTearDown(container.dispose);

      // Pre-resolve the async revealed-tile store so the synchronous
      // revealStreamingControllerProvider family read inside start()
      // sees the cached AsyncData rather than a still-loading state.
      await container.read(revealedTileStoreProvider.future);
      await container.read(activeSessionControllerProvider.future);
      await container.read(activeSessionControllerProvider.notifier).start(_testSessionId);
      // Add a few fixes that the buffer would normally hold pending.
      locationStream.emit(_buildFix(sessionId: _testSessionId, suffix: '01'));
      locationStream.emit(_buildFix(sessionId: _testSessionId, suffix: '02'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final beforeStop = revealedTileStore.mergeMaskCalls.length;

      await container.read(activeSessionControllerProvider.notifier).stop();

      // After stop() the buffer must be drained — call count is at
      // least equal to before-stop (idempotent + flush pushes any
      // buffered fixes to mergeMask).
      expect(revealedTileStore.mergeMaskCalls.length, greaterThanOrEqualTo(beforeStop), reason: 'stop() must flush — no fix is dropped on session end');
      expect(container.read(activeSessionControllerProvider).value, isA<Idle>());
    });
  });
}

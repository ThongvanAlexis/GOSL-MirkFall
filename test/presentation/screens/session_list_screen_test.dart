// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/providers/fix_store_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/fixes/fix_store.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/presentation/screens/session_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake [SessionStore] backed by a [StreamController] for
/// `watchAll()`. Lets tests seed sessions, observe inserts, and assert
/// the rendered list without wiring an AppDatabase.
///
/// Stream semantics: matches Drift's `select().watch()` — first
/// emission carries the current snapshot when the subscriber listens,
/// subsequent emissions fire on every mutation. Implemented by calling
/// `_emit()` on every insert/update/delete AND on first listen (via
/// `onListen`) so a late subscriber never sees an empty stream.
class FakeSessionStore implements SessionStore {
  FakeSessionStore([List<Session>? initial]) {
    if (initial != null) {
      for (final s in initial) {
        _byId[s.id] = s;
      }
    }
    _controller = StreamController<List<Session>>.broadcast(onListen: _emit);
  }

  final Map<SessionId, Session> _byId = <SessionId, Session>{};
  late final StreamController<List<Session>> _controller;
  final List<Session> inserts = <Session>[];
  final List<Session> updates = <Session>[];
  final List<SessionId> deletes = <SessionId>[];

  void _emit() {
    if (_controller.isClosed) return;
    final list = _byId.values.toList()..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    _controller.add(list);
  }

  @override
  Future<List<Session>> listAll() async {
    final list = _byId.values.toList()..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return list;
  }

  @override
  Future<Session?> findById(SessionId id) async => _byId[id];

  @override
  Future<Session> requireById(SessionId id) async {
    final s = _byId[id];
    if (s == null) throw StateError('Not found: $id');
    return s;
  }

  @override
  Future<Session?> findActive() async {
    for (final s in _byId.values) {
      if (s.status == SessionStatus.active) return s;
    }
    return null;
  }

  @override
  Future<void> insert(Session session) async {
    inserts.add(session);
    _byId[session.id] = session;
    _emit();
  }

  @override
  Future<void> update(Session session) async {
    updates.add(session);
    _byId[session.id] = session;
    _emit();
  }

  @override
  Future<void> delete(SessionId id) async {
    deletes.add(id);
    _byId.remove(id);
    _emit();
  }

  @override
  Future<void> activate(SessionId id) async {
    final existing = _byId[id];
    if (existing != null) {
      _byId[id] = existing.copyWith(status: SessionStatus.active);
      _emit();
    }
  }

  @override
  Future<void> deactivate(SessionId id) async {
    final existing = _byId[id];
    if (existing != null) {
      _byId[id] = existing.copyWith(status: SessionStatus.stopped);
      _emit();
    }
  }

  @override
  Stream<List<Session>> watchAll() => _controller.stream;

  Future<void> disposeController() async {
    await _controller.close();
  }
}

class FakeFixStore implements FixStore {
  final List<Fix> fixes = <Fix>[];

  @override
  Future<void> insert(Fix fix) async => fixes.add(fix);

  @override
  Future<List<Fix>> listBySession(SessionId sessionId) async => fixes.where((f) => f.sessionId == sessionId).toList(growable: false);

  @override
  Stream<List<Fix>> watchBySession(SessionId sessionId) => Stream<List<Fix>>.value(fixes.where((f) => f.sessionId == sessionId).toList(growable: false));

  @override
  Future<int> countBySession(SessionId sessionId) async => fixes.where((f) => f.sessionId == sessionId).length;

  @override
  Future<void> deleteAllForSession(SessionId sessionId) async => fixes.removeWhere((f) => f.sessionId == sessionId);
}

Session buildSession({
  required String id,
  String displayName = 'Test',
  DateTime? startedAtUtc,
  SessionStatus status = SessionStatus.stopped,
}) => Session(
  id: SessionId(id),
  displayName: displayName,
  status: status,
  startedAtUtc: startedAtUtc ?? DateTime.utc(2026, 4, 19, 10),
  startedAtOffsetMinutes: 120,
);

// `Override` is NOT publicly exported by `flutter_riverpod` (Riverpod
// 3.3.x `show` clause excludes the sealed type). Call sites inline the
// `ProviderScope` so the override-list type is inferred from
// [ProviderScope.overrides].

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('SessionListScreen', () {
    testWidgets('emptyStateShowsCreateFirstCta', (tester) async {
      final sessionStore = FakeSessionStore();
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();

      await tester.pumpWidget(
        ProviderScope(overrides: [
          sessionStoreProvider.overrideWith((ref) async => sessionStore),
          fixStoreProvider.overrideWith((ref) async => fixStore),
        ], child: MaterialApp(home: const SessionListScreen())),
      );
      // Pump a frame so the async session list resolves.
      await tester.pumpAndSettle();

      expect(find.text("Aucune session pour l'instant"), findsOneWidget);
      expect(find.text('Créer ma première session'), findsOneWidget);
    });

    testWidgets('rendersSessionsFromWatchAllInDescOrder', (tester) async {
      final sessionStore = FakeSessionStore(<Session>[
        buildSession(id: 'sess_00000000000000000000000001', displayName: 'Oldest', startedAtUtc: DateTime.utc(2026, 4, 10)),
        buildSession(id: 'sess_00000000000000000000000002', displayName: 'Middle', startedAtUtc: DateTime.utc(2026, 4, 15)),
        buildSession(id: 'sess_00000000000000000000000003', displayName: 'Newest', startedAtUtc: DateTime.utc(2026, 4, 19)),
      ]);
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();

      await tester.pumpWidget(
        ProviderScope(overrides: [
          sessionStoreProvider.overrideWith((ref) async => sessionStore),
          fixStoreProvider.overrideWith((ref) async => fixStore),
        ], child: MaterialApp(home: const SessionListScreen())),
      );
      await tester.pumpAndSettle();

      // All three rendered.
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Middle'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);

      // DESC order: "Newest" appears visually above "Middle" above
      // "Oldest". Use topLeft offset comparison.
      final newest = tester.getTopLeft(find.text('Newest'));
      final middle = tester.getTopLeft(find.text('Middle'));
      final oldest = tester.getTopLeft(find.text('Oldest'));
      expect(newest.dy, lessThan(middle.dy));
      expect(middle.dy, lessThan(oldest.dy));
    });

    testWidgets('activeSessionRowShowsActiveBadge', (tester) async {
      final sessionStore = FakeSessionStore(<Session>[
        buildSession(id: 'sess_00000000000000000000000099', displayName: 'Live one', status: SessionStatus.active),
      ]);
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();

      await tester.pumpWidget(
        ProviderScope(overrides: [
          sessionStoreProvider.overrideWith((ref) async => sessionStore),
          fixStoreProvider.overrideWith((ref) async => fixStore),
        ], child: MaterialApp(home: const SessionListScreen())),
      );
      await tester.pumpAndSettle();

      // Subtitle carries "• active" when the status is active.
      final Finder activeText = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('• active'));
      expect(activeText, findsOneWidget);
    });

    testWidgets('fabOpensCreateDialog', (tester) async {
      final sessionStore = FakeSessionStore();
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();

      await tester.pumpWidget(
        ProviderScope(overrides: [
          sessionStoreProvider.overrideWith((ref) async => sessionStore),
          fixStoreProvider.overrideWith((ref) async => fixStore),
        ], child: MaterialApp(home: const SessionListScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle session'), findsOneWidget);
      // Both create variants are visible.
      expect(find.text('Créer'), findsOneWidget);
      expect(find.text('Créer et démarrer'), findsOneWidget);
    });

    testWidgets('hundredSessionsRenderWithoutTimeout', (tester) async {
      // SESS-09 stress: 100 sessions render via ListView.separated.
      final seeded = <Session>[
        for (int i = 0; i < 100; i++)
          buildSession(
            id: 'sess_${i.toString().padLeft(26, '0')}',
            displayName: 'Session $i',
            startedAtUtc: DateTime.utc(2026, 4, 19, 0, i),
          ),
      ];
      final sessionStore = FakeSessionStore(seeded);
      addTearDown(sessionStore.disposeController);
      final fixStore = FakeFixStore();

      await tester.pumpWidget(
        ProviderScope(overrides: [
          sessionStoreProvider.overrideWith((ref) async => sessionStore),
          fixStoreProvider.overrideWith((ref) async => fixStore),
        ], child: MaterialApp(home: const SessionListScreen())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // First tile of the DESC list (index 0 has the latest minute).
      expect(find.text('Session 99'), findsOneWidget);
    });
  });
}

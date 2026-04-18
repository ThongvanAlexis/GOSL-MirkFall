// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Drift re-exports an `isNotNull` column matcher that collides with
// matcher's value matcher; `hide` it so matcher's version dominates.
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:mirkfall/domain/errors/concurrent_errors.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/errors/session_errors.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/stores/drift_session_store.dart';
import 'package:test/test.dart';

AppDatabase _newDb() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA journal_mode = WAL');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

/// Generates a deterministic 26-char sentinel body per numeric [index]
/// for exclusivity-test session IDs. Uses a fixed pad character ('A')
/// so IDs remain human-greppable when they leak into logs.
String _sessId(int index) => 'sess_01HRTESTSESSEXCL${index.toString().padLeft(2, '0')}AAAAAAAA';

void main() {
  late AppDatabase db;
  late DriftSessionStore store;

  setUp(() async {
    db = _newDb();
    store = DriftSessionStore(db);
    // Open + apply pragmas so the first INSERT doesn't race the migration.
    await db.customStatement('SELECT 1');

    for (var i = 0; i < 3; i++) {
      await store.insert(
        Session(
          id: SessionId(_sessId(i)),
          displayName: 'Session $i',
          status: SessionStatus.stopped,
          startedAtUtc: DateTime.utc(2026, 4, 18, 10 + i),
          startedAtOffsetMinutes: 120,
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  test('activate first session -> status becomes active', () async {
    final id0 = SessionId(_sessId(0));
    await store.activate(id0);
    final active = await store.findActive();
    expect(active, isNotNull);
    expect(active!.id, id0);
    expect(active.status, SessionStatus.active);
  });

  test('activate second session while first is active -> '
      'ConcurrentActivationException', () async {
    final id0 = SessionId(_sessId(0));
    final id1 = SessionId(_sessId(1));
    await store.activate(id0);
    await expectLater(() => store.activate(id1), throwsA(isA<ConcurrentActivationException>().having((e) => e.attemptedId, 'attemptedId', id1)));
    // The first session must still be the only active one.
    final active = await store.findActive();
    expect(active?.id, id0);
  });

  test('deactivating an active session unlocks activation of another', () async {
    final id0 = SessionId(_sessId(0));
    final id1 = SessionId(_sessId(1));
    await store.activate(id0);
    await store.deactivate(id0);
    await store.activate(id1);
    final active = await store.findActive();
    expect(active?.id, id1);
  });

  test('concurrent activation via Future.wait - exactly one succeeds', () async {
    final id0 = SessionId(_sessId(0));
    final id1 = SessionId(_sessId(1));

    final results = await Future.wait<Object?>(<Future<Object?>>[
      store.activate(id0).then<Object?>((_) => 'ok', onError: (Object e) => e),
      store.activate(id1).then<Object?>((_) => 'ok', onError: (Object e) => e),
    ]);
    final successes = results.where((r) => r == 'ok').length;
    final failures = results.whereType<ConcurrentActivationException>().length;
    expect(successes, 1, reason: 'exactly one activate should succeed');
    expect(failures, 1, reason: 'exactly one ConcurrentActivationException should be raised');

    // Exactly one row with status='active' remains.
    final activeRows = await db.customSelect("SELECT COUNT(*) AS c FROM t_sessions WHERE status = 'active'").getSingle();
    expect(activeRows.read<int>('c'), 1);
  });

  // Finding #3 + #25 (Batch G) — activate/deactivate now fail loudly on
  // nonexistent ids instead of silently succeeding.

  test('activate(nonExistent) -> SessionNotFoundException', () async {
    const nonExistent = SessionId('sess_01HRGHOSTSESSIONAAAAAAAAAAA');
    await expectLater(() => store.activate(nonExistent), throwsA(isA<SessionNotFoundException>().having((e) => e.id, 'id', nonExistent)));
  });

  test('deactivate(nonExistent) -> SessionNotFoundException', () async {
    const nonExistent = SessionId('sess_01HRGHOSTSESSIONAAAAAAAAAAA');
    await expectLater(() => store.deactivate(nonExistent), throwsA(isA<SessionNotFoundException>().having((e) => e.id, 'id', nonExistent)));
  });

  // Finding #4 + #26 (Batch G) — SqliteException 2067 wrap now covers the
  // insert(active) path too. Exercising it proves no raw SqliteException
  // leaks to the caller when a second active session is inserted.

  test('insert(active) + insert(active) -> second throws ConcurrentActivationException', () async {
    final id4 = SessionId(_sessId(4));
    final id5 = SessionId(_sessId(5));
    final now = DateTime.utc(2026, 4, 18, 12);

    await store.insert(Session(id: id4, displayName: 'S4', status: SessionStatus.active, startedAtUtc: now, startedAtOffsetMinutes: 120));
    await expectLater(
      () => store.insert(Session(id: id5, displayName: 'S5', status: SessionStatus.active, startedAtUtc: now, startedAtOffsetMinutes: 120)),
      throwsA(isA<ConcurrentActivationException>().having((e) => e.attemptedId, 'attemptedId', id5)),
    );

    // Only one active row remains — the first one.
    final activeRows = await db.customSelect("SELECT COUNT(*) AS c FROM t_sessions WHERE status = 'active'").getSingle();
    expect(activeRows.read<int>('c'), 1);
  });

  test('update(active) on a stopped row while another is active -> ConcurrentActivationException', () async {
    final id0 = SessionId(_sessId(0));
    final id1 = SessionId(_sessId(1));
    final now = DateTime.utc(2026, 4, 18, 12);

    await store.activate(id0);
    // Build a new Session(id=id1) carrying status=active and try to update.
    final conflict = Session(id: id1, displayName: 'Session 1', status: SessionStatus.active, startedAtUtc: now, startedAtOffsetMinutes: 120);
    await expectLater(() => store.update(conflict), throwsA(isA<ConcurrentActivationException>().having((e) => e.attemptedId, 'attemptedId', id1)));

    // The only active row is still id0.
    final active = await store.findActive();
    expect(active?.id, id0);
  });
}

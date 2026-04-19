// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
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

/// SESS-02 — rename via `update(displayName:)` — idempotence + persistence.
void main() {
  late AppDatabase db;
  late DriftSessionStore store;
  const SessionId sessionId = SessionId('sess_01HRRENAMETESTAAAAAAAAAAAAAA');

  setUp(() async {
    db = _newDb();
    await db.customStatement('SELECT 1');
    store = DriftSessionStore(db);
    await store.insert(
      Session(
        id: sessionId,
        displayName: 'Initial',
        status: SessionStatus.stopped,
        startedAtUtc: DateTime.utc(2026, 4, 19, 8),
        startedAtOffsetMinutes: 120,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('rename persists — requireById reads back the new displayName', () async {
    final original = await store.requireById(sessionId);
    await store.update(original.copyWith(displayName: 'Renamed'));

    final reread = await store.requireById(sessionId);
    expect(reread.displayName, 'Renamed');
    expect(reread.id, sessionId);
  });

  test('rename is idempotent — re-applying the same displayName does not throw', () async {
    final original = await store.requireById(sessionId);
    await store.update(original.copyWith(displayName: 'Renamed'));

    // Second rename to the same value — must not throw.
    final refreshed = await store.requireById(sessionId);
    expect(
      () async => store.update(refreshed.copyWith(displayName: 'Renamed')),
      returnsNormally,
    );

    final reread = await store.requireById(sessionId);
    expect(reread.displayName, 'Renamed');
  });

  test('rename preserves other fields (status, startedAtUtc, offsets)', () async {
    final original = await store.requireById(sessionId);
    await store.update(original.copyWith(displayName: 'Paris trip'));

    final reread = await store.requireById(sessionId);
    expect(reread.status, original.status);
    expect(reread.startedAtUtc, original.startedAtUtc);
    expect(reread.startedAtOffsetMinutes, original.startedAtOffsetMinutes);
  });
}

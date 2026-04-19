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

/// Sequenced session id — the 26-char body is `00000000000000000000` + a
/// zero-padded sequence number so every id is globally unique + reproducible.
/// Plain-string suffix (no cryptographic property needed — stress test only).
String _sequencedSessionId(int n) {
  final body = n.toString().padLeft(26, '0');
  return 'sess_$body';
}

/// SESS-09 — 100-session stress smoke (list + watch first emission).
void main() {
  late AppDatabase db;
  late DriftSessionStore store;

  setUp(() async {
    db = _newDb();
    await db.customStatement('SELECT 1');
    store = DriftSessionStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('100 sessions insertable and listable without crash', () async {
    for (var i = 0; i < 100; i++) {
      await store.insert(
        Session(
          id: SessionId(_sequencedSessionId(i)),
          displayName: 'Session $i',
          status: SessionStatus.stopped,
          // Stagger startedAtUtc so the DESC-ordered listAll() is deterministic.
          startedAtUtc: DateTime.utc(2026, 4, 19).add(Duration(minutes: i)),
          startedAtOffsetMinutes: 0,
        ),
      );
    }

    final all = await store.listAll();
    expect(all, hasLength(100));
  });

  test('watchAll first emission carries all 100 rows', () async {
    for (var i = 0; i < 100; i++) {
      await store.insert(
        Session(
          id: SessionId(_sequencedSessionId(i)),
          displayName: 'Session $i',
          status: SessionStatus.stopped,
          startedAtUtc: DateTime.utc(2026, 4, 19).add(Duration(minutes: i)),
          startedAtOffsetMinutes: 0,
        ),
      );
    }

    final first = await store.watchAll().first;
    expect(first, hasLength(100));
  });
}

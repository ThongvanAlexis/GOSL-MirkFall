// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: unused_import
// TODO(05-01 Task 4): DriftFixStore lands in Plan 05-01 Task 4. Imports turn
// green at that point. Currently RED by design (TDD).

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/stores/drift_fix_store.dart';
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

Future<void> _seedSession(AppDatabase db, SessionId sessionId) async {
  final store = DriftSessionStore(db);
  await store.insert(
    Session(
      id: sessionId,
      displayName: 'Fix store test',
      status: SessionStatus.active,
      startedAtUtc: DateTime.utc(2026, 4, 19, 10),
      startedAtOffsetMinutes: 120,
    ),
  );
}

Fix _buildFix({
  required String fixId,
  required SessionId sessionId,
  required int epochMs,
  double latitude = 48.8566,
  double longitude = 2.3522,
  double accuracyMeters = 5.0,
}) => Fix(
  id: FixId(fixId),
  sessionId: sessionId,
  recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
  recordedAtOffsetMinutes: 120,
  latitude: latitude,
  longitude: longitude,
  accuracyMeters: accuracyMeters,
);

void main() {
  late AppDatabase db;
  late DriftFixStore store;
  const SessionId sessionId = SessionId('sess_01HRFIXSTORETESTAAAAAAAAAA');

  setUp(() async {
    db = _newDb();
    await db.customStatement('SELECT 1');
    await _seedSession(db, sessionId);
    store = DriftFixStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insertPersistsAllColumns — round-trip through listBySession', () async {
    final fix = _buildFix(fixId: 'fix_01HRFIXSTORE00000000000AA', sessionId: sessionId, epochMs: 1765000000000);
    await store.insert(fix);

    final rows = await store.listBySession(sessionId);
    expect(rows, hasLength(1));
    expect(rows.single.id, fix.id);
    expect(rows.single.sessionId, fix.sessionId);
    expect(rows.single.latitude, fix.latitude);
    expect(rows.single.longitude, fix.longitude);
    expect(rows.single.accuracyMeters, fix.accuracyMeters);
  });

  test('listBySessionOrdersByRecordedAt — ASC', () async {
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTOREB0000000000AA', sessionId: sessionId, epochMs: 2000));
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTOREA0000000000AA', sessionId: sessionId, epochMs: 1000));
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTOREC0000000000AA', sessionId: sessionId, epochMs: 3000));

    final rows = await store.listBySession(sessionId);
    expect(rows.map((f) => f.recordedAtUtc.millisecondsSinceEpoch).toList(), <int>[1000, 2000, 3000]);
  });

  test('watchBySessionEmitsOnInsert', () async {
    final stream = store.watchBySession(sessionId);
    final values = <List<Fix>>[];
    final sub = stream.listen(values.add);

    // Allow initial emission.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTOREW0000000000AA', sessionId: sessionId, epochMs: 5000));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(values.isNotEmpty, isTrue);
    expect(values.last, hasLength(1));
    await sub.cancel();
  });

  test('countBySessionMatchesListLength', () async {
    expect(await store.countBySession(sessionId), 0);
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTOREX0000000000AA', sessionId: sessionId, epochMs: 100));
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTOREY0000000000AA', sessionId: sessionId, epochMs: 200));
    expect(await store.countBySession(sessionId), 2);
  });

  test('deleteAllForSessionRemovesRows + idempotent', () async {
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTOREZ0000000000AA', sessionId: sessionId, epochMs: 100));
    expect(await store.countBySession(sessionId), 1);

    await store.deleteAllForSession(sessionId);
    expect(await store.countBySession(sessionId), 0);

    // Idempotent: second call does not throw.
    await store.deleteAllForSession(sessionId);
    expect(await store.countBySession(sessionId), 0);
  });

  test('fkCascadeRemovesFixesWhenSessionDeleted', () async {
    await store.insert(_buildFix(fixId: 'fix_01HRFIXSTORECC000000000AA', sessionId: sessionId, epochMs: 100));
    expect(await store.countBySession(sessionId), 1);

    // Drop the session via the session store — FK ON DELETE CASCADE must
    // remove the fix row without a manual deleteAllForSession call.
    final sessionStore = DriftSessionStore(db);
    await sessionStore.delete(sessionId);

    expect(await store.countBySession(sessionId), 0, reason: 'FK ON DELETE CASCADE did not fire on t_fixes');
  });
}

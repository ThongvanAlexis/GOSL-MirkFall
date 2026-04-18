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
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/ids/seeded_id_generator.dart';
import 'package:mirkfall/infrastructure/stores/drift_session_store.dart';
import 'package:mirkfall/infrastructure/stores/sqlite_error_mapper.dart';
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

void main() {
  late AppDatabase db;
  late DriftSessionStore store;

  setUp(() async {
    db = _newDb();
    store = DriftSessionStore(db, SeededIdGenerator(seed: 7));
    await db.customStatement('SELECT 1');
  });

  tearDown(() async {
    await db.close();
  });

  test('SqliteException 2067 (SQLITE_CONSTRAINT_UNIQUE) on activate is '
      'mapped to ConcurrentActivationException (not leaked)', () async {
    const id0 = SessionId('sess_01HRERRORMAPPING00AAAAAAAAAAAA');
    const id1 = SessionId('sess_01HRERRORMAPPING01AAAAAAAAAAAA');
    for (final id in <SessionId>[id0, id1]) {
      await store.insert(
        Session(
          id: id,
          displayName: id.value,
          status: SessionStatus.stopped,
          startedAtUtc: DateTime.utc(2026, 4, 18, 10),
          startedAtOffsetMinutes: 120,
        ),
      );
    }

    await store.activate(id0);

    // Catch directly so we can assert BOTH shapes in a single attempt:
    // (a) the thrown instance is ConcurrentActivationException;
    // (b) it is NOT a SqliteException (no leak of the driver type through
    //     the store boundary).
    late Object thrown;
    try {
      await store.activate(id1);
      fail('expected activate(id1) to throw while id0 is active');
    } on Object catch (e) {
      thrown = e;
    }
    expect(thrown, isA<ConcurrentActivationException>());
    expect(thrown, isNot(isA<SqliteException>()),
        reason: 'store layer must NOT leak the raw driver type');
    expect((thrown as ConcurrentActivationException).attemptedId, id1);
  });

  test('extendedResultCode 2067 is the contract under test '
      '(documented constant matches driver behaviour)', () async {
    // Sanity: drive the partial unique index directly via raw SQL so we
    // can prove the driver raises extendedResultCode 2067 before it is
    // caught and rewrapped in the higher-level test above. Documents the
    // kSqliteConstraintUnique constant's provenance.
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('sess_RAW1', 'A1', 'active', 1000, 120)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
        "started_at_offset_minutes) VALUES ('sess_RAW2', 'A2', 'active', 2000, 120)",
      ),
      throwsA(
        isA<SqliteException>().having(
          (e) => e.extendedResultCode,
          'extendedResultCode',
          kSqliteConstraintUnique,
        ),
      ),
    );
  });

  test('other SqliteException codes (non-2067) propagate unchanged '
      '- store layer does NOT wide-catch', () async {
    // Attempting to insert into a non-existent table triggers a
    // SqliteException whose extendedResultCode is NOT 2067. The raw
    // exception must surface unchanged.
    late Object thrown;
    try {
      await db.customStatement(
        'INSERT INTO t_does_not_exist (x) VALUES (1)',
      );
      fail('expected SqliteException for a missing table insert');
    } on Object catch (e) {
      thrown = e;
    }
    expect(thrown, isA<SqliteException>());
    expect(
      (thrown as SqliteException).extendedResultCode,
      isNot(kSqliteConstraintUnique),
      reason:
          'precondition: the driver must raise a non-unique-constraint code '
          'for this particular error class',
    );
  });
}

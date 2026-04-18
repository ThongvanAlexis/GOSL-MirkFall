// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:mirkfall/domain/errors/concurrent_errors.dart';
import 'package:mirkfall/domain/errors/session_errors.dart';
import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/db/type_converters.dart';
import 'package:mirkfall/infrastructure/stores/sqlite_error_mapper.dart';

/// Drift-backed [SessionStore] implementation.
///
/// SESS-06 runtime enforcement: [activate] catches `SqliteException` with
/// `extendedResultCode == kSqliteConstraintUnique` (2067) raised by the
/// partial unique index `idx_t_sessions_status_active` and rewraps it in
/// [ConcurrentActivationException]. Every other `SqliteException` code is
/// rethrown unchanged per RESEARCH §pitfall #4 (never wide-catch driver
/// errors — a FK violation is a different bug class than a concurrent
/// activation race).
///
/// [IdGenerator] is accepted by constructor for future insert-without-id
/// paths and for symmetry with the other stores; Phase 03 callers always
/// pass a pre-allocated id in the [Session] they [insert].
class DriftSessionStore implements SessionStore {
  DriftSessionStore(this._db, this._idGenerator);

  final AppDatabase _db;
  // ignore: unused_field — reserved for insert-without-id paths, see docstring.
  final IdGenerator _idGenerator;

  static const SessionStatusStringConverter _statusConv =
      SessionStatusStringConverter();

  @override
  Future<List<Session>> listAll() async {
    final rows = await (_db.select(_db.sessions)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.startedAtUtc,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<Session?> findById(SessionId id) async {
    final row = await (_db.select(_db.sessions)
          ..where((t) => t.id.equals(id.value)))
        .getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<Session> requireById(SessionId id) async {
    final session = await findById(id);
    if (session == null) {
      throw SessionNotFoundException(id: id);
    }
    return session;
  }

  @override
  Future<Session?> findActive() async {
    final row = await (_db.select(_db.sessions)
          ..where((t) => t.status.equals('active')))
        .getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<void> insert(Session session) async {
    await _db.into(_db.sessions).insert(_toInsertCompanion(session));
  }

  @override
  Future<void> update(Session session) async {
    await _db.update(_db.sessions).replace(_toInsertCompanion(session));
  }

  @override
  Future<void> delete(SessionId id) async {
    await (_db.delete(_db.sessions)..where((t) => t.id.equals(id.value))).go();
  }

  @override
  Future<void> activate(SessionId id) async {
    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(id.value)))
          .write(const SessionsCompanion(status: Value('active')));
    } on SqliteException catch (e) {
      if (e.extendedResultCode == kSqliteConstraintUnique) {
        throw ConcurrentActivationException(attemptedId: id);
      }
      rethrow;
    }
  }

  @override
  Future<void> deactivate(SessionId id) async {
    await (_db.update(_db.sessions)..where((t) => t.id.equals(id.value)))
        .write(const SessionsCompanion(status: Value('stopped')));
  }

  // -- hydration ---------------------------------------------------------

  Session _hydrate(SessionRow row) => Session(
        id: SessionId(row.id),
        displayName: row.displayName,
        status: _statusConv.fromSql(row.status),
        startedAtUtc: row.startedAtUtc,
        startedAtOffsetMinutes: row.startedAtOffsetMinutes,
        stoppedAtUtc: row.stoppedAtUtc,
        stoppedAtOffsetMinutes: row.stoppedAtOffsetMinutes,
        notes: row.notes,
      );

  SessionsCompanion _toInsertCompanion(Session s) => SessionsCompanion.insert(
        id: s.id.value,
        displayName: s.displayName,
        status: _statusConv.toSql(s.status),
        startedAtUtc: s.startedAtUtc,
        startedAtOffsetMinutes: s.startedAtOffsetMinutes,
        stoppedAtUtc: Value(s.stoppedAtUtc),
        stoppedAtOffsetMinutes: Value(s.stoppedAtOffsetMinutes),
        notes: Value(s.notes),
      );
}

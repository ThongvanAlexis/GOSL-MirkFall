// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:mirkfall/domain/errors/concurrent_errors.dart';
import 'package:mirkfall/domain/errors/session_errors.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/db/type_converters.dart';
import 'package:mirkfall/infrastructure/stores/sqlite_error_mapper.dart';

/// Drift-backed [SessionStore] implementation.
///
/// SESS-06 runtime enforcement: [activate], [insert], and [update] catch
/// `SqliteException` with `extendedResultCode == kSqliteConstraintUnique`
/// (2067) raised by the partial unique index `idx_t_sessions_status_active`
/// and rewrap it in [ConcurrentActivationException]. Every other
/// `SqliteException` code is rethrown unchanged per RESEARCH §pitfall #4
/// (never wide-catch driver errors — a FK violation is a different bug class
/// than a concurrent activation race).
///
/// State-transition signaling (findings #3 + #25, Batch G): [activate] and
/// [deactivate] throw [SessionNotFoundException] when the UPDATE affects 0
/// rows (the session id is not present). Silent no-op on state transitions
/// was an invariant violation — the contract now holds for every caller.
class DriftSessionStore implements SessionStore {
  DriftSessionStore(this._db);

  final AppDatabase _db;

  static const SessionStatusStringConverter _statusConv = SessionStatusStringConverter();

  @override
  Future<List<Session>> listAll() async {
    final rows = await (_db.select(_db.sessions)..orderBy([(t) => OrderingTerm(expression: t.startedAtUtc, mode: OrderingMode.desc)])).get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<Session?> findById(SessionId id) async {
    final row = await (_db.select(_db.sessions)..where((t) => t.id.equals(id.value))).getSingleOrNull();
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
    final row = await (_db.select(_db.sessions)..where((t) => t.status.equals(_statusConv.toSql(SessionStatus.active)))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<void> insert(Session session) async {
    // Finding #4 (Batch G) — SqliteException 2067 wrap scope extended to
    // the insert path: insert(Session with status=active) hits the same
    // partial unique index as activate() would, and the invariant "domain
    // never sees SqliteException" must hold at every write site.
    try {
      await _db.into(_db.sessions).insert(_toInsertCompanion(session));
    } on SqliteException catch (e) {
      if (e.extendedResultCode == kSqliteConstraintUnique) {
        throw ConcurrentActivationException(attemptedId: session.id);
      }
      rethrow;
    }
  }

  @override
  Future<void> update(Session session) async {
    // Finding #4 (Batch G) — SqliteException 2067 wrap scope extended to
    // update() for the same reason as insert(): update(status=active) can
    // collide with the partial unique index when a concurrent actor has
    // already flipped another row to active.
    try {
      await _db.update(_db.sessions).replace(_toInsertCompanion(session));
    } on SqliteException catch (e) {
      if (e.extendedResultCode == kSqliteConstraintUnique) {
        throw ConcurrentActivationException(attemptedId: session.id);
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(SessionId id) async {
    await (_db.delete(_db.sessions)..where((t) => t.id.equals(id.value))).go();
  }

  @override
  Future<void> activate(SessionId id) async {
    // Finding #3 + #25 (Batch G) — throw on 0 rows affected. Pre-Batch-G,
    // activate() silently succeeded on nonexistent/already-stopped ids
    // because the UPDATE simply matched zero rows. The contract now: if
    // the session id does not exist, the caller gets a clear
    // SessionNotFoundException.
    //
    // Finding #24 (Batch G) — use the converter instead of raw 'active'.
    final rowsAffected = await _activateOrThrow(id);
    if (rowsAffected == 0) {
      throw SessionNotFoundException(id: id);
    }
  }

  /// Performs the `status = 'active'` UPDATE and returns `rowsAffected`.
  /// Rewraps SqliteException 2067 into [ConcurrentActivationException]
  /// (finding #4 still holds on the activate path).
  Future<int> _activateOrThrow(SessionId id) async {
    try {
      return await (_db.update(
        _db.sessions,
      )..where((t) => t.id.equals(id.value))).write(SessionsCompanion(status: Value(_statusConv.toSql(SessionStatus.active))));
    } on SqliteException catch (e) {
      if (e.extendedResultCode == kSqliteConstraintUnique) {
        throw ConcurrentActivationException(attemptedId: id);
      }
      rethrow;
    }
  }

  @override
  Future<void> deactivate(SessionId id) async {
    // Finding #3 + #25 (Batch G) — symmetric throw-on-0-rows with activate.
    // Finding #24 — use the converter instead of raw 'stopped'.
    final rowsAffected = await (_db.update(
      _db.sessions,
    )..where((t) => t.id.equals(id.value))).write(SessionsCompanion(status: Value(_statusConv.toSql(SessionStatus.stopped))));
    if (rowsAffected == 0) {
      throw SessionNotFoundException(id: id);
    }
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

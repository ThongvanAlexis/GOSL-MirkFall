// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/mirk_style_id.dart';
import '../ids/session_id.dart';
import 'session.dart';

/// Port for session persistence + lifecycle.
///
/// Implementations live in `lib/infrastructure/stores/` (Phase 03-06 Drift
/// impl). The contract explicitly follows the CONTEXT.md §Stratégie erreurs
/// §find-vs-require split: `findById` returns `null` when the row is absent;
/// `requireById` throws `SessionNotFoundException` — the caller chooses
/// which semantic they want at the call site rather than special-casing
/// inside the store.
abstract class SessionStore {
  /// Returns all sessions (active + stopped), ordered by [Session.startedAtUtc]
  /// descending by default.
  Future<List<Session>> listAll();

  /// Returns the session with [id] or null if none exists (find semantic).
  Future<Session?> findById(SessionId id);

  /// Returns the session with [id] or throws `SessionNotFoundException`
  /// (require semantic — caller promises it exists).
  Future<Session> requireById(SessionId id);

  /// Returns the single active session, or null if none is active.
  /// Exclusivity is enforced at the DB layer (SESS-06); this method never
  /// returns more than one.
  Future<Session?> findActive();

  Future<void> insert(Session session);

  Future<void> update(Session session);

  /// Hard-deletes the session and cascades: markers, revealed_tiles, and
  /// photos attached to those markers are removed in the same transaction
  /// via FK ON DELETE CASCADE (D4). No soft-delete / corbeille (project
  /// decision: stopped sessions are immutable; deletion is terminal).
  Future<void> delete(SessionId id);

  /// Activates the given session.
  ///
  /// SESS-06 exclusivity is enforced via a partial unique index on
  /// `t_sessions(status='active')` — a second concurrent activation from
  /// another code path throws `ConcurrentActivationException`. The Drift
  /// impl wraps the raw `SqliteException` (extended code 2067) into the
  /// domain exception so callers never see a driver-level error type.
  Future<void> activate(SessionId id);

  /// Stops the session (transitions status `active` -> `stopped`).
  Future<void> deactivate(SessionId id);

  /// Sets `t_sessions.mirk_style_id` to [mirkStyleId] for the row at
  /// [sessionId]. `null` clears the column (degrades to renderer-side
  /// default — see 09-05 SUMMARY §Decisions).
  ///
  /// Phase 09 plan 09-06: dedicated narrow write path used by
  /// `MirkStyleSessionController.select()`. Distinct from [update] so
  /// the rest of the row stays untouched (no need to read-modify-write
  /// the full Session, no risk of clobbering a concurrent edit to
  /// other columns).
  ///
  /// Throws `SessionNotFoundException` when the row is absent.
  Future<void> updateMirkStyle({required SessionId sessionId, required MirkStyleId? mirkStyleId});

  /// Emits the current list of sessions on every row change in
  /// `t_sessions`. Ordering matches [listAll] — `startedAtUtc` DESC.
  ///
  /// First emission carries the current snapshot. Consumed by
  /// `SessionListScreen` in Plan 05-05; Phase 11 and Phase 13 reuse.
  /// Resolves 05-RESEARCH Open Question #5.
  Stream<List<Session>> watchAll();
}

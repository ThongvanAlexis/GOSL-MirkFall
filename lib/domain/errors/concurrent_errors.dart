// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/session_id.dart';

/// Thrown when two code paths attempt to activate a session simultaneously.
///
/// SESS-06 enforcement lives at the DB layer (partial unique index on
/// `t_sessions(status='active')`). When SQLite raises
/// `SQLITE_CONSTRAINT_UNIQUE` (extended code 2067), the store layer
/// catches the raw `SqliteException` and rewraps it in this domain
/// exception — the domain never sees a `SqliteException` (D4).
///
/// `implements Exception` (not `extends Error`) per CLAUDE.md §Error
/// handling: this is a recoverable race, not a programming bug.
class ConcurrentActivationException implements Exception {
  const ConcurrentActivationException({required this.attemptedId});

  final SessionId attemptedId;

  @override
  String toString() => 'ConcurrentActivationException(attemptedId=${attemptedId.value})';
}

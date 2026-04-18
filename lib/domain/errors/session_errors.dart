// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/session_id.dart';

/// Thrown when a session lookup-by-ID returns no row.
class SessionNotFoundException implements Exception {
  const SessionNotFoundException({required this.id});

  final SessionId id;

  @override
  String toString() => 'SessionNotFoundException(id=${id.value})';
}

/// Thrown when a state-machine transition violates the SESS-* rules
/// (e.g. attempting to stop a session already in `stopped` state).
class InvalidSessionTransition implements Exception {
  const InvalidSessionTransition({required this.id, required this.fromStatus, required this.toStatus});

  final SessionId id;
  final String fromStatus;
  final String toStatus;

  @override
  String toString() => 'InvalidSessionTransition(id=${id.value}, $fromStatus -> $toStatus)';
}

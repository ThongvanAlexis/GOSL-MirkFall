// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:json_annotation/json_annotation.dart';

/// Lifecycle state of a tracking session.
///
/// JSON wire value is the lowercase name (`'active'` / `'stopped'`) so a
/// payload exported by another instance is human-readable and stable across
/// schema bumps.
enum SessionStatus {
  /// Currently active — GPS tracking writes fixes. At most one active session
  /// at a time (SESS-06, DB-enforced via partial unique index on
  /// `t_sessions(status='active')`).
  @JsonValue('active')
  active,

  /// Stopped — immutable afterwards (hard-delete only, no corbeille).
  @JsonValue('stopped')
  stopped,
}

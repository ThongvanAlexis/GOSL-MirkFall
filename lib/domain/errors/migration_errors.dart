// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Thrown by both `JsonMigrator` (this phase) and the future
/// `SchemaSanityChecker` (03-05) when a migration step is missing,
/// duplicated, or the row-count sanity check fails after a Drift
/// `onUpgrade`.
///
/// `reason` is a developer-facing message — migration failures are
/// always logged with the full stack trace, then surfaced to the user
/// with a generic "import a échoué" message (per CLAUDE.md §Error
/// handling: don't expose internals to end-users).
class MigrationFailureException implements Exception {
  const MigrationFailureException({required this.reason});

  final String reason;

  @override
  String toString() => 'MigrationFailureException(reason=$reason)';
}

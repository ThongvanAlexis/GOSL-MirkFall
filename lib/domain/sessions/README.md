# lib/domain/sessions/

Pure-Dart domain layer for tracking sessions. No `package:flutter` /
`package:drift` imports (enforced by `tool/check_domain_purity.dart`).

## Contents

- `session.dart` — Freezed `Session` entity with `@Assert` invariants
  (non-empty `displayName`, `startedAtOffsetMinutes` in `[-720, 840]`).
- `session_status.dart` — `SessionStatus { active, stopped }` enum with JSON
  wire values (`'active'` / `'stopped'`).
- `session_store.dart` — Abstract `SessionStore` port. Implementations live
  in `lib/infrastructure/stores/` (03-06 Drift impl).

## Invariants

- At most one `active` session at a time (SESS-06, DB-enforced via partial
  unique index on `t_sessions(status='active')`; the domain port throws
  `ConcurrentActivationException` when violated).
- `displayName` is non-empty after `trim()`.
- `startedAtOffsetMinutes` covers the IANA TZ range `UTC-12` (`-720`) to
  `UTC+14` (`+840`); values outside this throw `AssertionError` at
  construction.
- Time is carried as `(startedAtUtc: DateTime UTC, startedAtOffsetMinutes:
  int)` so the local wall-clock at session start can be reconstructed even
  after the device moves between time zones (CONTEXT.md §DateTime strategy).

## Phase 03 JSON wire shape

Split fields `(startedAtUtc, startedAtOffsetMinutes)`. A single combined
ISO 8601 `"startedAt"` string for export is deferred to Phase 13
SCHEMA.md finalization.

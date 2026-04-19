# lib/domain/fixes/

Pure-Dart domain layer for GPS fixes recorded during a session. No
`package:flutter` / `package:drift` imports (enforced by
`tool/check_domain_purity.dart`).

## Contents

- `fix.dart` — Freezed `Fix` entity with `@Assert` invariants (lat in
  [-90, 90], lon in [-180, 180], accuracy >= 0, offset in [-720, +840]).
- `fix_store.dart` — Abstract `FixStore` port (insert + list + watch +
  count + deleteAll by session). Implementation in
  `lib/infrastructure/stores/drift_fix_store.dart` (Plan 05-01 Task 4).

## Imports

Allowed:
- `package:freezed_annotation/`
- `../ids/` (`FixId`, `SessionId`, `id_json_converters.dart`)

Forbidden (enforced by `tool/check_domain_purity.dart`):
- `package:flutter/`
- `package:drift/` (the store port is platform-agnostic; Drift lives only
  in the infrastructure impl)
- `package:drift_flutter/`

## Invariants

- Every `Fix` belongs to exactly one `Session` (FK `sessionId`).
- `accuracyMeters` ≥ 0 — negative values are nonsensical for a GPS fix.
- UTC-offset range mirrors the IANA TZ range (UTC-12 to UTC+14) —
  identical to `Session.startedAtOffsetMinutes`.

## Phase 05 JSON wire shape

Split fields `(recordedAtUtc: DateTime, recordedAtOffsetMinutes: int)`,
same shape as `Session.startedAt{Utc,OffsetMinutes}`. Phase 13
SCHEMA.md finalization will decide whether to collapse them into a
combined ISO 8601 string for export readability.

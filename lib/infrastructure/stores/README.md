# lib/infrastructure/stores/

Drift-backed implementations of the six domain store ports declared in
`lib/domain/<subsystem>/<entity>_store.dart`. Each class `implements` its
port verbatim — no widening, no narrowing, no extra public methods.

## Files

- `drift_session_store.dart` — [SessionStore] impl. SESS-06 runtime gate.
- `drift_marker_store.dart` — [MarkerStore] impl. Photos list intentionally
  empty in Phase 03 (see class docstring; filled by Phase 11).
- `drift_marker_category_store.dart` — [MarkerCategoryStore] impl. Enforces
  the non-CASCADE reassign-to-default policy + protects `kCategoryDefaultId`.
- `drift_mirk_style_store.dart` — [MirkStyleStore] impl. Maintains the
  denormalized `renderer_type` column consistent with
  `config.rendererType`.
- `drift_revealed_tile_store.dart` — [RevealedTileStore] impl. MIRK-03
  transactional OR-monotone `mergeMask`.
- `sqlite_error_mapper.dart` — shared constants
  (`kSqliteConstraintUnique = 2067`, `kSqliteConstraintForeignKey = 787`).

Photo store impl (`FilesystemPhotoStore`) is intentionally NOT shipped in
Phase 03 — it lands in Phase 11 together with the filesystem photo
pipeline.

## SqliteException wrapping policy

Stores catch raw `SqliteException` only where a specific extended result
code maps to a domain exception. At the time of writing, that is exactly
one site:

- `DriftSessionStore.activate` wraps `extendedResultCode == 2067`
  (`SQLITE_CONSTRAINT_UNIQUE`) into `ConcurrentActivationException` —
  SESS-06 enforcement raised by the partial unique index
  `idx_t_sessions_status_active`.

Every other `SqliteException` code is **rethrown unchanged** (FK
violations, DISK_IO, BUSY, SCHEMA, etc.) per RESEARCH §pitfall #4: wide
catches mask unrelated bugs. Callers above the store layer treat raw
`SqliteException` as a programming error — the top-level
`runZonedGuarded` handler logs the stack trace (CLAUDE.md §Error
handling, Level 1).

## Transaction boundaries

- `DriftRevealedTileStore.mergeMask` wraps `SELECT + INSERT-or-UPDATE` in
  `_db.transaction(() async { ... })` — MIRK-03 atomicity guarantee.
- `DriftMarkerCategoryStore.delete` wraps `UPDATE t_markers ... + DELETE
  FROM t_marker_categories` in a single transaction — no window where
  orphan markers reference a non-existent category.

All other methods are single statements; Drift's default auto-commit is
sufficient.

## Hydration helpers

`_hydrate(<Row>)` and `_toInsertCompanion(<Entity>)` are private per
store. Row → entity shape conversions never leak outside the store; the
port returns the domain entity type (pure-Dart, Flutter/Drift-free).

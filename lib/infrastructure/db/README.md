# lib/infrastructure/db

Drift-backed persistence for MirkFall. Owns the schema, pragma wiring, and
migration framework. Store implementations (DriftSessionStore, etc.) live in
`lib/infrastructure/stores/` (plan 03-06) and import from here.

## Tables (6)

| Table | Purpose | FK policy |
|-------|---------|-----------|
| `t_sessions` | Tracking sessions. SESS-06 partial unique index on `status='active'`. | (parent table) |
| `t_marker_categories` | User-defined marker taxonomies. `cat_default` sentinel seeded 03-06. | (parent table) |
| `t_markers` | Points of interest. | `session_id` CASCADE, `category_id` NO cascade (reassigned in tx) |
| `t_revealed_tiles` | MIRK-03 storage: 512-byte bitmap per parent tile. Composite unique key. | `session_id` CASCADE |
| `t_mirk_styles` | Renderer configurations. `config` is JSON TEXT. | (independent) |
| `t_photos` | Photo attachments. | `marker_id` CASCADE |

## Pragma order (RESEARCH §Pattern 1)

1. **`setup:`** callback of `NativeDatabase.memory` / `createInBackground`
   runs `PRAGMA journal_mode = WAL` on the raw sqlite3 handle BEFORE Drift's
   first query (pitfall #2 — journal mode reads lock the mode, so WAL must
   be set first).
2. **`beforeOpen`** of `MigrationStrategy` calls [`applyRuntimePragmas`] to
   set `synchronous = NORMAL`, `busy_timeout = kDbBusyTimeoutMs`, and
   `foreign_keys = ON` on every cold + warm open.

`foreign_keys = ON` is CRITICAL — default is OFF and silently voids
`ON DELETE CASCADE` declarations (RESEARCH pitfall #1).

## Migration workflow

Schema versions freeze into immutable JSON snapshots under
`drift_schemas/`, produced by `dart run drift_dev schema dump`:

| File | Status |
|------|--------|
| `drift_schema_v1.json` | **Frozen** — shipped in 03-04 Task 1, never rewritten. |
| `drift_schema_v2.json` | **Frozen** — shipped in 03-04 Task 2, never rewritten. |
| `drift_schema_current.json` | **Rolling** — rewritten on every `schemaVersion` bump. CI diff-guards this file only. |

Migration helpers under `test/generated_migrations/` (schema.dart +
schema_v1.dart + schema_v2.dart) are produced by `drift_dev schema generate`
and consumed by SchemaVerifier-backed migration tests in plan 03-05.

V1 -> V2: `ALTER TABLE t_sessions ADD COLUMN notes TEXT` — symbolic fictive
migration (Phase 03 SC#6, proof-of-framework).

## onBeforeUpgrade hook

`AppDatabase` exposes an optional `Future<void> Function(OpeningDetails)?
onBeforeUpgrade` constructor parameter. When set and the upgrade path fires
(`details.hadUpgrade == true`), the hook runs inside `beforeOpen` BEFORE
`onUpgrade` executes. 03-05 wires `DbBackupService.takeBackup` into this
hook so a pre-migration snapshot is on disk before any schema change runs.

`details.hadUpgrade` is only true when `schemaVersion` increased from a
previously-opened version; first-open (`onCreate`) paths do not fire the
hook. This prevents bogus "backup of an empty DB" writes on fresh installs.

# test/fixtures/

Shared fixtures consumed by Phase 03+ tests. Contents are reproducible inputs,
not build artifacts — commit every change.

## Layout

- `json/` — versioned JSON samples for `JsonMigrator` (03-02) and
  `MirkStyleConfig.fromJson` (03-03).
- `db_seed/` — hand-written SQL INSERT scripts seeding `NativeDatabase.memory()`
  in migration + identity tests (03-04, 03-05).

Frozen Drift schema dumps live in the repo root at `drift_schemas/`
(outside `test/fixtures/`), alongside the `lib/infrastructure/db/` source
they mirror. Finding #33 (Batch J) — earlier drafts of this README
pointed to `test/fixtures/drift_schemas/`, which never existed; the
reference is corrected here.

## Conventions

- JSON samples: one file per (`schemaVersion`, `type`) tuple. Filename pattern:
  `<type>_v<schemaVersion>.json` (e.g. `session_v1.json`).
- Envelope shape (D9 — see PROJECT.md Key Decisions):

  ```json
  { "schemaVersion": 1, "type": "session" | "bundle" | "markers_only" | "mirk_style", "payload": { ... } }
  ```

- SQL seeds: INSERT-only, explicit column lists, GOSL header inside an SQL
  comment block at the top of each file.
- Do NOT reference absolute paths from tests — use
  `p.join(Directory.current.path, 'test/fixtures/...')` so the same fixture
  resolves under `dart test` (CWD = repo root) and `flutter test` (same).

## Authoritative schema

The column names used in `db_seed/v1_baseline.sql` are PROPOSED here so
downstream plans (03-02, 03-03) can write fixture-loading helpers against
a stable shape. The AUTHORITATIVE schema is owned by 03-04
(`lib/infrastructure/db/app_database.dart`). If 03-04 lands a different
column name (e.g. `started_at_ms` vs `started_at_utc`), the seed file is
updated there — never silently in a downstream plan.

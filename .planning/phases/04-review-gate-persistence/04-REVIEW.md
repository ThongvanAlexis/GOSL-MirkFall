# Phase 04: Review Gate — Persistence Review

**Opened:** 2026-04-18
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude's audit.*

*Aucune observation utilisateur — l'user n'a pas identifié de point à revoir dans son IDE.*

### 1b. Runtime walk Windows

**Walk driver chosen:** `(a+b)` — both `dart run tool/walk_db.dart` (DB open proof) AND `flutter run -d windows` (UI boot observation)
**Commit hash of app exec'd:** `c142a8c` (HEAD at walk time — walk_db.dart with Option B manual path resolution)
**Executed:** 2026-04-18 ~19:27 local

**DB path resolved:** `C:\Users\oliver\AppData\Roaming\app.gosl\mirkfall\mirkfall.db`

**File sizes after walk (from `dart run tool/walk_db.dart`):**
- `mirkfall.db` — 77824 bytes (exists=true)
- `mirkfall.db-wal` — N/A (exists=false after clean close — see Confirms §3)
- `mirkfall.db-shm` — N/A (exists=false after clean close)

<details>
<summary>Walk (b) — `dart run tool/walk_db.dart` verbatim output</summary>

```
Running build hooks...
DB path: C:\Users\oliver\AppData\Roaming\app.gosl\mirkfall\mirkfall.db
mirkfall.db exists=true size=77824
mirkfall.db-wal exists=false size=N/A
mirkfall.db-shm exists=false size=N/A
```
</details>

<details>
<summary>sqlite3 CLI inspection — `sqlite3 "<PATH>\mirkfall.db" < tool\inspect_db.sql` verbatim output</summary>

```
user_version = 2
journal_mode = wal
foreign_keys = 0
synchronous  = 2
timeout      = 0     (busy_timeout)
page_size    = 4096

CREATE TABLE "t_sessions" (id, display_name, status, started_at_utc, started_at_offset_minutes CHECK BETWEEN -720 AND 840, stopped_at_utc, stopped_at_offset_minutes, notes, PRIMARY KEY (id));
CREATE TABLE "t_marker_categories" (id, display_name, icon_name, created_at_utc, created_at_offset_minutes, PRIMARY KEY (id));
CREATE TABLE "t_markers" (id, session_id REFERENCES t_sessions ON DELETE CASCADE, category_id REFERENCES t_marker_categories, lat, lon, title, notes, created_at_utc, created_at_offset_minutes, PRIMARY KEY (id));
CREATE TABLE "t_revealed_tiles" (id, session_id REFERENCES t_sessions ON DELETE CASCADE, parent_x, parent_y, parent_zoom DEFAULT 14, bitmap BLOB, set_bit_count DEFAULT 0, updated_at_utc, PRIMARY KEY (id), UNIQUE (session_id, parent_x, parent_y, parent_zoom));
CREATE TABLE "t_mirk_styles" (id, display_name, renderer_type, config, created_at_utc, created_at_offset_minutes, PRIMARY KEY (id));
CREATE TABLE "t_photos" (id, marker_id REFERENCES t_markers ON DELETE CASCADE, relative_basename, width_px, height_px, file_size_bytes, created_at_utc, created_at_offset_minutes, PRIMARY KEY (id));

-- Indexes:
CREATE UNIQUE INDEX idx_t_sessions_status_active ON t_sessions (status) WHERE status = 'active';
CREATE INDEX idx_t_markers_session_id ON t_markers (session_id);
CREATE INDEX idx_t_markers_category_id ON t_markers (category_id);
CREATE INDEX idx_t_revealed_tiles_session_id_parent_key ON t_revealed_tiles (session_id, parent_x, parent_y);
CREATE INDEX idx_t_photos_marker_id ON t_photos (marker_id);

.indexes t_sessions: idx_t_sessions_status_active
```
</details>

<details>
<summary>`flutter doctor -v` (toolchain state at walk time)</summary>

```
✓ Flutter 3.41.7 stable, Windows 10.0.19045.6466, Dart 3.11.5
✓ Windows 10 Pro 22H2
✗ Android toolchain — cmdline-tools component is missing, license status unknown
✓ Chrome
✓ Visual Studio Build Tools 2022 17.12.3
✓ 4 connected devices (android emu, Windows desktop, Chrome, Edge)
✓ Network resources
```
</details>

<details>
<summary>Walk (a) — `flutter run -d windows` verbatim output (BLOCKER observed)</summary>

```
Launching lib\main.dart on Windows in debug mode...
Nuget.exe not found, trying to download or use cached version.
Building Windows application...                                    36.5s
✓ Built build\windows\x64\runner\Debug\mirkfall.exe

══╡ EXCEPTION CAUGHT BY FLUTTER FRAMEWORK ╞═══════════════════════
The following assertion was thrown during runApp:
Zone mismatch.
The Flutter bindings were initialized in a different zone than is
now being used. This will likely cause confusion and bugs as any
zone-specific configuration will inconsistently use the configuration
of the original binding initialization zone or this zone based on
hard-to-predict factors such as which zone was active when a
particular callback was set.
It is important to use the same zone when calling `ensureInitialized`
on the binding as when calling `runApp` later.
To make this warning fatal, set BindingBase.debugZoneErrorsAreFatal
to true before the bindings are initialized (i.e. as the first
statement in `void main() { }`).

When the exception was thrown, this was the stack:
#0  BindingBase.debugCheckZone.<anonymous closure> (package:flutter/src/foundation/binding.dart:519:31)
#1  BindingBase.debugCheckZone (package:flutter/src/foundation/binding.dart:525:6)
#2  _runWidget (package:flutter/src/widgets/binding.dart:1680:18)
#3  runApp (package:flutter/src/widgets/binding.dart:1616:3)
#4  main.<anonymous closure> (package:mirkfall/main.dart:71:7)
<asynchronous suspension>
#5  main (package:mirkfall/main.dart:36:3)
<asynchronous suspension>

Lost connection to device.
```

Log file captured the event (FileLogger armed OK, wrote to disk before crash): `C:\Users\oliver\Documents\logs\20260418_1927.32_logs.txt` — two entries: INFO "MirkFall starting — logger armed" + SHOUT FlutterError with full zone-mismatch stack.
</details>

<details>
<summary>`where /r %APPDATA% mirkfall.db` (proves Option B path matches path_provider resolution)</summary>

```
C:\Users\oliver\AppData\Roaming\app.gosl\mirkfall\mirkfall.db
```

Single match — confirms `tool/walk_db.dart`'s manual path construction (`%APPDATA%\app.gosl\mirkfall\`) is byte-identical to what `path_provider_windows` resolves to (CompanyName + ProductName sourced from `windows/runner/Runner.rc`). Walk (a) did NOT create a second DB file (ProviderScope deferral per 03-CONTEXT verified — `buildAppDatabase` never ran in walk (a) because no Riverpod consumer read `appDatabaseProvider`).
</details>

**Confirms:**

1. **`buildAppDatabase` opens the real file-backed DB on Windows** — `mirkfall.db` created at 77824 bytes at the path `path_provider_windows` would resolve (`%APPDATA%\app.gosl\mirkfall\`), end-to-end `SELECT 1` succeeds, clean close.
2. **All 6 Phase 03 tables present** — `t_sessions`, `t_marker_categories`, `t_markers`, `t_revealed_tiles`, `t_mirk_styles`, `t_photos` all emitted by `.schema`. **Note: plan text says `t_photo_refs`, actual table is `t_photos`** — plan-text drift only, no schema bug (see SUMMARY deviations).
3. **WAL was active at DB level** — `PRAGMA journal_mode=wal` persisted in DB header; `.db-wal` + `.db-shm` files absent after walk is benign SQLite clean-shutdown behaviour (checkpoint-and-cleanup merges WAL into main file on clean close of the last connection, SHM gets removed). NOT a WAL-disabled finding.
4. **`idx_t_sessions_status_active` partial unique index present** — SESS-06 DB layer intact (`WHERE status = 'active'`).
5. **`user_version=2`** — schema version matches `AppDatabase.schemaVersion => 2`, V1→V2 migration applied (or new DB created directly at V2 on fresh filesystem).
6. **CAVEAT on 3 per-connection pragmas — NOT authoritative in this walk:** The sqlite3 CLI reports `foreign_keys=0`, `synchronous=2` (FULL), `busy_timeout=0` — but these three pragmas are **per-connection in SQLite**, not persisted to the DB file. The CLI reads its own defaults on `.open`, not what Drift's `applyRuntimePragmas` set in `beforeOpen`. The walk AS DESIGNED cannot confirm Drift applied `foreign_keys=1`, `synchronous=1 NORMAL`, `busy_timeout=5000` at production connection-open. Escalated as `[Should]` finding in §2 — walk-tooling gap, not a pragma bug. (Phase 03 Plan 03-04 unit tests DO verify these three applied in-process via Drift, so the contract itself holds; only the runtime walk's independent verification is incomplete.)
7. **Zone mismatch crash at `runApp`** — `flutter run -d windows` boots the binary successfully (Windows packaging + plugin stack green) but the app crashes IMMEDIATELY at `runApp` with `Zone mismatch` assertion (`main.dart:36` + `:71` stack). Escalated as `[Blocker]` finding in §2. CI does not catch this because unit tests don't exercise real binding init + `runZonedGuarded` together.

**Informational observations (not findings):**
- Android toolchain `cmdline-tools` component missing on dev host — doesn't affect this walk (Windows desktop) or CI (CI uses ubuntu-latest with full SDK). Dev environment gap only.
- Dart CLI toolchain has Google Analytics opt-in default-on at SDK level (not project-code). Does NOT violate CLAUDE.md §Télémétrie because CLAUDE.md scope is dependencies + runtime app code, not the Dart SDK itself.
- `Running build hooks...` line before walk (b) output confirms `build_runner` / native-assets build_hook ran — expected for the Drift-codegen pipeline.
- `tool/inspect_db.sql` uses `--` SQL comment header matching the convention of `test/fixtures/db_seed/v1_baseline.sql`. Header convention for `.sql` files ratified.

## 2. Claude audit findings

*Filled by Plan 04-03: first the 3 pre-classified VERIFICATION candidates, then the 4 parallel sub-agents in ONE tool-use message.*

Format: `[severity] Title — 1-line explanation — file:line`. Severities: Blocker / Should / Could / Noted.

### Pre-known from VERIFICATION

*Filled by Plan 04-03 Task 1 BEFORE spawning sub-agents. Source: `03-VERIFICATION.md §Outstanding minor items`. Committed as `docs(04-rev): pre-class VERIFICATION candidates into §2` before any Agent tool call. The pre-class table deliberately excludes fix decisions — §3 triage decides fix/waive per finding. Runtime-walk findings are already escalated in the `Pre-known from Runtime Walk (§1b)` sub-section below and are NOT duplicated here.*

| #  | Finding                                                                                                                                                                | Severity | Source                                           | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| -- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1 | Flaky `backup_test.dart::rotate keeps the 3 newest when 4 exist` — 1 failure / ~30 runs on Windows parallel full-suite run; reproducible; mtime-ordering fragility   | Blocker  | `03-VERIFICATION.md §Outstanding minor items #1` | When run isolated (`dart test test/infrastructure/db/backup_test.dart`) or scoped to Phase 03 (`dart test test/domain test/infrastructure`) the suite is 100% green. Under full-parallel `dart test` the Windows file-system mtime resolution + concurrent tempdir manipulation race makes the `.rotate` test pick a wrong "newest 3" set. Fix candidate: `Future.delayed(Duration(milliseconds: 10))` between consecutive backup file creations OR sort by filename (contains `_hhmm.ss_` timestamp) rather than mtime. Agent #1 MUST re-verify whether `DbBackupService.rotate` itself (runtime) also depends on `File.lastModifiedSync()` mtime — if YES, ESCALATE P1 to Blocker-runtime + Blocker-test (two entries). |
| P2 | `custom_lint` silently degraded under analyzer-10 (`custom_lint_core` 0.8.1 breaks on analyzer's `Element2` API rename)                                              | Noted    | `03-VERIFICATION.md §Outstanding minor items #2` | `flutter analyze --fatal-infos --fatal-warnings` stays green via the analyzer-10 stack — operational impact = 0. Accept + document explicitly in `STATE.md` Accumulated Decisions (already present for 03-01 reversal) + add a `DEPENDENCIES.md` marker flagging `custom_lint` as "silently-degraded until 0.9.x ships analyzer-10 support". Re-verify at each deps bump and at Phase 15 polish at the latest. Agent #2 MUST run `dart run custom_lint` directly (bypassing `flutter analyze`) to confirm the plugin-load failure is still present; if it now loads successfully, promote to a Could `custom_lint re-enabled`; if it fails differently (new error class), note it. |
| P3 | `computeRevealMask` throws `UnimplementedError` by design (Phase 09 fog rendering scope)                                                                              | Should   | `03-VERIFICATION.md §Outstanding minor items #3` | Phase 09 (MIRK-01..02) owns the geometry kernel; Phase 03 commits only the signature + algebra primitives (`mergeBitmap`, `popcount`). Add a permanent test guard `test/domain/compute_reveal_mask_no_callers_test.dart` scanning `lib/**` + `test/**` for callers outside the single definition site; removed when Phase 09 implements the body. Anti-pattern documented (source-code-scanning test) per CLAUDE.md §Workarounds. Agent #4 MUST additionally search for OTHER `UnimplementedError` throws + flaky Windows-specific tests + analyzer-plugin silent-degrade analogues beyond the 3 pre-classified. |

### Pre-known from Runtime Walk (§1b)

*Filled by Plan 04-02 Task 3 at runtime-walk archival time — these are findings surfaced BY the runtime walk itself, escalated up-front so Plan 04-03 Task 1's pre-class commit can include them before agent spawn. Status at capture: `pending-user-decision` (triage happens in §3 via Plan 04-03 Task 3 or Plan 04-05 fix loop).*

- **[Blocker | Runtime walk | Zone mismatch crashes app at boot on Windows desktop | `lib/main.dart:34,36,71`]** — `flutter run -d windows` builds the binary successfully (36.5s build, `mirkfall.exe` produced) but the Flutter framework throws `Zone mismatch` assertion at `runApp()` and immediately loses connection to the device. `WidgetsFlutterBinding.ensureInitialized()` is called in the root zone (main.dart:34) per a deliberate Phase 01 RESEARCH pitfall workaround, but `runApp(const ProviderScope(...))` is then invoked INSIDE `runZonedGuarded` (main.dart:71) — the binding's message handlers observe a different zone than the one `runApp` runs in, triggering the debug-build-only zone-mismatch assertion. The comment at main.dart:27-33 claims this ordering AVOIDS the pitfall, but Flutter 3.41.7's `debugCheckZone` disagrees in practice. App does NOT boot. Phase 02 visual walk either missed this (ran in release mode?) or CI never caught it (CI doesn't run `flutter run -d windows`, only `flutter build`). Triage status: `pending-user-decision` — likely fix is either (a) move `runApp` outside `runZonedGuarded` while keeping the guarded zone for the async work before it, or (b) move `WidgetsFlutterBinding.ensureInitialized()` INSIDE the guarded zone as the first statement, accepting the original pre-3.10 pitfall as a calculated risk. Decision belongs in §3 and must be resolved BEFORE Phase 05 (where ProviderScope starts having real consumers and this crash becomes blocking for feature work).
- **[Should | Runtime walk | sqlite3 CLI pragmas non-authoritative for 3 per-connection settings | `tool/walk_db.dart` + `tool/inspect_db.sql`]** — The runtime walk reports `foreign_keys=0`, `synchronous=2 FULL`, `busy_timeout=0` from the sqlite3 CLI, but these three PRAGMAs are per-connection in SQLite (not persisted to the DB file — see sqlite.org/pragma.html). Each new `sqlite3 <path>` invocation starts fresh with SQLite's library defaults; Drift's `applyRuntimePragmas` (fired in `beforeOpen`) applies them IN-PROCESS on the Drift connection only. The walk AS DESIGNED cannot independently verify Drift sets these values at production connection-open — only the 3 DB-level pragmas (`user_version`, `journal_mode`, `page_size`) persist across connections and so are reliably observed by the CLI. Phase 03 Plan 03-04 pragma unit tests DO assert these values apply in-process (via Drift's `customSelect('PRAGMA ...')`), so the CONTRACT holds — but the runtime walk's claim to be an independent cross-check on the live filesystem is incomplete. Cheap remediation: extend `tool/walk_db.dart` to print the 5 mandatory PRAGMAs via `db.customSelect('PRAGMA ...').get()` BEFORE `db.close()`, archive that output into §1b as the authoritative reading. ~15 lines added. Triage status: `pending-user-decision` — (fix-now in Phase 04 via 04-05) | (defer to future validation phase) | (waive: rely on Phase 03 in-process unit tests). Decision belongs in §3.

### Agent #1 — Schema + migrations + backup
(pending)

### Agent #2 — Domain models + pureté
(pending)

### Agent #3 — Store layer + factory + providers
(pending)

### Agent #4 — Tests + fixtures + tooling + CLAUDE.md sweep
(pending)

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>
(pending)
</details>

## 3. Triage decisions

*Filled by Plan 04-03 Task 3 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden per CONTEXT.md). Every Should MUST be either `fix` or `waived` with inline rationale.*

| # | Finding | Severity | Decision | Rationale |
|---|---------|----------|----------|-----------|
| (pending) | | | | |

## 4. Adversarial evidence

*Filled by Plan 04-04. Two CI-branch evidence blocks (Tests #1, #2) + one permanent unit-test evidence block (Test #3).*

### Test 1: Domain purity import violation (Flutter + Drift)
*Branch `adversarial/04-domain-import-flutter-and-drift`: one branch, TWO violations. CI step `Check domain purity (lib/domain/ imports)` must fail with exit 1 listing BOTH `lib/domain/sessions/session.dart` (Flutter import) AND `lib/domain/markers/marker.dart` (Drift import).*

(pending)

### Test 2: Drift schema dump stale
*Branch `adversarial/04-schema-drift-stale`: add a column to `t_sessions` in `app_database.dart`, run `build_runner build` (mandatory — otherwise `flutter analyze` fails first per RESEARCH Pitfall 1), do NOT run `drift_dev schema dump`. CI step `Check drift schema (current) is committed and fresh` must fail with `git diff --exit-code` showing stale `drift_schemas/drift_schema_current.json`.*

(pending)

### Test 3: SchemaSanityChecker row-loss detection (permanent unit test)
*NOT a throwaway branch. Permanent test `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` on `main`. Injects V1 fixture (70 rows), runs adversarial migration with `ALTER TABLE` + `DELETE FROM t_sessions WHERE rowid % 2 = 0`, asserts `SchemaSanityChecker.assertNoLoss` throws `MigrationFailureException` with exact row-count diff. Evidence = commit hash + green `dart test` output.*

(pending)

## 5. CI-green confirmation

*Filled by Plan 04-05 Task 2 after all Blocker + non-waived Should fixes are applied and CI is green.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending)
- **Date:** (pending)

---
_Phase 04 closed: (pending)_
_Phase 05 unblocked._

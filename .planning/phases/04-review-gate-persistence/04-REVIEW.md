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

[Blocker] P1 escalation confirmed — `DbBackupService.rotate` architecturally depends on `File.statSync().modified` (mtime) ordering; mtime is fragile on Windows (NTFS 15ms–1s resolution, antivirus/indexer side-effects, parallel-run interleave); dedicated fix owner required: sort by filename-embedded ISO timestamp (deterministic, clock-injected) or monotonic counter suffix — `lib/infrastructure/db/backup.dart:89-90` — Cross-ref: same family as Agent #4 [Should] `backup_test.dart::takeBackup+rotation` Windows-flaky (5ms throttle test-side) — together form the P1 runtime+test escalation

[Blocker] `cat_default` sentinel is never seeded in any migration or `onCreate` — `onCreate: (m) => m.createAll()` has no seed, combined with `drift_marker_category_store.dart:84-92` reassign target; deletes of populated non-default categories throw `SQLITE_CONSTRAINT_FOREIGNKEY` in a fresh DB — `lib/infrastructure/db/app_database.dart:244`

[Should] Docstring inconsistency for `cat_default` seed owner — `app_database.dart:69` claims "seeded by 03-06 migrations"; `lib/domain/ids/default_ids.dart:13-14` says "seeded by Phase 11"; current code seeds in neither — `lib/infrastructure/db/app_database.dart:69`

[Should] Misleading `// ignore: unused_import` on `session_status.dart` — `app_database.g.dart` has zero `SessionStatus` references; import is truly dead — `lib/infrastructure/db/app_database.dart:11-12`

[Should] `t_sessions.status` has no DB-level CHECK constraint — raw SQL `status='garbage'` accepted silently — `lib/infrastructure/db/app_database.dart:42` — Cross-ref: also flagged by Agent #3 cross-lens Noted (same line)

[Should] UTC-offset magic numbers `-720, 840` duplicated across layers — violates CLAUDE.md §Magic numbers — `lib/infrastructure/db/app_database.dart:54`, `lib/domain/sessions/session.dart:38`, `session.freezed.dart:219` — Cross-ref: also flagged by Agent #2 as Noted (compile-time `@Assert` carve-out) and by Agent #4 as [Blocker] (severity disagreement — `lib/config/constants.dart` DOES allow top-level const reference; carve-out argument weak)

[Should] Offset-CHECK asymmetry — only `startedAtOffsetMinutes` has `-720..840` CHECK; `stoppedAtOffsetMinutes` (app_database.dart:57), `createdAtOffsetMinutes` on 4 other tables have no CHECK — `lib/infrastructure/db/app_database.dart:57`

[Should] Zoom default `14` magic number in schema — uses `Constant(14)`; `kRevealedTileParentZoom=14` exists in `lib/config/constants.dart:75` but not referenced — `lib/infrastructure/db/app_database.dart:141` — Cross-ref: also flagged by Agent #4 as [Blocker] (severity disagreement — Agent #1 says Could since schema default is isolated, Agent #4 escalates because two-site duplication with constants.dart third party)

[Should] BLOB `bitmap` size not enforced at DB level — `CHECK(length(bitmap)=512)` would catch paths bypassing the store guard — `lib/infrastructure/db/app_database.dart:142`

[Could] `onBeforeUpgrade` nullable hook is called through `!` — local capture avoids bang — `lib/infrastructure/db/app_database.dart:250`

[Could] Backup filename format lacks strict lex-sort guarantees — `Z` trailing position issue; matters for P1 fix — `lib/infrastructure/db/backup.dart:64-67`

[Could] `SchemaSanityChecker.captureRowCounts` queries tables serially — single `UNION ALL` would collapse round-trips — `lib/infrastructure/db/schema_sanity.dart:45-55`

[Could] `v1_to_v2_notes.dart::apply` uses raw `ALTER TABLE` — portability rationale OK, future rename silently de-syncs — `lib/infrastructure/db/migrations/v1_to_v2_notes.dart`

[Noted] PRAGMA wiring split across 2 sites — correct but no single-source-of-truth docstring — `lib/infrastructure/db/app_database_factory.dart:50-52` + `lib/infrastructure/db/pragma_setup.dart:25-28`

[Noted] `cat_default` docstring + 03-05-SUMMARY.md disagree (Phase 11 vs 03-06 vs may-be-seeded) — `lib/domain/ids/default_ids.dart:13-14`

[Noted] `drift_schema_v2.json == drift_schema_current.json` byte-equal — freshness guardrail green — `drift_schemas/`

[Noted] No composite `(session_id, category_id)` index on `t_markers` — `lib/infrastructure/db/app_database.dart` markers table

[Noted] `SchemaSanityChecker.assertNoLoss` only compares against before-keyset — new migration-added tables never evaluated — `lib/infrastructure/db/schema_sanity.dart`

[Noted] GOSL headers present on all 7 `lib/infrastructure/db/*.dart` + 7 `test/infrastructure/db/*.dart` + migrations — `lib/infrastructure/db/**`

**Adversarial poison verifications (consumed by Plan 04-04):**

**Test #1 `adversarial/04-domain-import-flutter-and-drift`:**
- `lib/domain/sessions/session.dart` exists: YES (1512 bytes, GOSL header present)
- `lib/domain/markers/marker.dart` exists: YES (GOSL header present)
- Imports section stable at top: YES — GOSL header (1-3), `// ignore_for_file` (5-7), imports from line 9. Zero `package:flutter/` or `package:drift` imports across `lib/domain/**`. Grep `-E "^import 'package:(flutter|drift)"` anchored to `lib/domain/` would catch a poison injection at line 9.

**Test #2 `adversarial/04-schema-drift-stale`:**
- `lib/infrastructure/db/app_database.dart` still has `t_sessions`: YES — line 36 `class Sessions extends Table` with `tableName => 't_sessions'` at line 38.
- Column-addition stress point stable: YES — `Sessions` class body spans lines 36-66; clean insertion point at line 63 (before `@override primaryKey` on line 65). The `fixed_sql` block in `drift_schema_v2.json:759` would need regeneration; CI gate fails diff.
- Drift from CONTEXT: no material drift. Minor callout: partial unique index is declared at `app_database.dart:31-35` via `@TableIndex.sql` (multi-line triple-quoted with indentation and trailing `;`). Grep for `idx_t_sessions_status_active` OR `CREATE UNIQUE INDEX idx_t_sessions_status_active` both hit. No adversarial-guardrail impact.

### Agent #2 — Domain models + pureté

[Should] `stoppedAtOffsetMinutes` not bounded — Session asserts startedAt in `[-720, 840]`; nullable sibling has no range assertion — `lib/domain/sessions/session.dart:37-49`

[Should] `Marker.lat` / `Marker.lon` lack range invariants — `TileMath.latLonToTile` silently clamps to Mercator envelope, nonsense coords round-trip — `lib/domain/markers/marker.dart:36-37`

[Should] `RevealedTile.bitmap` length invariant not enforced in entity — store contract says 512 bytes but entity accepts any `Uint8List`; paired with missing `parentZoom==14` / `setBitCount==popcount(bitmap)` / `parentX,Y >= 0` guards, corrupted row round-trips — `lib/domain/revealed/revealed_tile.dart:29-38`

[Should] `Envelope.schemaVersion` accepts any int including negative/zero — `validateOrThrow` only checks `is int`, not `>=1` — `lib/domain/envelope/envelope.dart:52-58`

[Should] `PhotoRef` width/height/fileSize have no positivity invariant — `lib/domain/photos/photo_ref.dart:25-36`

[Could] `IdentityMigrationV1` sentinel `fromVersion: -1` is fragile — future caller passing (-1, 0) silently "migrates" — `lib/domain/envelope/identity_migration_v1.dart:20-26`

[Could] `MirkStyleStore.requireById` / `PhotoStore.requireById` throw unspecified exception — asymmetry with `SessionStore`/`MarkerStore`/`MarkerCategoryStore` — `lib/domain/mirk/mirk_style_store.dart:21-24`, `lib/domain/photos/photo_store.dart:27-30`

[Could] `CategoryId.isValid` returns false for `kCategoryDefaultId` — no affirmative `isReserved` getter — `lib/domain/ids/category_id.dart:11-21`

[Could] `Envelope._payloadFromJson/toJson` take `Map<String, dynamic>` — only undocumented `dynamic` in hand-written domain code — `lib/domain/envelope/envelope.dart:90-98`

[Could] `UnknownConfig.fromJson` silently accepts shapes with nested `'raw'` key — no unit test — `lib/domain/mirk/mirk_style_config.dart:63-67`

[Could] `V1ToV2RenameRadius` drops old key even when new key is already present — edge case, no test — `lib/domain/envelope/v1_to_v2_rename_radius.dart:22-29`

[Could] `computeRevealMask` signature has no bounds validation — even as stub, `radiusMeters<0`/`parentZoom<0`/NaN lat/lon survive — `lib/domain/revealed/reveal_calculator.dart:61-74`

[Noted] `SessionStatus` transitions not encoded in type system — `InvalidSessionTransition` carries raw strings not enum — `lib/domain/errors/session_errors.dart:19-33`

[Noted] `-720`/`840` in `@Assert` string: compile-time carve-out (can't reference `const int` in annotation body) — `lib/domain/sessions/session.dart:38` — Cross-ref: also flagged by Agent #1 as [Should] and Agent #4 as [Blocker] (severity disagreement across three lenses)

[Noted] `Session` uses bare `factory` (not `const factory`) due to method-calling `@Assert` — Phase 03 decision correctly implemented; Marker/MarkerCategory/MirkStyle same; PhotoRef/RevealedTile/Envelope/UnknownConfig use `const factory` correctly — `lib/domain/**`

[Noted] `Envelope.fromJson` is pure arrow redirect — SC#4 respected — `lib/domain/envelope/envelope.dart`

[Noted] Extension-type `@JsonKey` per-field pattern verified — 20+ sites across 5 entities — `lib/domain/**`

[Noted] Zero `flutter/` or `drift/` imports in `lib/domain/**` — SC#2 pureté passes — `lib/domain/**`

[Noted] Sealed `MirkStyleConfig` dispatch via pattern-match — no `is`-chain — `lib/domain/mirk/mirk_style_config.dart`

[Noted] **P2 confirmed unchanged** — `dart run custom_lint` still fails against `analyzer-10.0.1` (same `Element2`, `ErrorCode`, `ErrorType`, `ErrorSeverity`, `ElementKind`, `Annotatable`, `ElementAnnotation`, `libraryElement2`, `resolveFile2` unresolved); P2 stays Noted — source: `dart run custom_lint` at repo root

[Noted] Cross-lens flag for Agent #4: no test asserts `MirkStyleConfig.fromJson` when `rendererType` key is absent + negative-path Envelope.parse for wrong-magnitude schemaVersion — `test/domain/**`

[Noted] Cross-lens flag for Agent #3: `Marker.photos` `@Default(const <PhotoRef>[])` — generated `_Marker` constructor NOT `const` (factory not const due to `.trim()` assert) → every Marker allocates — `lib/domain/markers/marker.dart`

### Agent #3 — Store layer + factory + providers

[Blocker] `activate()` silently succeeds on non-existent/already-stopped sessions — unconditional `UPDATE ... WHERE id=?`, 0 rows affected returns success — `lib/infrastructure/stores/drift_session_store.dart:94-104`

[Blocker] `SqliteException` 2067 wrap scope too narrow — `insert(Session with status=active)` and `update(status=active)` hit the SAME partial unique index but are NOT wrapped; create-and-activate-one-shot or status-replace leaks `SqliteException` to upper layers — `lib/infrastructure/stores/drift_session_store.dart:79-86`

[Should] `mergeMask` transaction can lose race on INSERT branch — two concurrent cold-start mergeMask on same `(sessionId, parentX, parentY)`, both see no existing row, both INSERT, second hits unique key violation uncaught — `lib/infrastructure/stores/drift_revealed_tile_store.dart:76-108` — Cross-ref: also flagged by Agent #4 as [Should] (NativeDatabase.createInBackground escalation — single-connection serialization assumption breaks under background isolate)

[Should] `_idGenerator` injected but unused in `DriftSessionStore` — `// ignore: unused_field` for speculative future insert-without-id path — `lib/infrastructure/stores/drift_session_store.dart:31-35`

[Should] Magic prefix `'rvt_'` duplicates `RevealedTileId.prefix` — `mergeMask` mints `_idGenerator.newId('rvt_')`, typed constant exists — `lib/infrastructure/stores/drift_revealed_tile_store.dart:87`

[Should] `MarkerCategoryStore.delete` uses raw `customStatement` + positional params — inconsistent with typed DSL; `t_markers` rename silently de-syncs — `lib/infrastructure/stores/drift_marker_category_store.dart:85-88`

[Should] Raw `'active'`/`'stopped'` literals bypass `SessionStatusStringConverter` — `findActive`, `activate`, `deactivate` — `lib/infrastructure/stores/drift_session_store.dart:73,97,109`

[Should] `activate`/`deactivate` do not verify session exists or prior state — silent no-op on state transition — `lib/infrastructure/stores/drift_session_store.dart:94-110`

[Should] `session_store_exclusivity_test.dart` does not cover `insert(active)+insert(active)` collision — only `activate()` exercised — `test/infrastructure/stores/session_store_exclusivity_test.dart`

[Should] Marker listing ordered by `createdAtUtc` ASC may not match UX expectation — port docstring says ascending; typical UI shows most-recent first — `lib/infrastructure/stores/drift_marker_store.dart:33`

[Could] `Future<SessionStore>` return type on every provider forces downstream `.future await` virality — `lib/application/providers/*_store_provider.dart`

[Could] `ConcurrentActivationException` carries only `attemptedId` — adding `activeId` improves logs — `lib/domain/errors/concurrent_errors.dart:17-24`

[Could] `CategoryInUseException` branch computes `markerCount` even when unused — wasteful COUNT(*) — `lib/infrastructure/stores/drift_marker_category_store.dart:73-83`

[Could] `DriftMirkStyleStore.requireById` throws `StateError` — inconsistent with `NotFoundException` pattern — `lib/infrastructure/stores/drift_mirk_style_store.dart:49`

[Could] `Ulid._encodeRandom` pad/truncate defense is unreachable given fixed 10→16 ratio — documented future-proof but silent — `lib/infrastructure/ids/ulid.dart:84-90`

[Could] `_newDb` helper duplicated across 6 store test files — `test/infrastructure/stores/*.dart`

[Noted] `ref.onDispose(() async { await db.close(); })` wraps close in unnecessary async closure — `lib/application/providers/app_database_provider.dart:48-50`

[Noted] `_statusConv` static const declared in `DriftSessionStore` but bypassed on `activate`/`deactivate` string-literal paths — `lib/infrastructure/stores/drift_session_store.dart:37-38`

[Noted] `listBySession` orders by `(parentX, parentY)` but composite unique key includes `parentZoom` — single zoom today per D3 — `lib/infrastructure/stores/drift_revealed_tile_store.dart:37-42`

[Noted] Marker-category cascade test doesn't assert `customStatement` reassign ran in same transaction — end-state consistency only — `test/infrastructure/stores/marker_category_store_cascade_test.dart:169-183`

[Noted] 7 providers `keepAlive=true` — `ProviderContainer().dispose()` is only teardown path; README note would help — `lib/application/providers/*.dart`

[Noted] Photo-join deferral makes `Marker.photos` always `[]` — loud `UnimplementedError` at hydration site better than silent empty list — `lib/infrastructure/stores/drift_marker_store.dart:70-82` — Cross-ref: also flagged by Agent #2 as cross-lens concern (every Marker allocates because `_Marker` constructor not `const`)

[Noted] `RandomIdGenerator` accepts optional `Random` — `SeededIdGenerator` nearly redundant — `lib/infrastructure/ids/random_id_generator.dart:17` vs `lib/infrastructure/ids/seeded_id_generator.dart`

[Noted] Cross-lens for Agent #1: `t_sessions.status` no CHECK + `-720/840` literal — `lib/infrastructure/db/app_database.dart:42,54` — Cross-ref: already flagged by Agent #1 as [Should] (both)

### Agent #4 — Tests + fixtures + tooling + CLAUDE.md sweep

[Blocker] Magic `parentZoom` default `14` duplicated outside `constants.dart` — `kRevealedTileParentZoom=14` exists in constants.dart but NOT referenced; both sites hardcode — `lib/infrastructure/db/app_database.dart:141` (`withDefault(const Constant(14))`) + `lib/domain/revealed/revealed_tile.dart:34` (`@Default(14) int parentZoom`) — Cross-ref: also flagged by Agent #1 as [Should] (severity disagreement — Agent #1 says Could/Should since schema default is isolated, Agent #4 escalates because two-site duplication with constants.dart third party violates CLAUDE.md §Magic numbers strictly)

[Blocker] `v1_identity_fixture_test.dart` uses `SchemaVerifier` but is NOT tagged `@Tags(['migration'])` — defeats dart_test.yaml tag discipline; pollutes fast path — `test/infrastructure/db/v1_identity_fixture_test.dart:1-13`

[Blocker] UTC-offset bounds `-720`/`840` duplicated in 4 places — `lib/domain/sessions/session.dart:38` (@Assert), `lib/infrastructure/db/app_database.dart:54` (.check), `test/domain/session_invariants_test.dart:39,46,51-54`; tightening or adding Nepal UTC+5:45 = 4 hunt sites — Cross-ref: also flagged by Agent #1 as [Should] and Agent #2 as [Noted] (severity disagreement — Agent #2 argues `@Assert` can't reference `const int`, Agent #4 argues `lib/config/constants.dart` DOES allow top-level const via plain Dart reference and carve-out argument is weak)

[Should] `pubspec_pinned_test.dart` skips `dependency_overrides:` — test scans only `dependencies:` + `dev_dependencies:`; won't catch drift in overrides — `test/pubspec_pinned_test.dart:22-23`

[Should] `backup_test.dart::takeBackup+rotation` Windows-flaky (same family as P1) — 5 backups 5ms apart; filename carries ISO millisecond precision; QueryPerformanceCounter VM jitter → same-millisecond collision — `test/infrastructure/db/backup_test.dart:130-144` — Cross-ref: same family as Agent #1 [Blocker] P1 runtime escalation and pre-class P1

[Should] Fixture `db_seed` loader's naive SQL split on `;` fragile — strips line comments but NOT block comments `/* ... */` — `test/infrastructure/db/v1_identity_fixture_test.dart:40-54` + `test/infrastructure/db/migration_v1_to_v2_test.dart:119-134`

[Should] `tool/check_domain_purity.dart` regex missing `package:drift_flutter/` — `drift_flutter` pulls `package:flutter/material.dart` transitively and exposes `driftDatabase(...)`; import slip past gate — `tool/check_domain_purity.dart:37-39`

[Should] `DriftRevealedTileStore.mergeMask` SELECT→INSERT race under `NativeDatabase.createInBackground` — in-process transaction serializes on single-connection, but factory doc says "can switch to createInBackground"; under background isolate, race no longer atomic; blind switch in Phase 05 reintroduces UNIQUE CONSTRAINT violation — `lib/infrastructure/stores/drift_revealed_tile_store.dart:76-108` + `lib/infrastructure/db/app_database_factory.dart:41-47` — Cross-ref: also flagged by Agent #3 as [Should] (cold-start race on same code path)

[Should] `test/fixtures/README.md` documents non-existent `drift_schemas/` sub-dir — README says `test/fixtures/drift_schemas/`; actual is repo-root `drift_schemas/` — `test/fixtures/README.md:11-13`

[Could] ULID body length `26` duplicated in 6 ID `.isValid` getters — `lib/domain/ids/category_id.dart:20`, `session_id.dart:20`, `mirk_style_id.dart:15`, `photo_ref_id.dart:15`, `revealed_tile_id.dart:15`, `marker_id.dart:15`

[Could] `seeded_id_generator_test.dart` asserts lengths `31`/`30` without naming — `test/infrastructure/ids/seeded_id_generator_test.dart:27,43`

[Could] `constants_test.dart` never asserts any Phase 03 constant — only Phase 01 — `test/constants_test.dart`

[Could] `tool/check_dependencies_md.dart` doesn't verify "no duplicate rows per package" — `declared[name]=version` clobbers — `tool/check_dependencies_md.dart:88`

[Could] `pubspec.yaml:88-95` pins `test: 1.30.0` against `flutter_test`-bundled version — future SDK bump transitively upgrades `test` → resolver silent absorption — `pubspec.yaml:88-95`

[Noted] `custom_lint.log` (29KB stack traces) in working tree — gitignored but evidence P2 actively generates noise, not just theoretical — `custom_lint.log`

[Noted] `DriftRevealedTileStore` uses `_idGenerator` actively; `DriftSessionStore` uses `// ignore: unused_field` — inconsistency — `lib/infrastructure/stores/drift_session_store.dart` vs `lib/infrastructure/stores/drift_revealed_tile_store.dart`

[Noted] `ImportValidationException`/`MigrationFailureException` use `reason` not `message` — Dart convention favors `message` for log-parsing ease — `lib/domain/errors/**`

[Noted] `NativeDatabase.memory` in tests sets `PRAGMA journal_mode=WAL` but in-memory backend IGNORES WAL (returns `memory`) — cargo-culted across 7 test files; only `app_database_pragma_test.dart:46-58` documents the no-op; others should remove or explain — `test/infrastructure/db/*.dart`

[Noted] Additional investigation: no additional `UnimplementedError` throws beyond P3 (`reveal_calculator.dart:69`) — `lib/**`

[Noted] Additional investigation: flaky Windows test candidates beyond P1 — `session_store_exclusivity_test.dart:101-132` (concurrent activation relies on NativeDatabase.memory single-connection serialization; fragile if executor swapped), `file_logger_test.dart:75-76` + `file_logger_prune_test.dart` (Phase 01 `Future<void>.delayed` async drain), `backup_on_upgrade_test.dart:39-44` (tearDown swallows `FileSystemException` on Windows) — `test/infrastructure/stores/` + `test/`

[Noted] Additional investigation: no analyzer-plugin silent-degrade analogues beyond P2 in `analysis_options.yaml`; adjacent risk: `tool/check_*.dart` scripts fail silently on pubspec shape drift (section rename invisible) — `analysis_options.yaml` + `tool/check_*.dart`

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>

#### Agent #1 Narrative

Schema-and-migration surface is well-organized. Drift 2.30 partial-index patterns used correctly. V1→V2 notes migration + verifier round-trip test is a model of "exercise the framework." `SchemaSanityChecker` correctly targets RESEARCH pitfall #7.

P1 (flaky rotate) escalates: core issue is architectural, not test-harness quirk. `File.statSync().modified` is the sort key in production — Windows mtime granularity + antivirus side effects make unstable sort non-deterministic retention. Fix must live in production code (filename-based ordering via ISO-8601-hyphenated segment, w/ strict lex-sortability guarantee).

The unseeded `cat_default` Blocker is latent: schema's FK asymmetry (markers cascade on session delete but reassign-on-category-delete) creates implicit contract that `cat_default` must pre-exist. No one seeds it.

P5 adjacency: production code applies 4 pragmas correctly (WAL via `setup:`, synchronous/busy_timeout/FK via `applyRuntimePragmas` in `beforeOpen`). `app_database_pragma_test.dart` verifies via Drift's `customSelect('PRAGMA ...')` — IS authoritative. P5 concerns CLI-based walk assertion, which opens its own connection. Recommend replacing CLI pragma checks with Drift-instance `customSelect` probe in any future walk.

`SessionStatus` converter is quirky: declared but not column-bound; applied manually in `drift_session_store.dart`. The `ignore: unused_import` is factually wrong.

#### Agent #2 Narrative

Domain layer solid: zero `flutter/`/`drift/` imports, generated code pure-Dart, extension-type IDs correctly wired, `@Assert`/`const factory` distinction handled across all entities. Sealed dispatch works via Freezed 3.2.3 `unionKey + fallbackUnion`. `Envelope.fromJson` arrow-redirect preserved.

10 test files exercise: Session invariants boundary cases, JSON round-trip across UTC offsets, MirkStyleConfig known/unknown/missing rendererType, JsonMigrator chain behavior, Envelope.fromJson round-trip, TileMath slippy conversions + polar clamping, mergeBitmap algebra (idempotence/commutativity/monotonicity/length mismatch/512-byte) and popcount. Real assertions, not placebo.

Main gap: invariant-robustness coverage for non-id fields (lat/lon, bitmap length, photo dimensions, stoppedAtOffset range). All 5 [Should] findings share same shape: entity deliberately refuses to duplicate DB-level validation, but DB also has no constraint.

`custom_lint` raw output (P2 verification): run `dart run custom_lint` at repo root. Plugin fails to build against analyzer-10.0.1, exit non-zero. Root cause unchanged: `custom_lint_core 0.8.1` was built against pre-Element2 API. Cascade: `Annotatable`, `Element2`, `ElementAnnotation`, `ElementKind`, `libraryElement2`, `resolveFile2` all unresolved across `type_checker.dart`, `lint_codes.dart`, `assist.dart`, `fixes.dart`. P2 stays Noted.

Latent regression risk: per-field `@JsonKey` spread across ~20 call sites. Missing one = json_serializable emits garbage. Custom-lint was the enforcement tool; non-functional → guardrail relies on code review + round-trip test reactive. Agent #4 concern.

#### Agent #3 Narrative

Structural shape good: narrow public methods in pure domain types, no Drift Companion/DataClass leakage. GOSL headers present on all audited files. Line lengths well under 160. All providers `keepAlive=true` with documented rationale.

Main concern — activate path fragility: SqliteException 2067 wrap is a single site (`activate`), but SESS-06 is ALSO enforceable via `insert(status=active)` and `update(status=active)`. The "domain never sees SqliteException" invariant structurally not upheld at other write paths. Either port contract says "insert/update with active is UB" OR those paths must also wrap 2067. Also: `activate()` silently succeeds on nonexistent — should throw.

mergeMask: concurrent test exercises UPDATE branch (both futures hit same existing row). Cold-start race (both SELECT branch, both INSERT) not tested — Drift single-writer queue may save in practice but contract not explicit.

MarkerCategoryStore.delete reassign: correct but stylistically inconsistent. customStatement string literals vs typed DSL. Refactor target must search SQL strings too.

IdGenerator asymmetry: Session + RevealedTile get it; Marker/MarkerCategory/MirkStyle don't. RevealedTile need genuine (mergeMask INSERT branch mints rvt_ IDs); Session need speculative (unused_field lint suppression + test wiring overhead).

Extension-type ID usage: clean across every store. MarkerRow.sessionId raw String correctly wrapped into SessionId() at hydration.

Tests: solid SESS-06, MIRK-03, concurrent merges, error-mapping scope, exclusivity. Missing: insert(active) collision, activate(nonExistent), cold-start mergeMask race. `_newDb` duplicated 6x.

ULID: correct, k-sortable, Crockford. Pad/truncate branch unreachable given 10×8/5=16; `assert(encoded.length == 16)` would make drift loud.

#### Agent #4 Narrative

Test coverage depth: genuine assertions not placebos. Real DB state, real fixtures, real cascade/exclusivity/error-mapping/idempotence coverage. `v1_baseline.sql` = 68 non-comment INSERTs (70 rows counting VALUES rows — matches plan spec).

Tooling: `check_domain_purity.dart` + test cover exit codes 0/1/2. Generated file exclusion works for `.g.dart`/`.freezed.dart`. Only gap: regex fallback missing `drift_flutter`.

Pubspec discipline: all direct deps exact-pinned. `dependency_overrides` uses `analyzer: ^10.0.0` (caret — rationale acceptable per spec as override narrows range) + `dart_style: 3.1.7` (exact). pubspec.lock committed.

DEPENDENCIES.md discipline: every Phase 03 addition has license + telemetry audit + "No network" + audit date. GOSL-compatible licenses (MIT/BSD-3/Apache-2.0). 2026-04-18 json_annotation 4.11.0 bump documented.

Analyzer plugin degrade (P2): confirmed by custom_lint.log. No other analyzer plugin → no analogues. But risk: commented-out `plugins: - custom_lint` block is the ONLY record it's disabled. Someone uncommenting without dropping `analyzer: ^10.0.0` override = silent degrade re-enabled. No guard.

UnimplementedError scan: 1 site — `reveal_calculator.dart:69` (= P3). Matching test `reveal_calculator_test.dart:122` asserts throw. No additional placeholders.

Naming conventions: clean. `xxxs` for lists (markers, sessions, photos), singulars for values, no stale `valueByKey` or `xxxSet`. Path naming: `dbFilename` absolute throughout (matches convention), `backupBasename` filename w/ ext (matches `xxxBasename`), `backupFilename` joined absolute (matches `xxxFilename`). Good discipline.

GOSL headers: 68 hand-written `lib/` + 31 hand-written `test/` + 9 `tool/` all carry header. Generated files correctly exempt.

Additional investigation results:
- UnimplementedError throws beyond P3: None. Only `reveal_calculator.dart:69` (= P3).
- Flaky Windows test candidates beyond P1: `backup_test.dart:130-144` (consecutive takeBackup+rotation, same family as P1), `backup_test.dart:75-91` (P1 itself), `session_store_exclusivity_test.dart:101-132` (concurrent activation relies on NativeDatabase.memory single-connection serialization; fragile if executor swapped), `file_logger_test.dart:75-76` + `file_logger_prune_test.dart` (Phase 01 `Future<void>.delayed` async drain; Windows scheduling jitter; same anti-pattern), `backup_on_upgrade_test.dart:39-44` (tearDown swallows `FileSystemException` on Windows; leaves artifacts).
- Analyzer plugin silent-degrade analogues beyond P2: None in analysis_options.yaml. Adjacent risk: `tool/check_*.dart` scripts fail silently on pubspec shape drift (e.g., section rename to `## Runtime dependencies` invisible — not analyzer-plugin but same "silent-because-nothing-scanned" mode).

</details>

## 3. Triage decisions

*Filled by Plan 04-03 Task 3 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden per CONTEXT.md). Every Should MUST be either `fix` or `waived` with inline rationale.*

**User decision (2026-04-18):** blanket-approve — `let's fix blocker and should`. Interpretation:
- All **Blockers** → `fix` (mandatory; waiver forbidden per CONTEXT.md)
- All **Shoulds** → `fix`
- All **Coulds** → `defer` (revisit at next natural stopping point — Phase 15 polish at latest)
- All **Noted** → `noted` (observation only; no action)

Severity disagreements (findings #5, #7) collapse to `fix` because Shoulds are also fixed under blanket approval — the higher-severity lens prevails but the action is identical. Paired findings (P1 + #1, #20 + #32) collapse to a single architectural fix.

### Blockers (all → fix; 9 findings: 2 pre-class + 7 from Agent #1/#3/#4)

| #  | Finding                                                                                               | Severity                  | Decision | Rationale / Target                                                                                                                                                                                                       |
| -- | ----------------------------------------------------------------------------------------------------- | ------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| P1 | Flaky `backup_test.dart::rotate` on Windows parallel; mtime-ordering fragility                        | Blocker (pre-class)       | fix (done 72da162) | Paired with Agent #1 Blocker #1 (runtime mtime dependency). Single architectural fix: sort by filename-embedded ISO timestamp (deterministic, clock-injected) with strict lex-sortability guarantee (fix `Z` trailing position per Could #35). Test stabilizes as side effect of production fix. |
| P4 | Zone mismatch crashes app at `runApp` on `flutter run -d windows`                                     | Blocker (pre-class walk)  | fix      | `WidgetsFlutterBinding.ensureInitialized()` must run inside `runZonedGuarded` zone (or `runApp` must run outside it). Edit target: `lib/main.dart:34,36,71`. Fix + re-walk in Plan 04-05 to verify boot.                   |
| 1  | `DbBackupService.rotate` architecturally mtime-dependent (`File.statSync().modified`)                 | Blocker (Agent #1)        | fix (done 72da162) | Paired with P1. Same single fix: sort by filename-embedded ISO timestamp in production code (`lib/infrastructure/db/backup.dart:89-90`). Guarantees P1 test stabilizes.                                                    |
| 2  | `cat_default` sentinel never seeded in any migration or `onCreate`                                    | Blocker (Agent #1)        | fix (done 2e528df) | Seed in `onCreate` migration in `app_database.dart:244`, with corresponding row added to `test/fixtures/db_seed/v1_baseline.sql`. Closes the latent FK contract (reassign-on-category-delete requires `cat_default` to pre-exist). |
| 3  | `activate()` silently succeeds on non-existent/already-stopped sessions                               | Blocker (Agent #3)        | fix (done 6425889) | Throw `SessionNotFoundException` when `UPDATE ... WHERE id=?` returns 0 rows affected in `drift_session_store.dart:94-104`. Silent no-op is an invariant violation.                                                         |
| 4  | `SqliteException 2067` wrap scope too narrow — `insert()`/`update()` paths leak raw exception         | Blocker (Agent #3)        | fix (done 6425889) | Extend SqliteException 2067 → ConcurrentActivationException wrap to `insert(Session with status=active)` + `update(status=active)` paths in `drift_session_store.dart:79-86`. Upper-layer contract "never sees SqliteException" must hold at all 3 write sites. |
| 5  | Magic `parentZoom=14` duplicated across schema + domain                                                | Blocker (Agent #4) / Should (Agent #1) | fix (done 54313ce) | Severity disagreement collapsed to `fix`. Replace both sites with `kRevealedTileParentZoom` reference: `lib/infrastructure/db/app_database.dart:141` (`withDefault(Constant(kRevealedTileParentZoom))`) + `lib/domain/revealed/revealed_tile.dart:34` (`@Default(kRevealedTileParentZoom)`).           |
| 6  | `v1_identity_fixture_test.dart` missing `@Tags(['migration'])`                                        | Blocker (Agent #4)        | fix      | Add `@Tags(['migration'])` annotation to `test/infrastructure/db/v1_identity_fixture_test.dart:1-13`. Restores dart_test.yaml tag discipline; moves slow test off fast path.                                                |
| 7  | UTC-offset bounds `-720/840` duplicated 4× across layers                                              | Blocker (Agent #4) / Should (Agent #1) / Noted (Agent #2) | fix (done 74f1bb2) | 3-lens severity disagreement collapsed to `fix`. Extract `kMinUtcOffsetMinutes=-720` + `kMaxUtcOffsetMinutes=840` to `lib/config/constants.dart`. Reference from `session.dart:38` (@Assert), `app_database.dart:54` (.check), `test/domain/session_invariants_test.dart:39,46,51-54`. Agent #2's compile-time-carve-out concern partly valid (string @Assert can't interpolate `const int`) — mitigate by asserting against the two explicit numeric bounds in the @Assert string AND adding a separate test-level guard referencing `kMin/MaxUtcOffsetMinutes`. |

### Shoulds (all → fix; 27 findings: 1 pre-class + 26 from agents)

| #   | Finding                                                                                                                | Severity                  | Decision | Rationale / Target                                                                                                                                      |
| --- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P3  | `computeRevealMask` throws `UnimplementedError` (Phase 09 scope)                                                       | Should (pre-class)        | fix      | Add permanent regression guard `test/domain/compute_reveal_mask_no_callers_test.dart` scanning `lib/**`+`test/**` for callers outside the definition site. Anti-pattern (source-scanning test) documented per CLAUDE.md §Workarounds. Removed when Phase 09 implements. |
| P5  | sqlite3 CLI pragmas non-authoritative for 3 per-connection settings                                                    | Should (pre-class walk)   | fix      | Extend `tool/walk_db.dart` to probe Drift-side pragmas via `db.customSelect('PRAGMA ...').get()` BEFORE `db.close()`, archive those authoritative readings. ~15 lines added. Closes the walk-tooling gap.                        |
| 8   | `cat_default` docstring inconsistency (`app_database.dart:69` vs `default_ids.dart:13-14` vs 03-05-SUMMARY)             | Should (Agent #1)         | fix (done 2e528df) | Single source of truth in `app_database.dart:69` after #2 seeds in `onCreate`. Update `default_ids.dart:13-14` to match ("seeded by `onCreate` migration" or similar). |
| 9   | Misleading `// ignore: unused_import SessionStatus` in `app_database.dart`                                             | Should (Agent #1)         | fix (done 6425889) | Remove dead import. `app_database.g.dart` has zero `SessionStatus` references; `ignore` comment is factually wrong.                                      |
| 10  | `t_sessions.status` has no DB-level CHECK constraint                                                                   | Should (Agent #1 + cross-lens Noted Agent #3) | fix (done b042a1c) | Add `CHECK(status IN ('active','stopped'))` to `app_database.dart:42`. Defense-in-depth for the `SessionStatusStringConverter` contract.                      |
| 11  | UTC-offset `-720/840` duplicated (dup of #7)                                                                           | Should                    | fix (done 74f1bb2) | Covered by #7 fix.                                                                                                                                       |
| 12  | Offset-CHECK asymmetry — only `startedAtOffsetMinutes` has bounds; 5 other offset columns have none                    | Should (Agent #1)         | fix (done b042a1c) | Extend `-720..840` CHECK (via new `kMin/MaxUtcOffsetMinutes` from #7) to `stoppedAtOffsetMinutes` (`app_database.dart:57`) + 4 `createdAtOffsetMinutes` columns. |
| 13  | Zoom `14` magic in schema (dup of #5)                                                                                  | Should                    | fix (done 54313ce) | Covered by #5 fix.                                                                                                                                       |
| 14  | BLOB `bitmap` size not enforced at DB level                                                                            | Should (Agent #1)         | fix (done b042a1c) | Add `CHECK(length(bitmap) = 512)` to `app_database.dart:142`. Defense-in-depth for the store-guard 512-byte invariant.                                   |
| 15  | `stoppedAtOffsetMinutes` not bounded in Session entity                                                                 | Should (Agent #2)         | fix (done 82a0ee7) | Add `@Assert` range check in `session.dart:37-49` using `kMin/MaxUtcOffsetMinutes` from #7. Parity with `startedAtOffsetMinutes`.                         |
| 16  | `Marker.lat`/`Marker.lon` lack range invariants                                                                        | Should (Agent #2)         | fix (done 82a0ee7) | Add `@Assert('lat >= -90 && lat <= 90')` + `@Assert('lon >= -180 && lon <= 180')` to `marker.dart:36-37`. Defense against nonsense coords round-tripping. |
| 17  | `RevealedTile.bitmap` length + `parentZoom==14` + `setBitCount==popcount(bitmap)` + `parentX/Y>=0` invariants not entity-enforced | Should (Agent #2)   | fix (done 82a0ee7) | Add `@Assert` guards to `revealed_tile.dart:29-38`. Entity-level defense mirrors DB CHECK (from #14) + uses `kRevealedTileParentZoom` (from #5).           |
| 18  | `Envelope.schemaVersion` accepts negative/zero                                                                         | Should (Agent #2)         | fix (done 82a0ee7) | Extend `validateOrThrow` in `envelope.dart:52-58` to check `schemaVersion >= 1`.                                                                          |
| 19  | `PhotoRef` width/height/fileSize have no positivity invariant                                                          | Should (Agent #2)         | fix (done 82a0ee7) | Add `@Assert('widthPx > 0')` + `@Assert('heightPx > 0')` + `@Assert('fileSizeBytes > 0')` to `photo_ref.dart:25-36`.                                      |
| 20  | `mergeMask` transaction can lose cold-start INSERT race                                                                | Should (Agent #3 + Agent #4 cross-lens) | fix (done daed232) | Single fix covers both cross-lens flags. Use `INSERT OR IGNORE` + SELECT-retry, OR wrap in explicit `SERIALIZABLE` transaction pattern in `drift_revealed_tile_store.dart:76-108`. Guards against both cold-start race AND hypothetical future `createInBackground` isolate-swap. |
| 21  | `_idGenerator` unused in `DriftSessionStore`                                                                           | Should (Agent #3)         | fix (done 6425889) | Drop the field + constructor param in `drift_session_store.dart:31-35`. Remove the `// ignore: unused_field`. If future need emerges (insert-without-id path), add it back then.                                                |
| 22  | Magic prefix `'rvt_'` duplicates `RevealedTileId.prefix`                                                               | Should (Agent #3)         | fix (done 6425889) | Use `RevealedTileId.prefix` constant in `drift_revealed_tile_store.dart:87`.                                                                              |
| 23  | `MarkerCategoryStore.delete` uses raw `customStatement` + positional params                                            | Should (Agent #3)         | fix      | Switch to typed DSL in `drift_marker_category_store.dart:85-88`: `_db.update(_db.markers)..where(...).write(MarkersCompanion(categoryId: Value(kCategoryDefaultId)))`. Survives table rename.                          |
| 24  | Raw `'active'`/`'stopped'` literals bypass `SessionStatusStringConverter`                                              | Should (Agent #3)         | fix (done 6425889) | Use `_statusConv.toSql(SessionStatus.active)` / `.stopped` at 3 sites in `drift_session_store.dart:73,97,109`.                                             |
| 25  | `activate`/`deactivate` do not verify session state                                                                    | Should (Agent #3)         | fix (done 6425889) | Paired with #3. Throw on 0 rows affected in `drift_session_store.dart:94-110` for both.                                                                   |
| 26  | `session_store_exclusivity_test.dart` missing `insert(active)+insert(active)` collision case                           | Should (Agent #3)         | fix (done 6425889) | Add test case exercising the second insert path to `session_store_exclusivity_test.dart`. Paired with #4 — validates extended wrap scope.                 |
| 27  | Marker listing orders by `createdAtUtc` ASC but UX expectation is DESC                                                 | Should (Agent #3)         | fix      | Change ORDER to DESC in `drift_marker_store.dart:33`; update port docstring to match. Most-recent-first is the typical UX.                                |
| 28  | `pubspec_pinned_test.dart` skips `dependency_overrides:`                                                               | Should (Agent #4)         | fix      | Extend `test/pubspec_pinned_test.dart:22-23` to also scan `dependency_overrides:` block. Catches drift in overrides section.                             |
| 29  | `backup_test.dart:130-144` 5ms throttle flaky (same family as P1)                                                      | Should (Agent #4)         | fix (done 72da162) | Stabilized as side effect of #1 architectural fix (filename-ISO sort removes ms-precision collision risk). No separate edit.                             |
| 30  | Fixture `db_seed` SQL loader doesn't handle `/* block comments */`                                                     | Should (Agent #4)         | fix      | Strip block comments before `;`-split in `v1_identity_fixture_test.dart:40-54` + `migration_v1_to_v2_test.dart:119-134`, or introduce a small SQL tokenizer. |
| 31  | `tool/check_domain_purity.dart` regex missing `drift_flutter`                                                          | Should (Agent #4)         | fix      | Extend regex in `tool/check_domain_purity.dart:37-39` to match `package:drift_flutter/` too. `drift_flutter` transitively pulls `package:flutter/material.dart`.     |
| 32  | `mergeMask` race under `createInBackground` (dup of #20)                                                               | Should                    | fix (done daed232) | Covered by #20 fix.                                                                                                                                       |
| 33  | `test/fixtures/README.md` documents non-existent `drift_schemas/` sub-dir                                              | Should (Agent #4)         | fix      | Update `test/fixtures/README.md:11-13` to point to repo-root `drift_schemas/` (actual location).                                                          |

### Coulds (all → defer; 22 findings)

Blanket defer — revisit at next natural stopping point (Phase 15 polish at latest). User did NOT say "fix Coulds" under the blanket-approve; `let's fix blocker and should` is explicit scope.

| #  | Finding                                                                                                 | Severity | Decision | Rationale                                                                                     |
| -- | ------------------------------------------------------------------------------------------------------- | -------- | -------- | --------------------------------------------------------------------------------------------- |
| 34 | Agent #1: `onBeforeUpgrade` nullable hook is called through `!` — local capture avoids bang             | Could    | defer    | Low-cost polish; not blocking.                                                                |
| 35 | Agent #1: Backup filename format lacks strict lex-sort guarantees (`Z` trailing position)               | Could    | fix (done 72da162) | **Promoted into #1 production fix** — ISO timestamp capture group preserves `Z` as lex-sort tail by construction of `toIso8601String()`. Single fix covers both. |
| 36 | Agent #1: `SchemaSanityChecker.captureRowCounts` queries tables serially (UNION ALL would collapse)     | Could    | defer    | Micro-optimization; table count is small.                                                     |
| 37 | Agent #1: `v1_to_v2_notes.dart::apply` uses raw `ALTER TABLE` (rename de-sync risk)                     | Could    | defer    | Portability rationale OK; revisit if a column rename lands.                                   |
| 38 | Agent #2: `IdentityMigrationV1` sentinel `fromVersion: -1` is fragile                                   | Could    | defer    | Test coverage mitigates; revisit if JsonMigrator grows callers.                               |
| 39 | Agent #2: `MirkStyleStore.requireById`/`PhotoStore.requireById` throw unspecified exception             | Could    | defer    | Revisit in Phase 11 (photos) + Phase 13 (mirk styles).                                        |
| 40 | Agent #2: `CategoryId.isValid` returns false for `kCategoryDefaultId` (no affirmative `isReserved`)     | Could    | defer    | Revisit when category CRUD hits Phase 11.                                                     |
| 41 | Agent #2: `Envelope._payloadFromJson/toJson` take `Map<String, dynamic>`                                | Could    | defer    | Only undocumented `dynamic` in hand-written domain; comment it or revisit at Phase 13 import boundary. |
| 42 | Agent #2: `UnknownConfig.fromJson` silently accepts shapes with nested `'raw'` key — no unit test       | Could    | defer    | Add test in Phase 13 review gate.                                                             |
| 43 | Agent #2: `V1ToV2RenameRadius` drops old key even when new key is already present                       | Could    | defer    | Edge case; revisit when V2 ships real data.                                                   |
| 44 | Agent #2: `computeRevealMask` signature has no bounds validation                                        | Could    | defer    | Guard added by P3's no-callers test; bounds validation lands in Phase 09 with the body.       |
| 45 | Agent #3: `Future<SessionStore>` return forces `.future await` virality                                 | Could    | defer    | Revisit when a consumer complains in Phase 05.                                                |
| 46 | Agent #3: `ConcurrentActivationException` carries only `attemptedId` (adding `activeId` improves logs)  | Could    | defer    | Log clarity polish; revisit if debugging hits it.                                             |
| 47 | Agent #3: `CategoryInUseException` branch computes `markerCount` even when unused                       | Could    | defer    | Minor perf; COUNT(*) is fast on indexed column.                                               |
| 48 | Agent #3: `DriftMirkStyleStore.requireById` throws `StateError` (should be `NotFoundException`)         | Could    | defer    | Consistency polish; revisit in Phase 13 with mirk style CRUD.                                 |
| 49 | Agent #3: `Ulid._encodeRandom` pad/truncate defense unreachable given fixed 10→16 ratio                 | Could    | defer    | Defensive code; `assert(encoded.length == 16)` could replace — revisit at ULID audit.          |
| 50 | Agent #3: `_newDb` helper duplicated across 6 store test files                                          | Could    | defer    | Test hygiene; extract to shared helper in Phase 05 when more tests land.                      |
| 51 | Agent #4: ULID body length `26` duplicated in 6 ID `.isValid` getters                                   | Could    | defer    | Extract to `kUlidBodyLength` in Phase 15 constants polish pass.                               |
| 52 | Agent #4: `seeded_id_generator_test.dart` asserts lengths `31`/`30` without naming                      | Could    | defer    | Same polish pass as #51.                                                                      |
| 53 | Agent #4: `constants_test.dart` never asserts any Phase 03 constant                                     | Could    | defer    | Add in Phase 15 polish with the #7 + #5 new constants.                                        |
| 54 | Agent #4: `tool/check_dependencies_md.dart` doesn't verify "no duplicate rows per package"              | Could    | defer    | Add `declared.containsKey(name)` check when audit scope next hits DEPENDENCIES.md.            |
| 55 | Agent #4: `pubspec.yaml:88-95` pins `test:` against `flutter_test`-bundled version (silent absorption risk) | Could | defer    | Monitor at each SDK bump.                                                                     |

### Noted (all → observation; 33 findings: 1 pre-class + 1 cross-lens synthesis + 31 from agents)

Observations only. No action taken under blanket-approve; these stay as documented transparency signals.

| #  | Finding                                                                                                                  | Severity                  | Decision | Rationale                                                                               |
| -- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------- | -------- | --------------------------------------------------------------------------------------- |
| P2 | `custom_lint` silently degraded under analyzer-10                                                                        | Noted (pre-class)         | noted    | Operational impact = 0 (`flutter analyze` green via analyzer-10 stack). Document in STATE.md + DEPENDENCIES.md + re-verify at each deps bump. Agent #2 confirmed state unchanged (same Element2/Annotatable/ErrorCode unresolved against analyzer-10.0.1). |
| 56 | Agent #1: PRAGMA wiring split across 2 sites (no single-source-of-truth docstring)                                       | Noted                     | noted    | Correct split; add docstring if future reader is confused.                              |
| 57 | Agent #1: `cat_default` docstring + 03-05-SUMMARY disagreement (merged into #8 Should fix target)                        | Noted                     | noted    | Covered indirectly by #8.                                                               |
| 58 | Agent #1: `drift_schema_v2.json == drift_schema_current.json` byte-equal                                                 | Noted                     | noted    | Freshness guardrail green. Transparency signal.                                         |
| 59 | Agent #1: No composite `(session_id, category_id)` index on `t_markers`                                                  | Noted                     | noted    | No performance complaint yet; revisit if queries slow.                                  |
| 60 | Agent #1: `SchemaSanityChecker.assertNoLoss` only compares against before-keyset                                         | Noted                     | noted    | Intentional per Phase 03 decision (migration growth silently accepted).                 |
| 61 | Agent #1: GOSL headers present on all 7 `lib/infrastructure/db/*.dart` + 7 `test/infrastructure/db/*.dart` + migrations  | Noted                     | noted    | Positive signal; CLAUDE.md header discipline clean.                                     |
| 62 | Agent #2: `SessionStatus` transitions not encoded in type system (`InvalidSessionTransition` carries raw strings)        | Noted                     | noted    | Revisit when session state machine grows (not in V1.0 scope).                            |
| 63 | Agent #2: `-720`/`840` in `@Assert` string is compile-time carve-out (covered by #7)                                     | Noted                     | noted    | See #7 Rationale — two-step mitigation addresses the carve-out.                         |
| 64 | Agent #2: `Session`/`Marker`/`MarkerCategory`/`MirkStyle` use bare `factory` (not `const factory`)                       | Noted                     | noted    | Phase 03 decision correctly implemented per @Assert method-call restriction.             |
| 65 | Agent #2: `Envelope.fromJson` is pure arrow redirect                                                                     | Noted                     | noted    | SC#4 respected. Positive signal.                                                         |
| 66 | Agent #2: Extension-type `@JsonKey` per-field pattern verified (20+ sites)                                               | Noted                     | noted    | Positive signal.                                                                         |
| 67 | Agent #2: Zero `flutter/` or `drift/` imports in `lib/domain/**`                                                         | Noted                     | noted    | SC#2 pureté passes. Positive signal; adversarial Test #1 will poison-verify.             |
| 68 | Agent #2: Sealed `MirkStyleConfig` dispatch via pattern-match (no `is`-chain)                                            | Noted                     | noted    | SC#2 polymorphism requirement passes.                                                    |
| 69 | Agent #2: P2 confirmed unchanged (`dart run custom_lint` still fails same way)                                           | Noted                     | noted    | Re-verified at audit time — merges with P2.                                              |
| 70 | Agent #2 cross-lens for Agent #4: no test asserts `MirkStyleConfig.fromJson` when `rendererType` absent                  | Noted                     | noted    | Test gap noted; revisit in Phase 13 review gate with mirk style CRUD.                    |
| 71 | Agent #2 cross-lens for Agent #3: `Marker.photos` `@Default(const <PhotoRef>[])` allocates (constructor not const)       | Noted                     | noted    | Every Marker allocates a fresh empty list; micro-alloc. Revisit when Phase 11 adds real photo joins. |
| 72 | Agent #3: `ref.onDispose(() async { await db.close(); })` wraps close in unnecessary async closure                       | Noted                     | noted    | Style polish; not a bug.                                                                 |
| 73 | Agent #3: `_statusConv` declared but bypassed on `activate`/`deactivate` (merged into #24 fix target)                    | Noted                     | noted    | Covered by #24.                                                                          |
| 74 | Agent #3: `listBySession` orders by `(parentX, parentY)` but unique key includes `parentZoom`                            | Noted                     | noted    | Single zoom today per D3; revisit if multi-zoom lands.                                   |
| 75 | Agent #3: Marker-category cascade test only asserts end-state, not same-transaction execution                            | Noted                     | noted    | End-state consistency is the user-visible contract; atomicity is an impl detail.         |
| 76 | Agent #3: 7 providers `keepAlive=true`; `ProviderContainer().dispose()` is only teardown path                            | Noted                     | noted    | Revisit if test teardown becomes fragile.                                                |
| 77 | Agent #3: Photo-join deferral makes `Marker.photos` always `[]` (cross-lens with #71)                                    | Noted                     | noted    | Phase 11 photo store owns hydration.                                                     |
| 78 | Agent #3: `RandomIdGenerator` accepts optional `Random`; `SeededIdGenerator` nearly redundant                            | Noted                     | noted    | Seam preserved for clarity in tests; collapse revisit is deferrable.                     |
| 79 | Agent #3 cross-lens for Agent #1: `t_sessions.status` no CHECK + `-720/840` literal                                      | Noted                     | noted    | Cross-ref to #10 + #7. Already covered.                                                  |
| 80 | Agent #4: `custom_lint.log` in working tree (gitignored) — evidence P2 actively generates noise                          | Noted                     | noted    | Transparency signal; merges with P2.                                                     |
| 81 | Agent #4: `DriftRevealedTileStore` uses `_idGenerator` actively; `DriftSessionStore` uses `// ignore: unused_field`       | Noted                     | noted    | Covered by #21 fix target.                                                               |
| 82 | Agent #4: `ImportValidationException`/`MigrationFailureException` use `reason` not `message`                             | Noted                     | noted    | Naming convention divergence; revisit in Phase 13 errors audit.                          |
| 83 | Agent #4: `NativeDatabase.memory` in tests sets `PRAGMA journal_mode=WAL` but in-memory backend returns `memory`         | Noted                     | noted    | Cargo-culted across 7 test files; `app_database_pragma_test.dart:46-58` documents the no-op. Revisit in Phase 15 test polish. |
| 84 | Agent #4: Additional investigation — no additional `UnimplementedError` throws beyond P3                                  | Noted                     | noted    | P3 coverage complete.                                                                    |
| 85 | Agent #4: Additional investigation — flaky Windows test candidates beyond P1 (3 candidates)                               | Noted                     | noted    | Revisit in Phase 15 test-stability polish pass.                                          |
| 86 | Agent #4: Additional investigation — no analyzer-plugin silent-degrade analogues beyond P2                                | Noted                     | noted    | Adjacent risk flagged (`tool/check_*.dart` fail-silent on pubspec shape drift) for future tooling audit. |
| 87 | Cross-lens synthesis: 2 severity disagreements (#5 parentZoom, #7 UTC offset) preserved with explicit lens attribution    | Noted                     | noted    | Pattern reused from Phase 02 "Cross-lens finding overlap handling convention" — transparency over merge. |

### Triage totals

- **fix:** 35 rows (9 Blockers + 27 Shoulds — minus 4 duplicate rows #11, #13, #29, #32 that reference existing fix targets — net ~31 unique fix targets, plus 2 paired fixes #1↔P1 and #20↔#32 each collapse to a single architectural fix)
- **defer:** 22 rows (all Coulds)
- **noted:** 33 rows (all Noteds + P2 + cross-lens synthesis row)
- **waived:** 0 rows
- **won't-fix:** 0 rows
- **Grand total:** 91 triage rows (5 pre-class + 86 agent findings, with cross-lens overlaps preserved per Phase 02 precedent)

## 4. Adversarial evidence

*Filled by Plan 04-04. Two CI-branch evidence blocks (Tests #1, #2) + one permanent unit-test evidence block (Test #3).*

### Test 1: Domain purity import violation (Flutter + Drift)
*Branch `adversarial/04-domain-import-flutter-and-drift`: one branch, TWO violations. CI step `Check domain purity (lib/domain/ imports)` must fail with exit 1 listing BOTH `lib/domain/sessions/session.dart` (Flutter import) AND `lib/domain/markers/marker.dart` (Drift import).*

- **Branch:** `adversarial/04-domain-import-flutter-and-drift` (deleted 2026-04-18, local + remote)
- **Poison commit:** `259af71` — `test(adversarial): inject Flutter + Drift imports in domain to exercise check_domain_purity gate` (initial `a375418` amended with format reflow of 61 pre-existing-drift files, see Surprise finding below; single-commit branch at deletion)
- **CI-trigger commit:** `259af71` — same commit; Option B per Phase 02 precedent (poison + trigger in same commit). `.github/workflows/ci.yml` `on.push.branches` temporarily set to `[main, 'adversarial/**']` on the branch only; `main` trigger stays `[main]`-only (inline expansion deleted together with the throwaway branch).
- **Run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24611059783
- **Job:** `Lint / Licence / Headers / Deps` (the `gates` job, conclusion=failure)
- **Gate step:** `Check domain purity (lib/domain/ imports)` — exit code **1** (policy violation, NOT exit 2 / misconfiguration). Prior steps all green: `Dart format check`, `Flutter analyze`, `Check GOSL headers`, `Check licenses`, `Check DEPENDENCIES.md is up to date`.
- **Error excerpt (stderr from `gh run view 24611059783 --log-failed`):**
  ```
  Run dart run tool/check_domain_purity.dart
  check_domain_purity: 2 forbidden import(s) under lib/domain/:
    lib/domain/sessions/session.dart:13: import 'package:flutter/material.dart';
    lib/domain/markers/marker.dart:13: import 'package:drift/drift.dart' hide JsonKey;
  Rule: lib/domain/ must not import package:flutter/* or package:drift/*.
  Move the offending import to lib/application/ or lib/infrastructure/.
  Process completed with exit code 1.
  ```
- **Confirms:** Gate detects multiple real forbidden imports in a single pass, not just synthetic fixtures. Tool does NOT short-circuit on first violation — both `session.dart` (Flutter) and `marker.dart` (Drift) are listed in one run. The `hide JsonKey` clause on the drift import does not disguise the import from the scanner (the regex anchors on `package:drift(?:/|['"])`, not on the symbol list).
- **Surprise finding during execution:** The first push (commit `a375418`) failed CI on `Dart format check` — an EARLIER step than the target — because 61 pre-existing files on `main` itself do not round-trip through CI's `dart format --line-length 160 --set-exit-if-changed .` clean (Phase 03 generated `.g.dart` files + some hand-written Phase 03 sources committed at a slightly-different toolchain rendering than CI's Flutter 3.41.5 produces). Confirmed independently — CI run 24610968531 on `main` (today's 61-commit push, docs-only) ALSO failed on the same step. The adversarial test amended its poison commit to include the re-formatted 61 files so CI could reach the target `Check domain purity` gate. This pre-existing drift is tracked in `.planning/phases/04-review-gate-persistence/deferred-items.md` for Plan 04-05 (or a standalone fix) — see item #1. It is NOT caused by the adversarial poison.

### Test 2: Drift schema dump stale
*Branch `adversarial/04-schema-drift-stale`: add a column to `t_sessions` in `app_database.dart`, run `build_runner build` (mandatory — otherwise `flutter analyze` fails first per RESEARCH Pitfall 1), do NOT run `drift_dev schema dump`. CI step `Check drift schema (current) is committed and fresh` must fail with `git diff --exit-code` showing stale `drift_schemas/drift_schema_current.json`.*

- **Branch:** `adversarial/04-schema-drift-stale` (deleted 2026-04-18, local + remote)
- **Poison commit:** `890851a` — `test(adversarial): add notesExtra column without re-dumping drift schema`. Added `TextColumn get notesExtra => text().nullable()();` to `Sessions extends Table` in `lib/infrastructure/db/app_database.dart` (between the existing `notes` column and the `primaryKey` override). `dart run build_runner build --delete-conflicting-outputs` was run locally so `app_database.g.dart` regenerated cleanly (78 outputs written) — without this prerequisite, `flutter analyze` would have failed first on stale `.g.dart` (RESEARCH Pitfall 1). `dart run drift_dev schema dump` DELIBERATELY NOT RUN — the rolling `drift_schemas/drift_schema_current.json` stays frozen at its pre-poison content, which is the whole point of the poison.
- **CI-trigger commit:** `890851a` — same commit; Option B (poison + trigger together). Branch ci.yml temporarily had `on.push.branches: [main, 'adversarial/**']`; main ci.yml stays `[main]`-only.
- **Run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24611132558
- **Job:** `Lint / Licence / Headers / Deps` (the `gates` job, conclusion=failure)
- **Gate step:** `Check drift schema (current) is committed and fresh` — exit code **1** (policy violation, NOT exit 2 / misconfiguration). All prior steps green: `Dart format check`, `Flutter analyze`, `Check GOSL headers`, `Check licenses`, `Check DEPENDENCIES.md is up to date`, `Check domain purity (lib/domain/ imports)`, `Tool scripts unit tests`.
- **Error excerpt (stderr from `gh run view 24611132558 --log-failed`):**
  ```
  Run dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_current.json
      git diff --exit-code drift_schemas/drift_schema_current.json || {
        echo "::error::drift_schemas/drift_schema_current.json is stale.";
        echo "Run: dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_current.json";
        exit 1;
      }
  Wrote to drift_schemas/drift_schema_current.json
  diff --git a/drift_schemas/drift_schema_current.json b/drift_schemas/drift_schema_current.json
  index a37d016..928a9ee 100644
  --- a/drift_schemas/drift_schema_current.json
  +++ b/drift_schemas/drift_schema_current.json
  ##[error]drift_schemas/drift_schema_current.json is stale.
  Run: dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_current.json
  Process completed with exit code 1.
  ```
- **Confirms:** Gate detects real schema-source-of-truth drift — `t_sessions` gained a column in `app_database.dart` + its `.g.dart` but the frozen `drift_schema_current.json` stayed behind. CI's re-run of `drift_dev schema dump` produces divergent content, `git diff --exit-code` non-zero, the conditional shell block fires `::error::` annotation and `exit 1`. build_runner prerequisite honored (Pitfall 1 avoided — no `flutter analyze` false-first failure). This is the full end-to-end check: the gate is not a dry-run lint, it actually re-dumps and compares.
- **Note on branch format scope:** Like Test 1, this branch also included the 61-file pre-existing format reflow alongside the poison so CI could reach the target step. Same root cause, same deferred-items.md item #1. Net effect on `main`: zero — branch deleted, format drift on main unchanged.

### Test 3: SchemaSanityChecker row-loss detection (permanent unit test)
*NOT a throwaway branch. Permanent test `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` on `main`. Injects V1 fixture (70 rows), runs adversarial migration with `ALTER TABLE` + `DELETE FROM t_sessions WHERE rowid % 2 = 0`, asserts `SchemaSanityChecker.assertNoLoss` throws `MigrationFailureException` with exact row-count diff. Evidence = commit hash + green `dart test` output.*

- **Type:** permanent regression guard (NOT a throwaway branch)
- **File:** `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart`
- **Commit:** `9c32eb1` on `main` — `test(04-rev): add SchemaSanityChecker row-loss regression guard`
- **Tags:** `@Tags(<String>['migration'])` (inherits Phase 03's slow-suite tag discipline — runs alongside `migration_v1_to_v2_test.dart` under `dart test -t migration`)
- **Test result (local `dart test test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart`):**
  ```
  00:00 +0: loading test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart
  00:00 +0: (setUpAll)
  00:00 +0: SchemaSanityChecker row-loss regression guard (Phase 04 Test #3) assertNoLoss throws MigrationFailureException when adversarial DELETE loses ~50% of t_sessions during a V1→V2-shaped migration
  00:00 +1: (tearDownAll)
  00:00 +1: All tests passed!
  ```
- **Behavior proven:** `SchemaSanityChecker.assertNoLoss` throws `MigrationFailureException` when an adversarial migration (`ALTER TABLE t_sessions ADD COLUMN "notes" TEXT NULL` + `DELETE FROM t_sessions WHERE rowid % 2 = 0`) loses sessions from the 70-row `v1_baseline.sql` fixture. Exception `reason` field contains both `t_sessions` and `decreased` (matching prod message: `row count decreased on t_sessions: 10 → 5 (migration likely dropped data)`).
- **False-positive guard:** the test asserts `after['t_sessions']! < before['t_sessions']!` BEFORE the `throwsA` expectation. A local mutation experiment confirmed this guard fires: replacing the adversarial DELETE with `DELETE FROM t_sessions WHERE 1=0` (inert) causes the test to fail with `adversarial DELETE did not remove any session row — test would be inert. before=10 after=10`. So the test cannot silently become a no-op through future SQL or fixture changes.
- **Confirms:** `SchemaSanityChecker` is the last line of defense against data-loss in any future migration. Permanent in-repo adversary means Phase 05+ cannot accidentally bypass it — any onUpgrade regression that drops rows will trip this test, and the same production code path at runtime will also fail-closed with `MigrationFailureException` (wrapped in 03-05's `DbBackupService` restore flow).

## 5. CI-green confirmation

*Filled by Plan 04-05 Task 2 after all Blocker + non-waived Should fixes are applied and CI is green.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending)
- **Date:** (pending)

---
_Phase 04 closed: (pending)_
_Phase 05 unblocked._

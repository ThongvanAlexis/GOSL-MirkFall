---
phase: 04-review-gate-persistence
plan: 02
subsystem: review-gate
tags: [runtime-walk, windows, drift, sqlite, wal, pragma, path_provider, zone-mismatch, review-artefact]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: buildAppDatabase factory + AppDatabase schemaVersion=2 + Drift WAL setup + applyRuntimePragmas + DbBackupService wiring (artefacts under runtime observation in this walk)
  - phase: 04-review-gate-persistence
    provides: 04-REVIEW.md scaffold with §1b + §2 placeholders (04-01 output)
provides:
  - §1b Runtime walk Windows populated with verbatim walk (a) flutter run + walk (b) dart run + sqlite3 inspection + flutter doctor + where /r outputs
  - §2 Pre-known from Runtime Walk sub-section with 2 findings (Blocker zone-mismatch + Should walk-tooling pragma gap) escalated pending-user-decision
  - tool/walk_db.dart (retained) — Option B manual-path-resolution DB opener bypassing path_provider's dart:ui dependency
  - tool/inspect_db.sql (retained) — CMD-compatible sqlite3 PRAGMA + .schema + .indexes script
  - Unblock signal for Plan 04-03 Wave 3 agent spawn — both user-first §1 AND runtime-walk §1b are committed before any Agent tool call
affects: [04-03, 04-04, 04-05, 05-gps-session-lifecycle, 06-review-gate-gps, 08-review-gate-map, 10-review-gate-fog, 12-review-gate-markers, 14-review-gate-import-export, 16-review-gate-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Runtime walk dedicated plan pattern — runtime observation BEFORE synthetic audit (walk-first, then agent spawn). Reusable for every review gate that follows an infrastructure phase."
    - "Option B manual-path-resolution pattern for dart run tools — path_provider transitively pulls dart:ui which cannot load under vanilla `dart run`. Workaround: construct %APPDATA%\\<CompanyName>\\<ProductName>\\ from Runner.rc constants. Mirrors path_provider_windows byte-for-byte."
    - "CMD-compatible SQL inspection script (tool/inspect_db.sql) over bash heredoc — Windows CMD has no POSIX heredoc; a .sql script works across CMD, PowerShell, and bash."
    - "Walk driver choice (a) + (b) combined — (a) flutter run -d windows proves desktop packaging + plugin stack; (b) dart run tool/walk_db.dart proves buildAppDatabase against real fs. Each driver exercises a different contract; (a+b) is the complete runtime-reachability check."
    - "Caveat-labelled §1b bullets when evidence is non-authoritative — rather than silently omitting the 3 per-connection pragmas, §1b explicitly flags them as CAVEAT with a Should-level finding in §2. Preserves transparency; no silent deferral."

key-files:
  created:
    - .planning/phases/04-review-gate-persistence/04-02-SUMMARY.md
    - tool/walk_db.dart
    - tool/inspect_db.sql
  modified:
    - .planning/phases/04-review-gate-persistence/04-REVIEW.md

key-decisions:
  - "Walk driver (a+b) combined — user ran both flutter run -d windows AND dart run tool/walk_db.dart for complete coverage (desktop packaging AND DB open)"
  - "Option B manual path resolution in tool/walk_db.dart — path_provider cannot load under vanilla dart run (transitive dart:ui dependency); workaround constructs %APPDATA%\\app.gosl\\mirkfall\\ from Runner.rc CompanyName + ProductName, verified byte-identical to path_provider_windows via where /r"
  - "tool/inspect_db.sql added as CMD-compatible alternative to bash heredoc — bash heredoc does not run in Windows CMD; .sql script works across all three shells"
  - "Retain BOTH tool/walk_db.dart AND tool/inspect_db.sql on main — ~95 lines total, zero CI/dependency cost, reusable as smoke test for Phase 05 ProviderScope wiring + any future persistence walk. Can evolve to close the Should-finding (walk-tooling pragma gap) by printing Drift-side PRAGMAs before close."
  - "3 per-connection pragmas (foreign_keys, synchronous, busy_timeout) flagged as §1b CAVEAT + §2 Should finding rather than asserted as green — sqlite3 CLI reads library defaults, not what Drift applied. Transparency over false assertion."
  - "Zone mismatch at flutter run -d windows flagged as §2 Blocker pending-user-decision — fix belongs in Phase 04 fix loop (04-05) or deferred via explicit waiver; CANNOT slip silently into Phase 05"
  - "Plan-text inaccuracy (t_photo_refs vs actual t_photos) documented in §1b Confirms #2 + SUMMARY deviations — cosmetic only, no schema bug"

patterns-established:
  - "Walk-first precedes synthetic-audit: runtime observation (dedicated plan, direct filesystem exercise) MUST land before sub-agent audit wave — reusable gate ordering rule for review gates 04, 06, 08, 10, 12, 14, 16"
  - "Any one-off Dart tool that production imports plumb to path_provider needs the Option B path-construction pivot because path_provider requires a Flutter engine; a plain-Dart walk cannot use it"
  - "Evidence archival is VERBATIM — no paraphrasing of CLI output. Reviewers can spot malformed output (empty PRAGMA result, suspicious null line) only if the paste is raw"
  - "Findings surfaced BY a walk get escalated to §2 AT walk-archival time, not deferred to the agent audit wave — keeps findings traceable to their source (§1b runtime evidence → §2 pre-known entry → §3 triage)"

requirements-completed:
  - SC#3

# Metrics
duration: 45 min
completed: 2026-04-18
---

# Phase 04 Plan 02: Runtime Walk Windows Summary

**First end-to-end runtime observation of Phase 03's Drift DB on a real Windows filesystem — `buildAppDatabase` opens `mirkfall.db` at the expected `%APPDATA%\app.gosl\mirkfall\` path with WAL active + all 6 tables + partial unique index + schemaVersion=2; AND surfaces a Blocker (Zone mismatch crash at `runApp` during `flutter run -d windows`) that Phase 03's 64 unit tests + Phase 02 visual walk + CI build jobs all missed.**

## Performance

- **Duration:** ~45 min (walk script scaffold + 2 Rule-3 blocking pivots + CMD compatibility fix + user-executed walk + verbatim archival + findings escalation)
- **Started:** 2026-04-18T16:55:00Z (approx — first Task 1 commit `2c56863` at 16:55)
- **Completed:** 2026-04-18T17:33:27Z (§1b+§2 archival commit `78abe04`)
- **Tasks:** 3 (Task 1 scaffold + Task 2 user execution + Task 3 archival — all 3 complete)
- **Files modified:** 3 (2 created: `tool/walk_db.dart` + `tool/inspect_db.sql`; 1 modified: `04-REVIEW.md`)
- **User-side wait time:** included in duration (user executed walk in their Windows terminal, pasted outputs)

## Accomplishments

- **`mirkfall.db` opens on real Windows filesystem** — 77824 bytes at `C:\Users\oliver\AppData\Roaming\app.gosl\mirkfall\mirkfall.db`, `buildAppDatabase` executes `SELECT 1` successfully, clean close
- **All 6 Phase 03 schema tables confirmed present on disk** — `t_sessions`, `t_marker_categories`, `t_markers`, `t_revealed_tiles`, `t_mirk_styles`, `t_photos` (note: plan text says `t_photo_refs`, actual is `t_photos` — see deviations)
- **Partial unique index `idx_t_sessions_status_active` confirmed on disk** — SESS-06 DB-level exclusivity intact
- **`user_version=2` + `journal_mode=wal` + `page_size=4096` confirmed persisted in DB header** — schema version + WAL + page size are the 3 DB-level pragmas that survive across connections
- **Option B manual-path-resolution in `tool/walk_db.dart` validated** — `where /r %APPDATA% mirkfall.db` returns exactly ONE match at the Option B path, proving the manual construction matches `path_provider_windows`'s resolution byte-for-byte
- **Walk (a) observed but UNSUCCESSFUL boot** — `flutter run -d windows` builds `mirkfall.exe` (36.5s Nuget + build, green), but `runApp` fires Zone mismatch assertion and the app exits. Build toolchain is green; boot runtime is NOT. **This is exactly the class of bug the runtime walk exists to catch.**
- **Two findings escalated at walk-archival time to §2 Pre-known from Runtime Walk** — Blocker (Zone mismatch) + Should (walk-tooling pragma gap), both `pending-user-decision`
- **`04-REVIEW.md` §1b + §2 atomically committed** on `main` BEFORE Plan 04-03 Wave 3 agent spawn — hard ordering gate satisfied

## Task Commits

Each task was committed atomically (where possible; §1b+§2 archival combined because they share one source — the user's pasted outputs — and committing §1b without §2 would leave unreferenced findings dangling):

1. **Task 1 (initial): Walk script scaffold** — `2c56863` (docs) — first cut of `tool/walk_db.dart` with the plan's reference pattern (used `getApplicationSupportDirectory` + `await buildAppDatabase()`)
1. **Task 1 (Rule 3 fix — Option B pivot): Bypass path_provider for vanilla `dart run`** — `c142a8c` (fix) — rewrote `tool/walk_db.dart` to construct `%APPDATA%\app.gosl\mirkfall\` manually from `Runner.rc` CompanyName+ProductName constants (path_provider transitively imports `dart:ui` and dies under plain `dart run` — cannot load without Flutter engine binding). Signature also adjusted: `buildAppDatabase` is synchronous (not `async`), requires `dbFilename`, `backupDir`, `maxBackups` positional args, not the plan's template `await buildAppDatabase()` call.
1. **Task 1 (Rule 3 fix — CMD compatibility): Add `tool/inspect_db.sql`** — `259c61e` (chore) — the plan's sqlite3 inspection step used bash heredoc syntax (`sqlite3 <path> <<'SQL' ... SQL`) which does not run in Windows CMD. Added a `.sql` script that works in CMD, PowerShell, and bash via `sqlite3 "<path>" < tool\inspect_db.sql`.
2. **Task 2: User-executed runtime walk** — (user action; no repo commit by Claude — artifact is the pasted outputs below, which Task 3 archived)
3. **Task 3: §1b verbatim archival + §2 findings escalation** — `78abe04` (docs) — 135-line insertion covering: 5 verbatim output blocks (walk b, sqlite3, flutter doctor, walk a, where /r) + 7 Confirms bullets (including explicit CAVEAT on 3 per-connection pragmas) + 3 informational observations + §2 Pre-known from Runtime Walk sub-section with 2 findings.

**Plan metadata commit:** _(pending — final plan-closure commit after STATE.md + ROADMAP.md updates)_

## Files Created/Modified

- **`tool/walk_db.dart`** (created, 69 lines) — Windows-only runtime walk utility. Constructs `%APPDATA%\app.gosl\mirkfall\` manually, instantiates `buildAppDatabase` with explicit args, forces lazy open via `SELECT 1`, closes, reports 3 file sizes. GOSL header + extensive comment explaining Option B rationale.
- **`tool/inspect_db.sql`** (created, 29 lines) — CMD-compatible sqlite3 inspection script. Dumps the 6 mandatory PRAGMAs + `.schema` + `.indexes t_sessions`. GOSL `--` header.
- **`.planning/phases/04-review-gate-persistence/04-REVIEW.md`** (modified, +135 lines) — §1b populated verbatim with walk evidence + Confirms analysis; §2 new sub-section `Pre-known from Runtime Walk (§1b)` with 2 findings.

## Decisions Made

### Walk driver (Task 2): (a+b) combined

User ran BOTH `flutter run -d windows` (walk a) AND `dart run tool/walk_db.dart` (walk b). Rationale (user's implicit — both sets of outputs were pasted): complete coverage. (a) validates desktop packaging + plugin stack; (b) validates DB open. The combined run produced the most informative §1b possible — including the Blocker (walk a crash) that (b)-only would not have surfaced.

### Option B manual path resolution (Task 1 Rule 3 fix)

`getApplicationSupportDirectory()` from `path_provider` transitively imports `dart:ui`, which vanilla `dart run` cannot load (no Flutter engine, no binding, no `dart:ui` symbol table). The plan's reference pattern (using `getApplicationSupportDirectory`) crashed immediately. Fix: construct `%APPDATA%\app.gosl\mirkfall\` manually from the `CompanyName` + `ProductName` constants declared in `windows/runner/Runner.rc`. Verified byte-identical to `path_provider_windows` resolution via `where /r %APPDATA% mirkfall.db` returning a single match at the Option B path.

Alternative considered + rejected: driving the walk via `flutter test` (which has the Flutter binding available). Rejected because `flutter test` introduces test-infra framing (tearDown, tester, widget binding) that isn't the production DB open path — defeats the purpose of exercising `buildAppDatabase` end-to-end. Option B is a clean direct-invoke.

### CMD-compatible `tool/inspect_db.sql` (Task 1 Rule 3 fix)

Plan Task 2 step 3 specified `sqlite3 '<PATH>' <<'SQL' ... SQL` (bash heredoc). Windows CMD has no heredoc — the command would fail at the first `<<'SQL'` token. Added `tool/inspect_db.sql` as a repository-tracked script; user invokes with `sqlite3 "<path>" < tool\inspect_db.sql` which works in CMD, PowerShell, and bash. Header convention for `.sql` files (matches `test/fixtures/db_seed/v1_baseline.sql`) confirmed: `--` prefix, same GOSL copyright block.

### Retention decision: KEEP `tool/walk_db.dart` + KEEP `tool/inspect_db.sql`

**Decided: KEEP both.** Rationale:

1. **Zero cost on main** — `walk_db.dart` is 69 lines, `inspect_db.sql` is 29 lines. Neither adds a dependency, a CI step, a build-time cost, or a runtime import from `lib/`. Both are explicitly scoped under `tool/` (convention: `tool/` is dev utilities, not shipped code — `tool/check_headers.dart` already precedent).
2. **Reusable smoke test** — after Phase 05 wires ProviderScope with real consumers, `dart run tool/walk_db.dart` remains the single one-command way to verify a) the DB opens on a fresh machine, b) the pragmas are at expected values, c) WAL-mode journal is active. Useful for future dev-env onboarding, release-branch smoke, post-refactor spot-check.
3. **Natural home for the Should-finding remediation** — the §2 Should entry ("sqlite3 CLI pragmas non-authoritative for 3 per-connection settings") can be closed cheaply by extending `walk_db.dart` to print `foreign_keys`, `synchronous`, `busy_timeout` from inside the Drift connection via `db.customSelect('PRAGMA ...').get()` BEFORE `db.close()`. That is ~15 additional lines and would make the walk authoritatively cover all 6 PRAGMAs. Deleting `walk_db.dart` now would throw away the natural home for that remediation.
4. **No delete commit needed** — retention is the default state (already committed in Task 1). Plan's delete-case conditional branch is skipped.

Documented in STATE.md Decisions for phase-04.

### Plan-text inaccuracy: `t_photo_refs` vs actual `t_photos`

Plan 04-02 objective text and `must_haves.truths` reference `t_photo_refs` as the 6th table. Actual schema (confirmed via `.schema` output): `t_photos`. This is a plan-text drift — not a schema bug. The Phase 03 Plan 03-04 migration SQL emits `CREATE TABLE "t_photos"`; PhotoRef is the DOMAIN MODEL name (from Freezed), not the DB table name. Plan text mis-paraphrased the domain model as the table name.

**Action taken:** logged in §1b Confirms #2 as a note; flagged here in SUMMARY deviations (Rule 1 - Bug). Plan 04-03 agents will encounter actual `t_photos` in their queries, not `t_photo_refs` — this could waste agent cycles on false "missing table" alarms. Plan 04-03 Task 1 pre-class commit should reference `t_photos` directly, not the plan's `t_photo_refs` text.

Does NOT propagate further: ROADMAP Phase 03 SC#4 lists `PhotoRef` as the domain model (correct domain name) — roadmap text is consistent; only plan 04-02 mis-translated domain-name to table-name.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan Task 1 reference template used `await buildAppDatabase()` — signature mismatch**
- **Found during:** Task 1 (walk script scaffold)
- **Issue:** Plan's `<interfaces>` template showed `final db = await buildAppDatabase();` but `buildAppDatabase` in `lib/infrastructure/db/app_database_factory.dart` is SYNCHRONOUS (returns `AppDatabase` directly, not `Future<AppDatabase>`) and requires 3 positional args: `dbFilename`, `backupDir`, `maxBackups`. The `await` + no-args form would not compile.
- **Fix:** Adapted `tool/walk_db.dart` to match the real production signature: `final db = buildAppDatabase(dbFilename: ..., backupDir: ..., maxBackups: kMaxDbBackups);` — no `await`, 3 named/positional args explicit.
- **Files modified:** `tool/walk_db.dart` (initial scaffold — commit `2c56863`)
- **Verification:** compile clean (`dart format` + initial `dart analyze` run green); confirmed contract by re-reading `lib/application/providers/app_database_provider.dart` and matching its wiring.
- **Committed in:** `2c56863`

**2. [Rule 3 - Blocking] `getApplicationSupportDirectory()` crashes under vanilla `dart run` (dart:ui transitive dep)**
- **Found during:** Task 1 — first attempted user-run of walk script
- **Issue:** `path_provider` package transitively imports `dart:ui` through `path_provider_platform_interface` → platform channel code → `dart:ui.PlatformDispatcher`. `dart run` executes in pure Dart VM (no Flutter engine) and cannot resolve `dart:ui` symbols. Walk crashed at `getApplicationSupportDirectory()` call with `Unsupported operation: This platform does not implement getApplicationSupportDirectory`.
- **Fix (Option B pivot, user pre-authorized by plan's `<interfaces>` note on RESEARCH Pitfall 3):** construct the Windows `%APPDATA%\<CompanyName>\<ProductName>\` path manually from `Platform.environment['APPDATA']` + Runner.rc constants. Emit a clean `Platform.isWindows` guard + APPDATA-set guard. Comment in the file explaining the rationale + noting Windows-only scope with a loud fail on other hosts.
- **Files modified:** `tool/walk_db.dart` (rewrite — commit `c142a8c`)
- **Verification:** `where /r %APPDATA% mirkfall.db` returns exactly ONE match at `%APPDATA%\app.gosl\mirkfall\mirkfall.db` after the walk — proves Option B path is byte-identical to what `path_provider_windows` would resolve (since walk (a) did NOT create a second DB anywhere, ProviderScope deferral per 03-CONTEXT was confirmed in the same step).
- **Committed in:** `c142a8c`

**3. [Rule 3 - Blocking] Plan Task 2 sqlite3 inspection command uses bash heredoc — fails in Windows CMD**
- **Found during:** Task 2 (user's first attempt to run sqlite3 inspection)
- **Issue:** Plan Task 2 specified `sqlite3 '<PATH>' <<'SQL' ... SQL` syntax. Windows CMD does not implement POSIX heredoc. User's shell (bash-in-git-bash? PowerShell? CMD?) either silently swallowed the command or errored on `<<`.
- **Fix:** Created `tool/inspect_db.sql` — a plain `.sql` script with `.headers on`, `.mode column`, the 6 PRAGMAs, `.schema`, `.indexes t_sessions`. Users invoke with `sqlite3 "<path>" < tool\inspect_db.sql` which works in CMD, PowerShell, AND bash (redirect-stdin is universal).
- **Files modified:** `tool/inspect_db.sql` (created — commit `259c61e`)
- **Verification:** User successfully ran `sqlite3 "C:\Users\oliver\AppData\Roaming\app.gosl\mirkfall\mirkfall.db" < tool\inspect_db.sql` and pasted 6 PRAGMA outputs + `.schema` + `.indexes` result into chat. Command works.
- **Committed in:** `259c61e`

**4. [Rule 1 - Known Inaccuracy] Plan text says `t_photo_refs`; actual table name is `t_photos`**
- **Found during:** Task 3 (archival — reading `.schema` output verbatim)
- **Issue:** Plan 04-02's objective paragraph and `must_haves.truths[2]` reference the 6th table as `t_photo_refs`. Actual DB emits `t_photos` (see Phase 03 Plan 03-04 migration SQL + Freezed `PhotoRef` vs. DB table `t_photos` separation). Plan text mis-translated the domain model (`PhotoRef`) as the table name.
- **Fix:** Noted in §1b Confirms #2 bullet; documented here as Rule 1 so Plan 04-03 Task 1 pre-class commit references the correct table name. No code change (schema is correct — only plan text was wrong).
- **Files modified:** `.planning/phases/04-review-gate-persistence/04-REVIEW.md` (§1b Confirms note)
- **Verification:** `.schema` output shows `CREATE TABLE "t_photos"` with FK to `t_markers` — table name is correct per Phase 03 SUMMARY. Domain model `PhotoRef` remains the Freezed class name in `lib/domain/photos/`.
- **Committed in:** `78abe04`

---

**Total deviations:** 4 auto-fixed (3 Rule 3 Blocking + 1 Rule 1 Known-Inaccuracy).
**Impact on plan:** All 3 Blocking fixes were strictly necessary — the plan as literally written would have failed at Task 1 compile (signature), Task 2 first user run (path_provider crash), and Task 2 sqlite3 step (heredoc syntax). Option B pivot was explicitly foreseen by RESEARCH Pitfall 3 and referenced in plan's `<interfaces>` notes, so the deviation is inside the spirit of the plan even if the letter diverged. The Rule 1 plan-text inaccuracy is cosmetic and does not affect schema correctness. Net effect: plan GOAL achieved (runtime walk evidence committed), plan LETTER adapted on-the-fly to Windows + CMD + vanilla-dart-run realities.

## Authentication Gates

None — runtime walk exercises local filesystem only, no external services, no CLI tool authentication required.

## Issues Encountered

### Blocker surfaced BY the walk (flagged to §2, triage deferred to Plan 04-03 or 04-05)

**Zone mismatch assertion crashes the app at `runApp` on Windows desktop.**

- `flutter run -d windows` builds `mirkfall.exe` successfully (36.5s, Nuget + native build + linker all green)
- On boot: `FlutterError` thrown from `BindingBase.debugCheckZone` at `binding.dart:519` → `_runWidget` at `binding.dart:1680` → `runApp` at `binding.dart:1616` → `main.dart:71` (the `runApp(const ProviderScope(...))` call) — inside the `runZonedGuarded` callback
- Stack confirms: `WidgetsFlutterBinding.ensureInitialized()` at `main.dart:34` ran in the root zone; `runApp` at `main.dart:71` runs inside the guarded zone; the binding's message handlers observe a different zone than `runApp`, triggering the debug-build-only zone assertion.
- Phase 01 RESEARCH line 349-354 + 987-989 was the source of the "ensureInitialized outside runZonedGuarded" pattern that `main.dart:26-33` comments reference. Flutter 3.41.7's `debugCheckZone` disagrees with that pattern in practice — the inverse fix (ensureInitialized INSIDE the guarded zone) would also be legitimate per the same Flutter docs.
- FileLogger armed correctly BEFORE the crash: log file `C:\Users\oliver\Documents\logs\20260418_1927.32_logs.txt` captured the INFO "MirkFall starting — logger armed" line + the SHOUT FlutterError with full stack. Error handling infrastructure (`FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded` catcher) works as designed — it caught the assertion and logged it cleanly. This is a silver lining: the error pipeline Phase 01 built is functioning correctly.

**Why CI didn't catch this:** CI runs `flutter build` (compile-only), not `flutter run` (actual launch). Unit tests (`flutter test`) use `testWidgets` which installs its own binding in the test zone — doesn't exercise the production zone-topology. `dart test` runs pure-Dart code with no Flutter binding at all. The only code path that catches this is an actual `flutter run` against a live device/desktop — which is precisely what the runtime walk exists to do.

**Why Phase 02 visual walk didn't catch this:** Phase 02 Agent #2 visual walk happened BEFORE Phase 01's Plan 02-04 fix that wired `PlatformDispatcher.onError`. The `main.dart` structure at that time may have been different, or the walk may have been exercised in release mode (where `debugCheckZone` is compiled out). Triage in §3 should include a re-reading of Phase 02 §1b/§2 to see whether that walk captured a similar crash and whether it was resolved or silently deferred.

**Escalation:** §2 Pre-known from Runtime Walk — `[Blocker | pending-user-decision]`. Cannot slip to Phase 05: Phase 05's first ProviderScope consumer (`ActiveSessionController`) would hit this crash on every first boot.

### Should-level walk-tooling gap (also flagged to §2)

sqlite3 CLI's `foreign_keys`, `synchronous`, `busy_timeout` readings are per-connection defaults, NOT Drift's applied values. The walk as designed cannot independently cross-check these. Phase 03 Plan 03-04 pragma unit tests (via Drift's in-process `customSelect('PRAGMA ...')`) DO assert them — so the contract is covered — but an independent filesystem-level cross-check is incomplete. Cheap remediation (~15 lines) left open for triage in §3.

### Benign observations captured in §1b (not findings)

- `.db-wal` + `.db-shm` absent after walk → SQLite clean-shutdown cleanup; WAL was active per DB-header `journal_mode=wal`. Not a bug.
- Android `cmdline-tools` missing on dev host → dev env gap, doesn't affect walk or CI.
- Dart CLI Google Analytics default-on → SDK-level, not project-code; outside CLAUDE.md §Télémétrie scope.
- `Running build hooks...` → expected `build_runner` step for Drift codegen; green.

## User Setup Required

None — runtime walk is local-only, no external services configured.

## Next Phase Readiness

### Unblocked by this plan

- **Plan 04-03 Wave 3 agent spawn** — hard ordering gate from `must_haves.truths[7]` is satisfied: `04-REVIEW.md §1b` committed (`78abe04`) BEFORE any Agent tool call. User-first §1 and runtime-walk §1b both on `main`.
- **Plan 04-03 Task 1 pre-class commit target updated** — must now include FIVE entries not three:
  1. flaky `backup_test.dart::rotate` (from 03-VERIFICATION.md — Blocker)
  2. `custom_lint` silently degraded (from 03-VERIFICATION.md — Noted)
  3. `computeRevealMask` UnimplementedError (from 03-VERIFICATION.md — Should)
  4. Zone mismatch crash at `runApp` on Windows (from §1b runtime walk — Blocker)  ← NEW
  5. sqlite3 CLI pragmas non-authoritative (from §1b runtime walk — Should)  ← NEW

  Plan 04-03 Task 1 should NOT re-extract #4 and #5 from §2 — they are already there, committed by this plan. It should integrate them into its pre-class table directly.

### Blockers / concerns for downstream

- **Zone mismatch Blocker must be triaged in §3.** Ideally fixed in Plan 04-05 atomic fix loop (small `main.dart` edit + re-walk to verify). Alternative: explicit waiver with inline rationale (per CONTEXT.md Blocker-must-be-fix rule, waiver would be out-of-protocol).
- **Should-finding (walk tooling gap) triage is optional.** Either fix in 04-05 (extend `tool/walk_db.dart` to print Drift-side PRAGMAs) or waive (rely on Phase 03 in-process unit tests).
- **Plan 04-02 SC#3 from ROADMAP Phase 04** is NOT formally the plan-02 deliverable per the plan's `requirements` frontmatter, but the runtime walk DOES exercise SC#3 (protocol "user d'abord, titres + explications courtes") since user-first §1 + runtime evidence §1b precede Claude's audit. Flagged for tracing in ROADMAP update.

## Self-Check: PARTIAL

Must-haves verification against `04-02-PLAN.md` `must_haves`:

- [x] **Truth 1: Real file-backed DB opened at least once via `buildAppDatabase` producing observable files** — `mirkfall.db` at 77824 bytes on filesystem, confirmed by walk (b). `.db-wal` + `.db-shm` absent after clean close (SQLite normal behaviour), but WAL persistence at DB level confirmed via `journal_mode=wal`. **MET (with WAL-files-cleaned-up caveat, which is benign).**
- [~] **Truth 2: Output of 6 PRAGMAs captured verbatim into §1b with all expected values** — ARCHIVED verbatim, but only 3 of 6 pragmas authoritative:
  - `user_version=2` ✓ (DB-level, persisted)
  - `journal_mode=wal` ✓ (DB-level, persisted)
  - `page_size=4096` ✓ (DB-level, persisted)
  - `foreign_keys=0` ✗ (CLI default, NOT Drift's applied value — flagged as Should finding)
  - `synchronous=2` ✗ (CLI default, NOT Drift's applied value — flagged as Should finding)
  - `busy_timeout=0` ✗ (CLI default, NOT Drift's applied value — flagged as Should finding)
  **PARTIAL — archival done verbatim (the strict letter of the truth), but 3 per-connection pragmas are caveat-labelled rather than green-asserted. Phase 03 in-process unit tests cover these; walk-tool gap flagged for §3 triage.**
- [x] **Truth 3: `.schema` captured showing all 6 tables** — all 6 tables (`t_sessions`, `t_marker_categories`, `t_markers`, `t_revealed_tiles`, `t_mirk_styles`, `t_photos`) present. **MET (with plan-text-says-`t_photo_refs` flagged as Rule 1 deviation — actual table name is `t_photos`).**
- [x] **Truth 4: `.indexes t_sessions` showing `idx_t_sessions_status_active`** — present. **MET.**
- [x] **Truth 5: Three file sizes captured** — `mirkfall.db` 77824 bytes, `.db-wal` N/A (absent), `.db-shm` N/A (absent) — all three file states observed and archived. Plan's "may be 0-byte if closed cleanly" allowance covers the absent case. **MET.**
- [x] **Truth 6: User explicitly chose walk driver** — user chose (a+b) combined, executed both, pasted both. **MET.**
- [x] **Truth 7: `tool/walk_db.dart` retained OR deleted per user decision logged in SUMMARY** — KEEP decided; logged in Decisions Made. Also kept `tool/inspect_db.sql` (not in original `must_haves` but added via Rule 3). **MET.**
- [x] **Truth 8: §1b committed BEFORE Plan 04-03 Wave 3 agent spawn** — commit `78abe04` on `main`; Plan 04-03 not yet spawned. **MET.**

File artifact checks:

- [x] `.planning/phases/04-review-gate-persistence/04-REVIEW.md` exists with `### 1b. Runtime walk Windows` filled — FOUND (135 lines added).
- [x] `tool/walk_db.dart` exists on `main` with GOSL header — FOUND (69 lines, commits `2c56863` → `c142a8c`).
- [x] `tool/inspect_db.sql` exists on `main` with GOSL header — FOUND (29 lines, commit `259c61e`).
- [x] Commit `78abe04` (`archive runtime walk outputs + escalate findings`) on `main` — FOUND.
- [x] Placeholder `pending — filled by Plan 04-02` no longer appears in `04-REVIEW.md` — CONFIRMED absent.

Key-links checks:

- [x] `tool/walk_db.dart main()` → `buildAppDatabase` via `import 'package:mirkfall/infrastructure/db/app_database_factory.dart';` + direct `buildAppDatabase(...)` call — FOUND.
- [x] sqlite3 CLI outputs → `04-REVIEW.md` §1b verbatim paste — FOUND (5 `<details>` blocks).
- [x] §1b committed → Plan 04-03 Wave 3 spawn trigger — GATE CLEARED (commit `78abe04` predates any Plan 04-03 Task).

**Overall: Self-Check PARTIAL.** Truths 1, 3, 4, 5, 6, 7, 8 fully met. Truth 2 met in letter (verbatim archival done) but 3 of 6 pragmas are non-authoritative CLI readings — caveat flagged in §1b Confirms #6 and escalated as Should finding in §2. This is the most honest signal: the walk DID archive what it was told to archive, but the archival itself surfaced a legitimate tooling gap, which is better than silent green-washing.

---
*Phase: 04-review-gate-persistence*
*Plan: 02*
*Completed: 2026-04-18*

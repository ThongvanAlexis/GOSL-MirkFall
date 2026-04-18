# Phase 04: Review Gate — Persistence - Research

**Researched:** 2026-04-18
**Domain:** Review-gate pattern adapted to persistence/domain concerns — 5-section REVIEW.md artefact, 4-parallel sub-agent audit, adversarial stress-tests (2 CI branches + 1 permanent unit test), runtime walk Windows, atomic fix loop
**Confidence:** HIGH (Phase 02 established and validated the entire mechanical pattern; Phase 04 is mostly "same recipe with persistence-shaped ingredients")

## Summary

Phase 04 is a near-carbon-copy structural reuse of Phase 02 Review Gate Foundation, with three concrete adaptations driven by the shift from "scaffold/CI guardrails" (Phase 01's domain) to "persistence + domain purity + runtime filesystem" (Phase 03's domain):

1. **A dedicated runtime walk plan is inserted BETWEEN §1 user capture and §2 agent audit.** Phase 02 folded its Windows walk into Agent #2 (bootstrap runtime). Phase 04 promotes it to a standalone plan because `buildAppDatabase` against a real filesystem is the single most under-exercised code path of Phase 03 (all 64 infrastructure tests used `NativeDatabase.memory()` or tempdirs). The walk feeds observable PRAGMA/schema/index evidence into §1b before the four agents have a chance to bias themselves with any particular frame.
2. **The adversarial wave mixes 2 throwaway-branch CI tests with 1 permanent unit test** instead of Phase 02's 3-throwaway-branch uniformity. `check_domain_purity.dart` and the drift schema dump guard are script-level CI gates (poisoner-friendly → throwaway branch); `SchemaSanityChecker` is runtime code → a permanent `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` regression test. The CONTEXT explicitly sanctions this split.
3. **Three candidates are pre-classified in §2 before the four agents spawn**, coming from `03-VERIFICATION.md §Outstanding minor items`: flaky `backup_test.dart::rotate` (Blocker), `custom_lint` silently degraded under analyzer-10 (Noted), `computeRevealMask` UnimplementedError (Should). This saves a full cycle of duplicate discovery across the four agents and lets their attention go to blind-spot adjacencies instead of known debris.

**Primary recommendation:** 5 plans across 5 waves. Wave 1 = scaffold + §1 capture (mirrors 02-01). Wave 2 = runtime walk Windows dedicated plan (new). Wave 3 = 4-agent parallel audit + user triage (mirrors 02-02, adapted slicing). Wave 4 = adversarial evidence (2 CI branches + 1 permanent test, adapted 02-03). Wave 5 = atomic fix loop + closure (mirrors 02-04). All four agents stay `general-purpose` per Phase 02 precedent. The pattern's 42-finding load was sustained in Phase 02; Phase 03 ships ~40 `.dart` + ~25 tests + 6 fixtures + 3 schema dumps, so comparable audit surface is expected.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Sub-agent slicing: 4 agents by layer technique, spawned in a SINGLE tool-use message (parallel).**

- **Agent #1 — Schema + migrations + backup**
  - `lib/infrastructure/db/app_database.dart` (Drift schema, 6 tables, FK CASCADE, partial unique index `idx_t_sessions_status_active`, BLOB MIRK-03, schemaVersion=2, MigrationStrategy)
  - `lib/infrastructure/db/migrations/v1_to_v2_notes.dart` (ALTER raw `customStatement`)
  - `lib/infrastructure/db/backup.dart` + `lib/infrastructure/db/schema_sanity.dart` + `lib/infrastructure/db/app_database_factory.dart` + `lib/infrastructure/db/pragma_setup.dart` + `lib/infrastructure/db/type_converters.dart`
  - `drift_schemas/drift_schema_v{1,2,_current}.json` (frozen snapshots vs rolling)
  - `test/infrastructure/db/**` (~13 test files)
  - Pragma wiring (WAL via NativeDatabase setup, FK + busy_timeout + synchronous via beforeOpen)

- **Agent #2 — Domain models + pureté**
  - `lib/domain/**` (entities Freezed, sealed `MirkStyleConfig` + `UnknownConfig` fallback, `@Assert` invariants, errors taxonomy, ports stores)
  - Zero `import 'package:flutter/'` or `import 'package:drift/'`, zero `is`-chains, zero `dynamic` non documenté, zero singleton global caché
  - Extension type IDs (6 types) + ULID + IdGenerator seam
  - Envelope `{schemaVersion, type, payload}` + JsonMigrator framework + IdentityMigrationV1 + V1ToV2RenameRadius
  - `test/domain/**` (~10 test files)

- **Agent #3 — Store layer + factory + providers**
  - `lib/infrastructure/stores/drift_*_store.dart` (5 stores : SessionStore SqliteException 2067 wrap scope, RevealedTileStore transactional mergeMask, MarkerCategoryStore reassign-to-default, MarkerStore, MirkStyleStore) + `lib/infrastructure/stores/sqlite_error_mapper.dart`
  - Aucune fuite Drift dans les couches supérieures, transactions correctes pour multi-write, FK CASCADE comportement réel (pas juste schéma)
  - `lib/application/providers/*_store_provider.dart` (7 providers @Riverpod keepAlive=true) + `lib/infrastructure/ids/random_id_generator.dart` + `seeded_id_generator.dart` + `lib/infrastructure/ids/ulid.dart`
  - `test/infrastructure/stores/**` (~6 test files) + `test/infrastructure/ids/**` (3 test files)

- **Agent #4 — Tests + fixtures + tooling + CLAUDE.md sweep**
  - Qualité tests : assertions réelles vs placebo, mock correctness, `@Tags(['migration'])` discipline, `dart_test.yaml`
  - `test/fixtures/` (drift_schemas/, json/v{1,2}, db_seed/v1_baseline.sql 70 rows, mirk_style_unknown_renderer.json)
  - `tool/check_domain_purity.dart` + `tool/test/check_domain_purity_test.dart`
  - `pubspec.yaml` deltas Phase 03 (drift, drift_flutter, sqlite3_flutter_libs, freezed, json_serializable, build_runner, custom_lint, riverpod_lint, riverpod_generator) + `dependency_overrides analyzer ^10.0.0 + dart_style 3.1.7`
  - `analysis_options.yaml` (custom_lint plugin)
  - CLAUDE.md anti-patterns sweep sur tout le code Phase 03
  - `lib/config/constants.dart` deltas (`kDbFilename`, `kDbBackupDirName`, `kMaxDbBackups`, `kDbBusyTimeoutMs`)
  - `DEPENDENCIES.md` spot-check des entrées Phase 03 ajoutées

**Ordering: STRICT user-first protocol.** User IDE findings → §1 capture + commit → runtime walk Windows (dedicated plan) → 4 sub-agents in ONE tool-use message → §2 synthesis → §3 user triage. Parallèle user/agents EXPLICITLY rejected. Non-négociable.

**Runtime walk: DEDICATED plan, before agents.**
- Not an agent (general-purpose has trouble piloting long-lived `flutter run`)
- Not user-manual-alone (Claude prepares script + archives result)
- Plan autonomous=false; Claude posts the script, user runs `flutter run -d windows` + sqlite3 CLI queries, pastes output, Claude archives into `04-REVIEW.md §1b`

**Runtime walk scope:**
- `flutter run -d windows` (kill after observations)
- Verify `<app_support>/mirkfall.db` + `mirkfall.db-wal` + `mirkfall.db-shm` exist (WAL proof)
- `sqlite3 <path>` → `.schema` (6 tables), `PRAGMA user_version;` (=2), `PRAGMA journal_mode;` (=wal), `PRAGMA foreign_keys;` (=1), `PRAGMA synchronous;` (=1 NORMAL), `PRAGMA busy_timeout;` (=5000), `.indexes t_sessions` (contains `idx_t_sessions_status_active`)
- NO UI walk (ProviderScope wiring deferred to Phase 05 per 03-CONTEXT — nothing observable on screen)

**Adversarial tests: 3 stress-tests (2 throwaway CI branches + 1 permanent unit test).**
- **Test #1 — `adversarial/04-domain-import-flutter-and-drift`**: add `import 'package:flutter/material.dart';` to `lib/domain/sessions/session.dart` AND `import 'package:drift/drift.dart';` to `lib/domain/markers/marker.dart` (ONE branch, TWO violations). CI step `dart run tool/check_domain_purity.dart` must fail with exit 1, stderr listing BOTH violations (proves check doesn't stop at first).
- **Test #2 — `adversarial/04-schema-drift-stale`**: add `TextColumn get notesExtra => text().nullable()();` to `t_sessions` in `app_database.dart`, run `dart run build_runner build --delete-conflicting-outputs` (regenerate `.g.dart`), but DO NOT run `dart run drift_dev schema dump ...`. Push → CI step "Check drift schema (current) is committed and fresh" must fail with `git diff --exit-code drift_schemas/drift_schema_current.json` showing drift.
- **Test #3 — `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart`** (PERMANENT, NOT a throwaway branch). Unit test: inject V1 fixture (70 rows) → run adversarial migration that does `ALTER TABLE` + `DELETE FROM t_sessions WHERE rowid % 2 = 0` (loses ~50% of sessions) → assert `SchemaSanityChecker.assertNoLoss` throws `MigrationFailureException` with exact row-count diff. Evidence = commit hash + green `dart test` output.

**Pre-classification of 3 VERIFICATION candidates in §2 BEFORE spawn agents:**
- **Flaky `backup_test.dart::rotate keeps the 3 newest when 4 exist`** → Blocker. Fix = `Future.delayed(10ms)` between consecutive backup file creations, OR sort by filename (contains ms timestamp) instead of mtime. If audit reveals `DbBackupService.rotate` runtime also depends on mtime, ESCALATE to Blocker runtime + Blocker test.
- **`custom_lint` silently degraded (analyzer-10 API rename `Element2` breaks `custom_lint_core` 0.8.1)** → Noted. Document in STATE.md Accumulated Decisions + new line/column in DEPENDENCIES.md. Re-verification task at each deps bump + Phase 15 latest.
- **`computeRevealMask` throws `UnimplementedError`** (Phase 09 scope) → Should. Add test guard `test/domain/compute_reveal_mask_no_callers_test.dart` that scans `.dart` files outside `lib/domain/revealed/reveal_calculator.dart` and fails if `computeRevealMask` is called elsewhere. Test = permanent guard until Phase 09 implements + removes.

**Atomic commit discipline:** `fix(04-rev): <title>` | `refactor(04-rev):` | `docs(04-rev):` | `test(04-rev):` — one finding per commit. Each commit CI-green before next. `docs(04-rev):` excluded from fix-tally grep.

**Gate-closed criteria:**
- All Blockers fixed (waiver forbidden)
- All Shoulds fixed OR explicitly waived with inline rationale in §3
- CI green on final `main` commit (3 jobs: gates / android / ios)
- `04-REVIEW.md` 5 sections filled + `**Status:** closed` + `**Closed:** <date>`
- Runtime walk evidence in §1b
- 2 adversarial CI run URLs in §4 + test #3 commit hash in §4
- `adversarial/04-*` branches deleted local + remote
- STATE.md + ROADMAP.md updated

**Adversarial branch discipline:** throwaway branches from `main`, push, observe CI to failure, capture URL + stderr excerpt, delete branch local + remote. NO PRs. Sequencing free (parallel or sequential, planner's call based on CI runner load).

### Claude's Discretion

- **Wave layout exact** (combien de plans, scaffold/walk/agents/adversarial/fixes) — free to arbitrate, but runtime walk MUST be a separate plan BEFORE the agents
- **Order of the 2 adversarial CI branches** (parallel vs sequential)
- **Format of runtime walk evidence** inline in REVIEW.md (collapsed `<details>` vs flat list)
- **Internal découpage of Agent #4** (CLAUDE.md anti-patterns sweep: combined pass or per-pattern pass)
- **Choice of fictive column name** in adversarial #2 (`notesExtra` suggested, any name works as long as schema dump diff is observable)
- **Cleanup strategy for adversarial branches** (delete immediately after archiving vs batch at end of Plan 04-04)
- **Exact format of `compute_reveal_mask_no_callers_test.dart`** (`Process.run('rg', ...)` vs pure Dart File + regex read)
- **DEPENDENCIES.md format** for documenting `custom_lint` silent-degraded (inline comment vs extra column vs table footnote)
- **Re-verification depth** that `DbBackupService.rotate` runtime doesn't depend on mtime (if yes, escalate flaky to Blocker runtime + Blocker test)

### Deferred Ideas (OUT OF SCOPE)

- Pre-commit hooks (lefthook or similar) — rejected Phase 01, stays rejected Phase 02 + 04
- Persistent adversarial matrix in `ci.yml` (matrix job replaying 5 known-bad tests at each push) — considered, not retained, deferred maybe Phase 16
- Exhaustive `pubspec.lock` re-audit (175+ entries) — replaced by Agent #4 spot-check of Phase 03 deltas
- Automation of Could / Noted fixes — Coulds triaged `defer-to-phase-15-polish`, Noteds feed `deferred` of future phases
- Stress-test report as separate permanent artefact (`docs/guardrail-stress-tests.md`) — not retained; evidence lives in per-phase REVIEW.md
- Deep investigation of `DbBackupService.rotate` runtime mtime-dependence as separate plan — done inside Blocker #1 fix scope
- Replacing `custom_lint` with alternative (`lint_lab`, `dart_code_metrics`) — overkill V1.0, dedicated phase if needed
- Re-pinning analyzer downgrade to restore `custom_lint` — drift_dev 2.32.1 requires analyzer ^10, so downgrade = Phase 03 broken. Not viable.
- MPL-unreachable heuristic fix in `tool/check_licenses.dart` — Phase 02 backlog (4th Blocker not covered by Phase 02 adversarial)
- `ProviderScope` wiring of `AppDatabase` in `lib/main.dart` — explicitly deferred Phase 05 by 03-CONTEXT
- UI debug menu walk — no ProviderScope = no UI wired; "Backup DB now" debug button not delivered = finding `Should` if Agent #1 surfaces it, not a walk extension
- Test guard pattern reusable for future `UnimplementedError` — 1-shot for Phase 04; promote if Phase 09/11 require similar
- Rotation backups by age — Phase 15
- Soft-delete / undo / trash — post-V1
</user_constraints>

<phase_requirements>
## Phase Requirements

No phase requirement IDs are mapped to Phase 04. Review gates (even-numbered phases) verify requirements of the preceding code phase but do not own any REQ-ID themselves. Phase 04 specifically audits SESS-06 + MIRK-03 (Phase 03's two REQ-IDs) as part of the broader audit, but success is measured against the 4 ROADMAP success criteria, not a requirement checklist.

| Concern | ROADMAP Success Criterion | Research Support |
|---------|---------------------------|------------------|
| Migration framework actually works | SC#1: "Une migration V1→V2 fictive est écrite en test pour valider que le framework fonctionne réellement" | Phase 03 already ships `V1ToV2Notes` + fixture-driven `migration_v1_to_v2_test.dart` (70 rows). Agent #1 audits; Test #3 adds row-loss regression guard. |
| Domain purity + polymorphism | SC#2: "Les `is` chains sont absents dans le domaine ; aucun `dynamic` non documenté ; aucun singleton global" | Agent #2 scope. `tool/check_domain_purity.dart` already enforces import purity; Agent #2 adds human-level polymorphism + `dynamic` + singleton sweep. Adversarial Test #1 stress-tests the tool. |
| Review protocol applied | SC#3: "Le protocole review (user d'abord, puis titres + explications courtes) est appliqué" | Plan 04-01 Task 2 (user-first §1 capture) + Plan 04-03 Task 2 (titles-only triage) — mirrors 02-01 / 02-02. |
| Fixes integrated, tests green | SC#4: "Les corrections choisies sont intégrées et les tests de persistance restent verts avant ouverture de la Phase 05" | Plan 04-05 atomic CI-gated fix loop — mirrors 02-04. |
</phase_requirements>

## Standard Stack

No new libraries introduced by Phase 04 (a review gate consumes existing artefacts; it doesn't add deps). What matters is the tooling Phase 04 EXERCISES.

### Core Tools Consumed (audit surface)
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Drift | 2.32.1 | ORM under audit (schemas, migrations, stores) | Phase 03 locked; adversarial #2 stress-tests schema dump guard |
| drift_dev | 2.32.1 | schema dump CLI | `dart run drift_dev schema dump` is the CI guard adversary #2 targets |
| Freezed | 3.2.5 | Immutable entities in `lib/domain/**` | Agent #2 audits generated code vs hand-written invariants |
| Riverpod + riverpod_generator | 3.x / 4.0.3 | 7 `@riverpod` providers in `lib/application/providers/` | Agent #3 audits keepAlive + provider seams |
| `gh` CLI | installed, authenticated | `gh run list`, `gh run view --log-failed`, `gh run watch`, `gh api repos/:owner/:repo/branches` | Adversarial CI tests poll + capture run IDs with `gh` — same as Phase 02 pattern |
| `sqlite3` CLI | Windows-native | Runtime walk: `.schema`, `PRAGMA *`, `.indexes t_sessions` | Only way to observe the real file-backed DB post-`flutter run -d windows` |
| `rg` (ripgrep) | bundled with git-bash | Optional for test #Should `compute_reveal_mask_no_callers_test.dart` | Pure Dart `File + regex` is the zero-dep alternative |
| `dart test` / `flutter test` | 3.41.5 | Unit + widget tests; Phase 03 uses both (pure-Dart subdirs + Flutter root-level) | Phase 03's `dart_test.yaml` tags (`@Tags(['migration'])`) gate the slow migration suite |

### Supporting Tools (process-level)
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `git branch -D` / `git push origin --delete` | Adversarial branch cleanup | After CI run captured (Tests #1 #2) |
| `flutter run -d windows` | Runtime walk Windows executable | Plan 04-02 only (user-run, Claude-guided) |
| `dart format --line-length 160 --set-exit-if-changed` | Pre-commit local gate | Every fix commit; mandatory per CI ordering |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `gh run watch` polling | Manual GitHub UI refresh | Polling = scriptable + faster feedback; UI = human verification. Use `gh run watch --exit-status` for reliability. |
| `sqlite3` CLI for runtime walk | Drift itself in a tiny Dart script | CLI is simpler for PRAGMA observation + no extra boilerplate; Dart would need to re-open DB with correct pragmas (potentially masking PRAGMA bugs the walk is trying to catch). CLI recommended. |
| Single combined Agent #4 pass | Per-anti-pattern Agent #4 sub-pass | Combined pass matches Phase 02 precedent and 4-agent parallelism budget; per-pattern subdivides into 5-6 mini-agents and blows parallelism wall-clock. Combined recommended. |

**Installation:** No new installs. Tooling already in place after Phase 03 (verified against `pubspec.yaml` + `pubspec.lock`). Confirm:
```bash
which gh sqlite3 rg  # should all resolve
dart --version       # 3.5.x+
flutter --version    # 3.41.5
```

## Architecture Patterns

### Recommended Wave Decomposition (5 plans, 5 waves)

```
Wave 1 — Plan 04-01: Scaffold + §1 user capture
  ├─ Task 1: Create 04-REVIEW.md 5-section skeleton (+ §1b sub-section for runtime walk)
  └─ Task 2 (blocking checkpoint): Solicit user IDE findings → capture §1 verbatim → commit

Wave 2 — Plan 04-02: Runtime walk Windows (dedicated plan, BEFORE agents)
  ├─ Task 1: Prepare walk script (documented commands for flutter run -d windows + sqlite3 queries)
  ├─ Task 2 (blocking checkpoint): User runs script on Windows, pastes outputs in chat
  └─ Task 3: Claude archives evidence into §1b + commits

Wave 3 — Plan 04-03: Pre-class + 4 parallel sub-agent audit + user triage
  ├─ Task 1: Write the 3 pre-classified candidates into §2 under "Pre-known from VERIFICATION"
  ├─ Task 2: Spawn 4 sub-agents in ONE tool-use message; consolidate findings into §2 by agent-slice
  ├─ Task 3 (blocking checkpoint): Present titles + 1-line explanations to user; capture triage into §3
  └─ Task 4: Write 04-03-SUMMARY.md + carry adversarial poison recipes forward

Wave 4 — Plan 04-04: Adversarial wave (2 CI branches + 1 permanent unit test)
  ├─ Task 1: Test #1 — adversarial/04-domain-import-flutter-and-drift (2 violations, 1 branch)
  ├─ Task 2: Test #2 — adversarial/04-schema-drift-stale (notesExtra column without dump)
  ├─ Task 3: Test #3 — PERMANENT migration_v1_to_v2_data_loss_test.dart (row-loss regression guard)
  └─ Task 4: Verify no adversarial/04-* branches remain local or remote; commit §4 evidence

Wave 5 — Plan 04-05: Atomic fix loop + closure
  ├─ Task 1: Snapshot fix count → apply every §3 fix-triaged finding as atomic commit, CI-gated
  └─ Task 2 (blocking checkpoint): §5 CI-green confirmation + status=closed + STATE.md/ROADMAP.md + user "OK close"
```

| Wave | Plan | Depends On | Autonomous | Rationale |
|------|------|------------|------------|-----------|
| 1 | 04-01 | — | false (checkpoint on user) | Scaffold must happen before anything else; §1 user-first is non-negotiable protocol gate |
| 2 | 04-02 | 04-01 | false (checkpoint on user) | Runtime walk requires `flutter run -d windows` on user's machine; Claude can't drive long-lived processes |
| 3 | 04-03 | 04-02 | false (checkpoint on user for triage) | Agents spawn once §1 + §1b are committed (hard ordering gate); triage checkpoint mirrors 02-02 Task 2 |
| 4 | 04-04 | 04-03 | true (autonomous — gh CLI + dart test) | Adversarial tests are scripted; no user interaction beyond CI runs observability. Matches 02-03 `autonomous: true`. |
| 5 | 04-05 | 04-03 + 04-04 | false (checkpoint for "OK close") | Fix loop runs autonomously per finding; final closure is user approval gate |

### Pattern 1: 5-section REVIEW.md contract (locked Phase 02)

**What:** Artifact spec that `gsd-verifier` greps via `^## [1-5]\.` to confirm all sections present.

**When to use:** Every review gate phase (04, 06, 08, 10, 12, 14, 16).

**Example (from `02-REVIEW.md`, adapted):**
```markdown
# Phase 04: Review Gate — Persistence Review

**Opened:** 2026-04-18
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude's audit.*

(awaiting user input — Plan 04-01 Task 2 fills this section)

### 1b. Runtime walk Windows

*Captured by Plan 04-02 Task 3 after flutter run -d windows + sqlite3 CLI observations.*

<details>
<summary>PRAGMA + schema + index dumps</summary>
(pending — filled by Plan 04-02)
</details>

## 2. Claude audit findings

*Pre-classified VERIFICATION candidates and structured findings from the 4 parallel sub-agents.*

### Pre-known from VERIFICATION
(3 candidates: flaky backup rotate Blocker | custom_lint silently degraded Noted | computeRevealMask UnimplementedError Should)

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
...
## 4. Adversarial evidence
### Test 1: Domain purity import violation (Flutter + Drift)
(pending)
### Test 2: Drift schema dump stale
(pending)
### Test 3: SchemaSanityChecker row-loss detection (permanent unit test)
(pending)
## 5. CI-green confirmation
...
```

### Pattern 2: 4-parallel sub-agent spawn (ONE tool-use message)

**What:** Claude-main issues exactly ONE tool-use message containing 4 Agent tool calls. All 4 agents return in parallel wall-clock time.

**When to use:** Every review-gate audit wave (verified in Phase 02 — 54 findings / one slot).

**Example (schematic):**
```typescript
// Single message, 4 parallel tool calls
<tool_calls>
  <Agent agent_type="general-purpose" scope="Agent #1: Schema + migrations + backup" ... />
  <Agent agent_type="general-purpose" scope="Agent #2: Domain models + pureté" ... />
  <Agent agent_type="general-purpose" scope="Agent #3: Store layer + factory + providers" ... />
  <Agent agent_type="general-purpose" scope="Agent #4: Tests + fixtures + tooling + CLAUDE.md sweep" ... />
</tool_calls>
```

**Non-negotiable rule:** All 4 agents MUST be `general-purpose` per Phase 02 Accumulated Decision (STATE.md):
> "All 4 audit agents set to `general-purpose` for wave consistency — even the read-only Agent #3 (code sweep) which could have been `Explore` was kept `general-purpose` so future review gates have a predictable agent-type rule."

### Pattern 3: Adversarial branch lifecycle (throwaway + permanent split)

**What (for CI tests #1 #2):**
```bash
git checkout main && git pull
git checkout -b adversarial/04-<name>
# apply poison (+ flutter pub get / build_runner if needed)
git add <files> && git commit -m "test(adversarial): <description>"
git push -u origin adversarial/04-<name>
RUN_ID=$(gh run list --branch adversarial/04-<name> --limit 1 --json databaseId --jq '.[0].databaseId')
# wait for completion
gh run view $RUN_ID --log-failed | grep -B2 -A10 "<gate name>"
# archive evidence in §4
git checkout main
git branch -D adversarial/04-<name>
git push origin --delete adversarial/04-<name>
```

**What (for permanent test #3):**
- Write `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` on `main` directly
- Commit with `test(04-rev): add SchemaSanityChecker row-loss regression guard`
- Evidence in §4 = commit hash + green `dart test` output (not a CI run URL because permanent code lives on `main`)
- File stays forever as regression guard

**When to use:** Every review gate when guard-tool coverage + runtime regression both need proof.

### Anti-Patterns to Avoid

- **Spawning 4 agents in 4 separate messages** — loses wall-clock parallelism (Phase 02 Anti-Pattern documented)
- **Presenting findings to user as diffs/code-blocks** — violates CLAUDE.md §Code Review Phases "titres + explication courte" contract
- **Deduplicating same-line findings across agents** — preserves same-line multi-agent finding with explicit cross-reference (Phase 02 decision: "Cross-lens finding overlap handling convention")
- **Waiver on a Blocker** — explicitly forbidden; if user tries, Claude pushes back and asks to reclassify to Should or accept fix
- **Batching multiple findings into one fix commit** — violates atomic commit discipline + breaks bisect/revert per-finding
- **Running adversarial test WITHOUT `flutter pub get`/`build_runner build` prerequisite** — produces exit-2 misconfig instead of exit-1 policy violation → invalid evidence (Phase 02 RESEARCH Pitfall 2, re-applies to Test #2 build_runner requirement)
- **Conflating `docs(04-rev):` with `fix(04-rev):`** — Phase 02 fix-tally grep excludes docs commits; Phase 04 must do the same (`.fixes-expected` snapshot before mutation)
- **Mutating §3 rows during Task 1 execution without snapshot** — live grep drifts; snapshot fix count once at start (Phase 02 Plan 04 pattern)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Review gate workflow for Phase 04 | Custom phase runbook | Phase 02 5-plan template (02-01..02-04) with 5 waves (adding 04-02 runtime walk) | Phase 02 validated the entire mechanical flow — 54 findings, 42 atomic fixes, 307 min wall-clock. Re-deriving = weeks. |
| 5-section REVIEW.md | Custom section layout | Exact Phase 02 skeleton (§1 user / §2 audit / §3 triage / §4 adversarial / §5 CI-green) + new `§1b Runtime walk` sub-section | `gsd-verifier` contract (grep `^## [1-5]\.`). Break = verifier fails. |
| Adversarial CI test lifecycle | Custom harness | Phase 02 throwaway-branch recipe: `git checkout -b adversarial/04-*` → push → `gh run list/view` → delete local + remote | `gh` CLI is installed + authenticated; Phase 02 precedent complete. |
| sqlite3 observation of real DB | Custom Dart script opening the DB with `sqlite_async` | `sqlite3 <path>` CLI + `.schema` / `PRAGMA *` / `.indexes t_sessions` | CLI is dependency-free, doesn't mask PRAGMA bugs by re-opening with "correct" pragmas. |
| Atomic commit fix loop with CI gate | Custom CI-polling harness | `gh run watch --exit-status` + per-commit loop | Phase 02 42-commit loop ran 307 min green first-try every time. |
| `fix vs docs` commit counting | `grep ^fix(04-rev):` live | `.fixes-expected` snapshot file (integer count captured BEFORE mutation) | Phase 02 precedent: live grep drifts because §3 rows mutate from `| fix |` to `| fix (done <hash>) |` during execution. |
| Domain purity runtime check | Custom import walker in agent | Existing `tool/check_domain_purity.dart` — audit it, stress-test it, don't replace it | Phase 03 Plan 03-01 already shipped + tested the tool. Phase 04 validates, doesn't rebuild. |
| Schema drift detection | Custom diff script | Existing `git diff --exit-code drift_schemas/drift_schema_current.json` CI step + adversarial Test #2 | Phase 03 Plan 03-04 shipped; CI job "Check drift schema (current) is committed and fresh" exists since then. |
| Row-loss migration detection | Custom row count diff lib | Existing `SchemaSanityChecker.assertNoLoss` (throws `MigrationFailureException`) | Phase 03 Plan 03-05 shipped. Test #3 exercises it adversarially as regression guard. |

**Key insight:** Phase 04 builds ALMOST NOTHING. It audits, stresses, and captures. The only NEW files expected:
- `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` (Test #3, permanent)
- `test/domain/compute_reveal_mask_no_callers_test.dart` (Should #3, permanent until Phase 09)
- `04-REVIEW.md` (artifact)
- 5 summary files (`04-01..04-05-SUMMARY.md`)
- Possibly 1-20 small fix files depending on §3 triage outcomes (changes to existing files in `lib/infrastructure/db/**`, `lib/domain/**`, `lib/infrastructure/stores/**`, `test/**`, etc.)

## Common Pitfalls

### Pitfall 1: Test #2 needs `build_runner build` before `git push`
**What goes wrong:** Adversarial Test #2 adds a new `TextColumn get notesExtra => text().nullable()();` column to `app_database.dart`. Without running `dart run build_runner build --delete-conflicting-outputs` locally, `app_database.g.dart` is stale, `flutter analyze` fails BEFORE the drift schema dump guard, evidence proves the wrong gate.
**Why it happens:** Drift uses codegen for `.g.dart`; column additions require regeneration.
**How to avoid:** Plan 04-04 Task 2 MUST include `dart run build_runner build --delete-conflicting-outputs` explicitly AFTER the column edit and BEFORE the commit. Verify by `flutter analyze --fatal-infos --fatal-warnings` locally — must pass — THEN push.
**Warning signs:** CI fails on "Flutter analyze" step (line 57 of `ci.yml`) instead of "Check drift schema (current) is committed and fresh" (line 90) → evidence invalid, redo.

### Pitfall 2: `<app_support>/mirkfall.db` path may not match on Windows
**What goes wrong:** Runtime walk instructions assume `<app_support>` resolves to a known location, but on Windows it's `%APPDATA%\com.example\mirkfall\` or similar per Flutter's `path_provider`. User spins on "where is the DB?"
**Why it happens:** `path_provider.getApplicationSupportDirectory()` returns a platform-specific, bundle-ID-dependent path. Phase 03 uses the default bundle ID `com.example` (Phase 01 scaffold), so the path is predictable but not well-documented.
**How to avoid:** Plan 04-02 Task 1 script must include a way to print the resolved path. Options: (a) temporarily add a `log.info('DB opened at: ${dbFile.path}')` inside `buildAppDatabase` before the walk and revert after (annoying), OR (b) instruct user to run `where /r %APPDATA% mirkfall.db` after the flutter run kills (cleanest). Recommended: (b).
**Warning signs:** User reports "no mirkfall.db found" — verify Flutter actually ran (check log output for `buildAppDatabase` invocation), check bundle ID, check the `getApplicationSupportDirectory` platform stub for Windows.

### Pitfall 3: `flutter run -d windows` does NOT open the DB if nothing consumes it
**What goes wrong:** Phase 03 ships `AppDatabase` + `buildAppDatabase` + all 7 Riverpod providers, but `main.dart` does NOT wire `ProviderScope` to consume any of them (explicitly deferred to Phase 05 per 03-CONTEXT). A `flutter run -d windows` that just paints `PlaceholderHomeScreen` never triggers `buildAppDatabase`.
**Why it happens:** Riverpod is lazy — providers instantiate only on first `ref.watch`/`ref.read`. No consumer → no DB open.
**How to avoid:** Plan 04-02 Task 1 script must include a temporary consumer. Options:
 - (a) Add a tiny `main.dart` branch: `if (bool.fromEnvironment('WALK_DB')) { await buildAppDatabase(); }` — invoked via `flutter run -d windows --dart-define=WALK_DB=true`. Revert after walk.
 - (b) Add a one-off `tool/walk_db.dart` that invokes `buildAppDatabase()` and prints the path + shuts down. Simpler, no UI involvement.
 - (c) Let the runtime walk instead be "Claude writes `tool/walk_db.dart`, user runs `dart run tool/walk_db.dart`, we observe" — MUCH simpler than `flutter run -d windows` and doesn't need UI at all.
**Recommendation (STRONG):** Option (c). `flutter run -d windows` is overkill for data-only Phase 03. CONTEXT says "Runtime walk Windows" but the intent is "open the DB against a real filesystem" — `dart run tool/walk_db.dart` satisfies that AND avoids Windows UI friction. Document this deviation in 04-02-PLAN.md.
**Warning signs:** User says "app opened, nothing happened, no DB file" → you just proved (a) Flutter runs fine, (b) no consumer, (c) the walk is not exercising what it was supposed to.

### Pitfall 4: 4 agents in parallel saturate Windows file IO
**What goes wrong:** Four `general-purpose` agents all reading `lib/**` + `test/**` simultaneously on Windows. Phase 02 sustained this (54 findings, wall-clock not unreasonable); Phase 03 codebase is ~2× larger (~40 `.dart` + ~25 tests + 6 fixtures + 3 schema dumps vs Phase 01's smaller surface).
**Why it happens:** Windows file IO is slower than Linux/macOS for cold-cache reads; agents may contend on `.dart_tool/` caches.
**How to avoid:** Monitor wall-clock of 02-02 audit (Phase 02 took 25 min per STATE.md Phase 02 P02). If Phase 04 Plan 04-03 exceeds 40 min, flag for investigation. Fallback: serialize agents (1-by-1 instead of parallel) — loses wall-clock advantage but robust.
**Warning signs:** Agent returns with "File read timeout" or file listings incomplete → cache contention, serialize.

### Pitfall 5: `gh run watch` timeout short for adversarial runs
**What goes wrong:** `gh run watch` has no explicit timeout by default but will exit on network blip. For adversarial branches, the CI `gates` job runs ~5-10 min (with test suite); Android build ~15 min; iOS ~20 min. If watching without `--exit-status`, a transient network issue kills the watch without conclusion.
**Why it happens:** `gh run watch` default behavior assumes short-lived runs.
**How to avoid:** Use `gh run watch --exit-status` (blocks until completion + inherits exit code) + poll `gh run view $RUN_ID --json status,conclusion --jq '.'` if watch drops. Phase 02 used `gh run watch` successfully per 02-04-SUMMARY — no reported timeout issue, but Phase 04 should still use `--exit-status` defensively.
**Warning signs:** `gh run watch` returns without printing conclusion → re-query via `gh run view`.

### Pitfall 6: `custom_lint` silently degraded — agent #2 might flag it anew
**What goes wrong:** Agent #2 (domain purity) runs `flutter analyze --fatal-infos --fatal-warnings`. Since `custom_lint` silently fails to load its plugin under analyzer-10, the analyzer passes green WITHOUT custom-lint rules. Agent #2 could mistake this for "custom lints pass" — it's actually "custom lints don't run at all". Without pre-classification, Agent #2 re-flags this as a Blocker despite STATE.md documenting it as accepted trade-off.
**Why it happens:** `flutter analyze` output doesn't show that `custom_lint` plugin failed to load — degradation is silent by design of the analyzer-plugin contract.
**How to avoid:** Pre-classify in §2 BEFORE spawn agents (CONTEXT.md decision). Agent #2 is briefed that this is a known-accepted Noted and not to re-flag. Agent #2 should still VERIFY (e.g., by running `dart run custom_lint` directly and noting the plugin error) to confirm the silent-degrade state has not changed.
**Warning signs:** Agent #2 returns with a Blocker "custom_lint not running" — reclassify as Noted cross-ref to pre-class.

### Pitfall 7: `DbBackupService.rotate` runtime mtime-dependence (escalation risk)
**What goes wrong:** Flaky `backup_test.dart::rotate keeps the 3 newest when 4 exist` is currently pre-classified as Blocker with a test-only fix (`Future.delayed(10ms)` or sort by filename). If Agent #1 audit reveals the PRODUCTION `DbBackupService.rotate` code ALSO uses `File.lastModifiedSync()` mtime instead of filename-ms-timestamp sort, the bug is runtime-level, not test-level. Fix = rewrite `rotate` to sort by filename (which contains `_hhmm.ss_` timestamp) + rewrite test accordingly. Escalation to Blocker runtime + Blocker test.
**Why it happens:** mtime resolution on Windows FAT/NTFS is ~10ms; rotate logic assuming monotonic mtime for files created microseconds apart is inherently flaky on Windows.
**How to avoid:** Agent #1 specifically audits `lib/infrastructure/db/backup.dart` for any `lastModified*` calls in ordering-sensitive code paths. If found, escalate. Plan 04-03 sub-agent scope explicitly mentions this per CONTEXT §Claude's Discretion.
**Warning signs:** Agent #1 finds `File.lastModifiedSync()` in `DbBackupService.rotate` → escalate now, don't wait.

### Pitfall 8: No existing `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` — must be built fresh
**What goes wrong:** CONTEXT describes Test #3 but the file doesn't exist. Must be written from scratch using Drift's `SchemaVerifier` pattern (already used in `migration_v1_to_v2_test.dart`). If reuse cut-and-paste pattern is sloppy, test may pass even without `SchemaSanityChecker.assertNoLoss` triggering (false-positive).
**Why it happens:** Adversarial tests are high-stakes because they prove a safeguard fires; a false-pass is worse than nothing.
**How to avoid:** Plan 04-04 Task 3 explicitly uses `SchemaVerifier` + a custom `Migrator` step that does `await m.customStatement('DELETE FROM t_sessions WHERE rowid % 2 = 0')` AFTER the schema ALTER. Assertion uses `expect(..., throwsA(isA<MigrationFailureException>()))` with the exact row-count diff as expected. Reference implementation: examine `test/infrastructure/db/schema_sanity_test.dart` which already tests `assertNoLoss` — Test #3 is an ADVERSARIAL integration version of that.
**Warning signs:** Test #3 passes on first run without any red phase → verify it actually exercises `assertNoLoss` (add a debug `log.info` inside the migration step to prove the DELETE ran and the assertion caught it).

## Code Examples

### Example 1: Test #3 SchemaSanityChecker row-loss regression guard (reference pattern)

```dart
// Source: adapted from test/infrastructure/db/migration_v1_to_v2_test.dart + schema_sanity_test.dart
// Target path: test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(['migration'])
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/domain/errors/migration_errors.dart';
import 'package:mirkfall/infrastructure/db/schema_sanity.dart';
import 'package:test/test.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart';
// ... etc

void main() {
  // Load 70-row V1 fixture
  // Run adversarial migration that does ALTER + DELETE FROM t_sessions WHERE rowid % 2 = 0
  // Wrap with SchemaSanityChecker.captureRowCounts BEFORE / assertNoLoss AFTER
  // expect assertNoLoss to throw MigrationFailureException with rowcount diff listing t_sessions loss

  test('assertNoLoss throws MigrationFailureException on row loss in t_sessions', () async {
    // ... fixture setup ...
    // ... adversarial migration step ...
    expect(
      () => sanity.assertNoLoss(),
      throwsA(
        isA<MigrationFailureException>()
            .having((e) => e.message, 'message', contains('t_sessions'))
            .having((e) => e.message, 'message', contains('lost')),
      ),
    );
  });
}
```

### Example 2: `compute_reveal_mask_no_callers_test.dart` guard (reference pattern — pure Dart option)

```dart
// Source: new, Phase 04
// Target path: test/domain/compute_reveal_mask_no_callers_test.dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details
//
// WORKAROUND: guard temporaire jusqu'à Phase 09 où computeRevealMask sera
// implémenté + ce test supprimé. CLAUDE.md §Workarounds.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('computeRevealMask has no callers outside its definition site (Phase 09 guard)', () {
    const definitionSite = 'lib/domain/revealed/reveal_calculator.dart';
    final callers = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relativePath = entity.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^.*/lib/'), 'lib/');
      if (relativePath == definitionSite) continue;
      final content = entity.readAsStringSync();
      if (content.contains('computeRevealMask')) callers.add(relativePath);
    }
    // Also scan test/ (except this guard itself)
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relativePath = entity.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^.*/test/'), 'test/');
      if (relativePath == 'test/domain/compute_reveal_mask_no_callers_test.dart') continue;
      final content = entity.readAsStringSync();
      if (content.contains('computeRevealMask')) callers.add(relativePath);
    }
    expect(callers, isEmpty,
        reason: 'computeRevealMask is unimplemented until Phase 09. Callers found: $callers');
  });
}
```

### Example 3: Adversarial Test #1 poison (domain import violation)

```dart
// Edit 1: lib/domain/sessions/session.dart (TOP of file, BEFORE the GOSL header — deliberately poison)
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart'; // POISON #1: forbidden import in domain

// ... existing imports and code ...

// Edit 2: lib/domain/markers/marker.dart (add near other imports)
import 'package:drift/drift.dart'; // POISON #2: forbidden import in domain

// ... existing code ...
```

Expected CI output:
```
tool/check_domain_purity.dart: 2 forbidden imports in lib/domain/:
  - lib/domain/sessions/session.dart:N imports package:flutter/material.dart
  - lib/domain/markers/marker.dart:M imports package:drift/drift.dart
Exit code: 1
```

### Example 4: Adversarial Test #2 poison (drift schema dump stale)

```dart
// Edit: lib/infrastructure/db/app_database.dart — inside Sessions table definition
// Source: existing file, add ONE new column

class Sessions extends Table {
  // ... existing columns ...
  TextColumn get notes => text().nullable()();

  // POISON: add notesExtra WITHOUT running `dart run drift_dev schema dump` afterwards
  TextColumn get notesExtra => text().nullable()();
}
```

Then locally:
```bash
dart run build_runner build --delete-conflicting-outputs   # regenerates .g.dart — MANDATORY
# DO NOT run: dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_current.json
flutter analyze --fatal-infos --fatal-warnings              # MUST pass locally BEFORE push
git add lib/infrastructure/db/app_database.dart lib/infrastructure/db/app_database.g.dart
git commit -m "test(adversarial): add notesExtra column without re-dumping schema to exercise drift dump guard

POISONED INTENTIONALLY — branch deleted after evidence archived."
git push -u origin adversarial/04-schema-drift-stale
```

Expected CI output on step "Check drift schema (current) is committed and fresh":
```
::error::drift_schemas/drift_schema_current.json is stale.
Run: dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_current.json
Exit code: 1
```

### Example 5: Runtime walk — `tool/walk_db.dart` one-off (RECOMMENDED alternative to `flutter run -d windows`)

```dart
// Source: new, Phase 04 Plan 04-02
// Target path: tool/walk_db.dart  (scratch file, delete after walk OR keep as debug utility)
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:mirkfall/infrastructure/db/app_database_factory.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  // Replicate the production path_provider resolution used by buildAppDatabase
  final supportDir = await getApplicationSupportDirectory();
  final dbFilename = p.join(supportDir.path, 'mirkfall.db');
  print('DB path: $dbFilename');

  final db = await buildAppDatabase(); // fires backup + pragma setup + migration + open
  await db.customSelect('SELECT 1').get(); // force open if lazy
  await db.close();

  // Report file sizes for WAL proof
  for (final basename in ['mirkfall.db', 'mirkfall.db-wal', 'mirkfall.db-shm']) {
    final file = File(p.join(supportDir.path, basename));
    print('$basename exists=${file.existsSync()} size=${file.existsSync() ? file.lengthSync() : "N/A"}');
  }
}
```

Run:
```bash
dart run tool/walk_db.dart
# outputs the DB path
sqlite3 <path>
# interactive prompt — run .schema, PRAGMA queries, .indexes
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 02 runtime walk bundled into Agent #2 | Dedicated Plan 04-02 BEFORE 4-agent wave | Phase 04 (2026-04-18) | Isolates filesystem-observation evidence from synthetic audit; avoids agent bias |
| All 3 adversarial tests = throwaway CI branches | 2 CI branches + 1 permanent unit test | Phase 04 (2026-04-18) | `SchemaSanityChecker` is runtime code, not a CI script — unit test is the correct discipline |
| No pre-classification of known items | Pre-class 3 VERIFICATION candidates in §2 BEFORE spawn agents | Phase 04 (2026-04-18) | Saves redundant agent cycles; focuses attention on blind-spot adjacencies |
| `flutter run -d windows` as walk driver | `dart run tool/walk_db.dart` (Claude recommendation, CONTEXT Discretion) | Phase 04 proposal | No UI wiring = no Flutter UI needed; simpler, platform-neutral |
| analyzer `<9` pin + `custom_lint` active | analyzer `^10` override + `custom_lint` silently degraded | Phase 03 Plan 03-04 (2026-04-18) | Accepted Noted trade-off, documented in STATE.md; to re-verify each dep bump |

**Deprecated/outdated:**
- Any expectation that `flutter analyze` catches domain-purity violations — relies on `custom_lint` which doesn't run under analyzer-10. Only `tool/check_domain_purity.dart` enforces this now.

## Open Questions

1. **Should the runtime walk use `flutter run -d windows` (CONTEXT wording) or `dart run tool/walk_db.dart` (Claude recommendation per Pitfall 3)?**
   - What we know: CONTEXT says `flutter run -d windows`. Phase 03's ProviderScope deferral means `flutter run` doesn't trigger `buildAppDatabase`.
   - What's unclear: Does user WANT the full UI-launch walk (proves the Windows packaging doesn't regress, desktop plugin stack intact) or just the DB-open walk (proves `buildAppDatabase` works against real filesystem)?
   - Recommendation: Plan 04-02 DEFAULTS to `dart run tool/walk_db.dart` (simpler, direct) BUT offers `flutter run -d windows` as an option in the script if user prefers. Flag this explicitly in 04-02-PLAN.md for user input at checkpoint.

2. **Does the 4-agent parallel audit risk timeout on Windows for a ~2× larger Phase 03 codebase?**
   - What we know: Phase 02 `agents` wave completed in 25 min (STATE.md). Phase 03 code base is roughly twice larger by file count + fixtures.
   - What's unclear: Actual wall-clock impact on Windows vs Linux/macOS; cache warming behavior.
   - Recommendation: Accept the risk (Phase 02 success margin is wide). If Plan 04-03 Task 2 exceeds 45 min, serialize agents as fallback. Document outcome in 04-03-SUMMARY.md for future review gates.

3. **Is the 3-candidate pre-classification exhaustive, or will the 4 agents surface adjacent repeats?**
   - What we know: VERIFICATION.md §Outstanding minor items lists exactly 3. Agents could plausibly re-discover additional flaky tests (Windows-specific), additional `UnimplementedError` stubs (search the Phase 03 codebase), or additional analyzer-10 compat regressions.
   - What's unclear: Whether the VERIFICATION list is complete or just the items the verifier noticed.
   - Recommendation: Pre-class the 3 known; brief Agent #4 explicitly to search for ADDITIONAL `UnimplementedError` throws, flaky tests, analyzer-plugin silent-degrade analogues. Any adjacencies surface in §2 normally.

4. **Should `custom_lint` silent-degrade fix waiver be cross-posted to ROADMAP.md Phase 15?**
   - What we know: CONTEXT says "re-verification at each deps bump + Phase 15 polish latest". STATE.md already documents the reversal.
   - What's unclear: Whether ROADMAP.md Phase 15 Success Criteria should be updated to include "re-check custom_lint status" as an explicit item.
   - Recommendation: Plan 04-05 closure (STATE.md update) adds a Pending Todo entry: "Re-verify custom_lint status at each deps bump + Phase 15 at latest". This goes in STATE.md, not ROADMAP.md (which is locked scope-wise).

5. **How are commits from adversarial branches handled in git history?**
   - What we know: Phase 02 kept `main` clean — poison commits stayed on throwaway branches, deleted after evidence. Only `docs(02-rev): archive adversarial evidence` commits made it to `main`.
   - What's unclear: n/a — pattern is well-established. Phase 04 follows identically with `adversarial/04-*` naming.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `test` (pure-Dart, version 1.25.2 per pubspec) + `flutter_test` (for widget tests, not used Phase 04) |
| Config file | `dart_test.yaml` at repo root (Phase 03 Plan 03-01 — uses `tags` definitions for `migration`) |
| Quick run command | `dart test test/domain/ test/infrastructure/` (pure-Dart subsets, matches Phase 03 CI scoping) |
| Full suite command | `flutter test` + `dart test test/domain/ test/infrastructure/` (Phase 01 Flutter widgets + Phase 03 pure-Dart) |
| Adversarial CI gate observation | `gh run list --branch adversarial/04-<name> --limit 1 --json databaseId,status,conclusion` + `gh run view $RUN_ID --log-failed` |
| Runtime walk validation | `sqlite3 <path>` CLI outputs captured into §1b inline |

### Phase Requirements → Validation Map

Since Phase 04 has no REQ-IDs, validation maps to the 4 SC items of ROADMAP + CONTEXT gate-closed criteria.

| Concern | Validation Type | Automated Command | File Exists? |
|---------|-----------------|-------------------|--------------|
| SC#1: V1→V2 migration fictive tested | integration | `dart test test/infrastructure/db/migration_v1_to_v2_test.dart` | ✅ (Phase 03) |
| SC#1 (extension): row-loss regression guard | integration | `dart test test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` | ❌ Plan 04-04 Task 3 creates |
| SC#2: no `is`-chains / `dynamic` / singletons in domain | manual (Agent #2) + automated purity | `dart run tool/check_domain_purity.dart` (enforces imports, not polymorphism) | ✅ tool exists; Agent #2 adds human-level review |
| SC#2 (extension): `computeRevealMask` no callers guard | unit | `dart test test/domain/compute_reveal_mask_no_callers_test.dart` | ❌ Plan 04-05 fix task creates |
| SC#3: review protocol applied | process-verification (git log) | `git log --oneline --grep="docs(04-rev): scaffold" --grep="docs(04-rev): capture user-observed"` | — verified by commit pattern |
| SC#4: fixes integrated + tests green | CI-verified | `gh run list --branch main --limit 1 --json conclusion --jq '.[0].conclusion'` → "success" | — verified by final `main` CI |
| Adversarial Test #1 evidence | CI policy violation | `gh run view $RUN_ID_1 --log-failed` contains domain-purity violation × 2 | — CI URL archived §4 |
| Adversarial Test #2 evidence | CI policy violation | `gh run view $RUN_ID_2 --log-failed` contains `drift_schemas/drift_schema_current.json is stale` | — CI URL archived §4 |
| Adversarial Test #3 evidence | unit test + commit hash | `dart test test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` green | — commit hash archived §4 |
| §1 user capture | file content | `! grep -q "awaiting user input" 04-REVIEW.md` + commit log shows `docs(04-rev): capture user-observed findings` | — |
| §1b runtime walk | file content | `grep -q "^### 1b\. Runtime walk Windows" 04-REVIEW.md` + content with 6 PRAGMA outputs + `.schema` + `.indexes` | — |
| §3 triage complete | file content | every row filled, no `(pending)`, every Blocker=fix, every waived Should has rationale | — |
| §4 adversarial evidence | file content | 3 evidence blocks with 2 CI URLs + 1 commit hash | — |
| §5 CI-green closure | file content | `grep -q "**Status:** closed"` + commit hash + run URL filled | — |
| Adversarial branch cleanup | git | `git branch -a | grep adversarial/04- || echo CLEAN` + `gh api repos/:owner/:repo/branches --paginate | grep -v adversarial/04-` | — |

### Sampling Rate
- **Per task commit (Plan 04-05 fix loop):** `flutter analyze --fatal-infos --fatal-warnings` + `dart format --line-length 160 --set-exit-if-changed .` + `flutter test` + `dart test test/domain/ test/infrastructure/` + 4 guard scripts (`check_headers`, `check_licenses`, `check_dependencies_md`, `check_domain_purity`). All exit 0 required before push.
- **Per wave merge (per plan boundary):** full quick suite as above; wait for `gh run watch --exit-status` green before next plan.
- **Phase gate (before `/gsd:verify-work`):** full suite green on `main` final commit; all 5 REVIEW.md sections filled; `**Status:** closed`; no `adversarial/04-*` branches local/remote; `.fixes-expected` scratch file deleted.

### Wave 0 Gaps

No Wave 0 gaps — test infrastructure is complete from Phase 03:
- `dart_test.yaml` exists (root)
- `test/generated_migrations/` has `schema.dart` + `schema_v1.dart` + `schema_v2.dart` (consumed by migration tests)
- `test/fixtures/` has `json/session_v{1,2}.json` + `json/markers_only_v1.json` + `json/mirk_style_unknown_renderer.json` + `db_seed/v1_baseline.sql`
- Both `dart test` (pure-Dart) and `flutter test` (Flutter widgets) runners are operational

Only Phase 04 additions needed during normal plan execution:
- [ ] `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` — covers Test #3 adversarial (Plan 04-04 Task 3)
- [ ] `test/domain/compute_reveal_mask_no_callers_test.dart` — covers Should #3 (Plan 04-05 fix task corresponding to pre-classified Should)
- [ ] `tool/walk_db.dart` — scratch utility for runtime walk (Plan 04-02 Task 1); deletable post-walk OR kept as debug utility (decision at Plan 04-02 checkpoint)

## Per-Plan Scope (planner input)

### Plan 04-01 — Scaffold + §1 user capture (Wave 1)
- **Depends on:** none
- **Autonomous:** false (checkpoint on user IDE findings solicitation)
- **Files modified:** `.planning/phases/04-review-gate-persistence/04-REVIEW.md`
- **Must-haves:** 5-section skeleton + §1b sub-section for runtime walk + `**Status:** open` + 3 pre-classification slots in §2 (filled Plan 04-03 Task 1) + §1 verbatim user capture + 2 atomic commits (scaffold + capture)
- **Pattern source:** 02-01-PLAN.md

### Plan 04-02 — Runtime walk Windows (Wave 2)
- **Depends on:** 04-01
- **Autonomous:** false (checkpoint on user executing walk + pasting outputs)
- **Files modified:** `.planning/phases/04-review-gate-persistence/04-REVIEW.md` (§1b filled) + possibly `tool/walk_db.dart` (scratch utility, maybe delete at plan end)
- **Must-haves:** 6 PRAGMA outputs (`user_version=2`, `journal_mode=wal`, `foreign_keys=1`, `synchronous=1`, `busy_timeout=5000`, `page_size` optional) + `.schema` output showing 6 tables + `.indexes t_sessions` showing `idx_t_sessions_status_active` + 3 file sizes (DB, WAL, SHM) + evidence commit `docs(04-rev): archive runtime walk evidence`
- **Pattern source:** new plan, no direct 02-xx-PLAN equivalent; use 02-02-PLAN Task 1's Windows-walk section as inspiration but extract into dedicated plan

### Plan 04-03 — Pre-class + 4-agent parallel audit + user triage (Wave 3)
- **Depends on:** 04-02
- **Autonomous:** false (triage checkpoint on user)
- **Files modified:** `.planning/phases/04-review-gate-persistence/04-REVIEW.md` (§2 + §3 filled) + `.planning/phases/04-review-gate-persistence/04-03-SUMMARY.md`
- **Must-haves:** pre-class 3 VERIFICATION candidates into §2 sub-section "Pre-known from VERIFICATION" BEFORE spawn; spawn 4 sub-agents (all `general-purpose`) in ONE tool-use message; consolidate findings into §2 by agent-slice; present to user as titles + 1-line explanations (never diffs); capture §3 triage; carry adversarial poison recipes into 04-03-SUMMARY.md
- **Pattern source:** 02-02-PLAN.md — direct adaptation with agent scopes from CONTEXT §Locked Decisions

### Plan 04-04 — Adversarial wave (2 CI branches + 1 permanent test) (Wave 4)
- **Depends on:** 04-03
- **Autonomous:** true (matches 02-03 `autonomous: true`)
- **Files modified:** `.planning/phases/04-review-gate-persistence/04-REVIEW.md` (§4 filled) + `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` (new, permanent) + `.planning/phases/04-review-gate-persistence/04-04-SUMMARY.md`
- **Must-haves:** Test #1 branch lifecycle (poison + push + CI red + archive URL + delete local/remote); Test #2 branch lifecycle (same, with `build_runner` prerequisite); Test #3 commit + green unit test evidence; 3 §4 evidence blocks; no `adversarial/04-*` branches remaining
- **Pattern source:** 02-03-PLAN.md — direct adaptation, with Task 3 = permanent test (NOT a branch)

### Plan 04-05 — Atomic fix loop + closure (Wave 5)
- **Depends on:** 04-03 + 04-04
- **Autonomous:** false (final closure checkpoint on user "OK close")
- **Files modified:** dynamically determined by §3 triage (typically `lib/infrastructure/db/backup.dart` for flaky fix, `test/infrastructure/db/backup_test.dart` for flaky test update, `test/domain/compute_reveal_mask_no_callers_test.dart` new, `DEPENDENCIES.md` for custom_lint documentation, `.planning/STATE.md` for Accumulated Decisions entry); ALWAYS: `.planning/phases/04-review-gate-persistence/04-REVIEW.md` (§5 + status flip) + `.planning/STATE.md` (Phase 04 complete) + `.planning/ROADMAP.md` (Phase 04 row complete) + `.planning/phases/04-review-gate-persistence/04-05-SUMMARY.md` + `.planning/phases/04-review-gate-persistence/.fixes-expected` (scratch, deleted at closure)
- **Must-haves:** `.fixes-expected` snapshot taken BEFORE any §3 mutation; atomic `fix(04-rev):`/`refactor(04-rev):`/`test(04-rev):` commits one-per-finding, each CI-gated green before next; §5 filled with final commit hash + run URL + 3-job-green status + date; `**Status:** open` → `closed`; STATE.md + ROADMAP.md updated with user consent; `.fixes-expected` deleted
- **Pattern source:** 02-04-PLAN.md — direct adaptation

## References

### Phase 02 (exemplar, same pattern)
- `.planning/phases/02-review-gate-foundation/02-CONTEXT.md` — original protocol decisions
- `.planning/phases/02-review-gate-foundation/02-REVIEW.md` — reference artefact final state
- `.planning/phases/02-review-gate-foundation/02-01-PLAN.md` — scaffold + §1 capture template
- `.planning/phases/02-review-gate-foundation/02-02-PLAN.md` — 4-agent audit + triage template
- `.planning/phases/02-review-gate-foundation/02-03-PLAN.md` — adversarial branch lifecycle template
- `.planning/phases/02-review-gate-foundation/02-04-PLAN.md` — atomic fix loop + closure template
- `.planning/phases/02-review-gate-foundation/02-04-SUMMARY.md` — 42-fix execution trace

### Phase 03 (audit target)
- `.planning/phases/03-persistence-domain-models/03-VERIFICATION.md` — 6/6 VERIFIED baseline + 3 candidate items pre-classified
- `.planning/phases/03-persistence-domain-models/03-CONTEXT.md` — decisions being audited
- `.planning/phases/03-persistence-domain-models/03-0{1..6}-SUMMARY.md` — deviations self-documented

### Phase 04 source (primary context)
- `.planning/phases/04-review-gate-persistence/04-CONTEXT.md` — locked decisions consumed verbatim into `<user_constraints>` above

### Project-wide
- `.planning/STATE.md` — Accumulated Decisions for Phase 02 + Phase 03 patterns
- `.planning/ROADMAP.md` — Phase 04 Success Criteria (4 items)
- `.planning/REQUIREMENTS.md` — no REQ-IDs for Phase 04 (review gate)
- `CLAUDE.md` — §Code Review Phases protocol (non-negotiable); §Git-CI; §Dependencies
- `DEPENDENCIES.md` — Phase 03 deltas visible (drift, freezed, custom_lint silently-degraded note)
- `.github/workflows/ci.yml` — `gates` job runs `check_domain_purity` (line 74) + drift schema dump guard (line 90) — the two CI adversary targets

## Sources

### Primary (HIGH confidence)
- `.planning/phases/04-review-gate-persistence/04-CONTEXT.md` — all decisions verbatim
- `.planning/phases/02-review-gate-foundation/02-01-PLAN.md` .. `02-04-PLAN.md` — concrete template exemplar (frontmatter, task structure, checkpoint patterns)
- `.planning/phases/02-review-gate-foundation/02-REVIEW.md` — output format reference
- `.planning/phases/03-persistence-domain-models/03-VERIFICATION.md` — 3 candidate items pre-classified + outstanding minor items language
- `.github/workflows/ci.yml` — verified CI step names + ordering (gates line 27-122)
- `.planning/STATE.md` — accumulated decisions (analyzer-10 reversal, custom_lint silently-degraded, 4-agent pattern validation)
- Filesystem glob outputs — verified file lists for `lib/domain/**`, `lib/infrastructure/**`, `lib/application/**`, `test/**`, `tool/**`, `drift_schemas/*.json`, `test/fixtures/**`

### Secondary (MEDIUM confidence)
- `DEPENDENCIES.md` (lines 77-104) — `custom_lint` version + analyzer-10 trade-off explicit
- `pubspec.yaml` (lines 19-107) — comment trail of analyzer-10 reversal decision
- Phase 02 `.fixes-expected` scratch file precedent (file found in Phase 02 dir) — confirms pattern still live
- Phase 02 commit log (`git log`) — verifies atomic commit naming convention `fix(02-rev):`, `docs(02-rev):`, etc.

### Tertiary (LOW confidence — flagged for validation during planning)
- Pitfall 3 `flutter run -d windows` not triggering `buildAppDatabase` — reasoned from Riverpod lazy-initialization + 03-CONTEXT ProviderScope deferral; RECOMMEND validate by attempting the walk OR adopting `tool/walk_db.dart` alternative
- Pitfall 5 `gh run watch` timeout concern — Phase 02 worked without `--exit-status` per 02-04-SUMMARY but defensive use is cheap
- Pitfall 4 Windows 4-agent parallel IO saturation — reasoned from Phase 02 25-min wall-clock; actual Phase 04 cost unknown

## Metadata

**Confidence breakdown:**
- Wave decomposition: HIGH — direct 1:1 structural mapping to Phase 02 + 1 insertion (runtime walk) prescribed by CONTEXT
- Sub-agent scopes: HIGH — CONTEXT §Locked Decisions lists exact file assignments per agent
- Adversarial test design: HIGH — CONTEXT §Locked Decisions + verified against `.github/workflows/ci.yml` step names
- Pre-classification targets: HIGH — 03-VERIFICATION.md §Outstanding minor items verbatim
- Per-plan files_modified: HIGH for planning/STATE/ROADMAP/REVIEW paths; MEDIUM for dynamic fix targets (depends on §3 triage outcome)
- Runtime walk script format: MEDIUM — `tool/walk_db.dart` recommendation is a Claude inference from Pitfall 3, not in CONTEXT
- Pitfalls: MEDIUM-HIGH — most derived from Phase 02 precedent (high); a few novel (walk path discovery, build_runner prerequisite) rated MEDIUM pending validation
- Code examples: HIGH — reference patterns verified against existing Phase 03 test files + CI YAML

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — review gate patterns are stable; only Drift/Freezed ecosystem drift or `gh` CLI changes could invalidate)

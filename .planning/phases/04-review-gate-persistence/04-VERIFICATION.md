---
phase: 04-review-gate-persistence
verified: 2026-04-18T00:00:00Z
status: passed
score: 4/4 must-haves verified
---

# Phase 04: Review Gate — Persistence Verification Report

**Phase Goal:** Auditer la phase 03 avant que le GPS ne commence à écrire. Une erreur de modèle rattrapée ici coûte une semaine ; rattrapée en phase 09 elle coûte un mois.
**Verified:** 2026-04-18
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                  | Status     | Evidence                                                                                                                         |
| --- | -------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 1   | V1→V2 fictive migration exercises a real schema change (not identity)                  | VERIFIED   | `migration_v1_to_v2_test.dart` adds `notes` column, inserts V1 row, asserts NULL default + writeable; data-loss guard test fires on rowid-parity DELETE |
| 2   | Domain has no is-chains, no undocumented dynamic, no singletons                        | VERIFIED   | One `is Map` in `mirk_style_config.dart` is a type-narrowing converter (not a polymorphic dispatch chain); `dynamic` in `envelope.dart` is documented at the call-site with two-paragraph docstring; no singletons found |
| 3   | Review protocol (user-first, titles+explanations, per-finding triage) applied          | VERIFIED   | §1 captured user IDE findings BEFORE Claude audit (explicit "aucune observation utilisateur" marker); 88 structured `[Severity] Title — explanation — file:line` entries in §2; 95-row triage table in §3 |
| 4   | All Blocker+Should fixes integrated with persistence tests still green                 | VERIFIED   | 10 fix batches on `main` (commits `74f1bb2`..`676bcb8`), CI all 3 jobs green on `26f3d99`; `.fixes-expected` deleted; `04-REVIEW.md` status=closed |

**Score:** 4/4 truths verified

---

## Required Artifacts

| Artifact                                                               | Expected                                         | Status   | Details                                                                          |
| ---------------------------------------------------------------------- | ------------------------------------------------ | -------- | -------------------------------------------------------------------------------- |
| `test/infrastructure/db/migration_v1_to_v2_test.dart`                 | Real schema-change migration test                | VERIFIED | 167 lines; 2 tests: single-row + 70-row fixture; `migrateAndValidate` + `assertNoLoss` called |
| `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart`       | Permanent regression guard — row-loss detection  | VERIFIED | 125 lines; `@Tags(['migration'])`; throws `MigrationFailureException` with adversarial `DELETE WHERE rowid % 2 = 0` |
| `tool/check_domain_purity.dart`                                        | Regex covers `flutter`, `drift`, `drift_flutter` | VERIFIED | `final RegExp _forbiddenPattern = RegExp(r"""^\s*import\s+['"]package:(flutter\|drift_flutter\|drift)(?:/\|['"])""")` — all three arms present (Batch J fix #31) |
| `test/domain/compute_reveal_mask_no_callers_test.dart`                 | No-callers guard for Phase 09 unimplemented stub | VERIFIED | 38 lines; scans `lib/` + `test/` for `computeRevealMask` callers; allowlist for definition + existing contract test |
| `lib/main.dart`                                                        | Zone mismatch fix (P4 option-b)                  | VERIFIED | Both `WidgetsFlutterBinding.ensureInitialized()` and `runApp(...)` are inside the same `runZonedGuarded` callback; 100-line docblock explains option-a→option-b pivot |
| `lib/infrastructure/db/backup.dart`                                    | Filename-ISO sort replacing mtime sort           | VERIFIED | `rotate()` uses `_extractBackupSortKey(p.basename(...))` lex compare; comment explicitly states "deterministic and immune to Windows NTFS mtime" |
| `.planning/phases/04-review-gate-persistence/04-REVIEW.md`            | Status=closed, §1–§5 complete                    | VERIFIED | Frontmatter `Status: closed`; §1 user-first; §2 88 findings; §3 triage; §4 adversarial evidence with CI URLs; §5 per-batch SHAs + final CI URL |
| `tool/walk_db.dart`                                                    | P5 pragma probe via live Drift connection        | VERIFIED | Lines 63–79 iterate 5 PRAGMAs via `db.customSelect('PRAGMA $pragma').getSingle()` |

---

## Key Link Verification

| From                                       | To                                         | Via                                                    | Status   | Details                                                                   |
| ------------------------------------------ | ------------------------------------------ | ------------------------------------------------------ | -------- | ------------------------------------------------------------------------- |
| `migration_v1_to_v2_test.dart`             | `AppDatabase` / `SchemaVerifier`           | `verifier.migrateAndValidate(prodDb, 2)`               | WIRED    | Live prod code path exercised, not a stub                                 |
| `migration_v1_to_v2_data_loss_test.dart`   | `SchemaSanityChecker.assertNoLoss`         | Direct call after adversarial DELETE                   | WIRED    | Asserts `MigrationFailureException` with `t_sessions` + `decreased` in `reason` |
| `tool/check_domain_purity.dart`            | `lib/domain/**` handwritten files          | Recursive `Directory.list` + `_forbiddenPattern` regex | WIRED    | Covers `flutter`, `drift`, `drift_flutter`; CI gate invokes via `dart run` |
| `lib/main.dart`                            | `runZonedGuarded` bootstrap               | `ensureInitialized` + `runApp` both inside guarded lambda | WIRED  | User re-walk confirmed clean boot (no zone mismatch assertion)            |
| `lib/infrastructure/db/backup.dart`        | Filename-ISO timestamp                     | `_extractBackupSortKey` regex capture group             | WIRED    | Production `rotate()` no longer calls `File.statSync().modified`         |

---

## Success Criteria Assessment

### SC#1 — V1→V2 Fictive Migration

**Status: MET**

`test/infrastructure/db/migration_v1_to_v2_test.dart` is a substantive test of the migration framework:

- Opens schema at V1 via `verifier.schemaAt(1)`, seeds a session row in V1 shape (no `notes` column in that schema).
- Calls `verifier.migrateAndValidate(prodDb, 2)` — this is the prod `AppDatabase` wired to the same backing store, exercising the real `V1ToV2Notes.apply()` migration step.
- Asserts the seeded row survived with `notes IS NULL` (the V1→V2 migration uses `ALTER TABLE ADD COLUMN` which defaults to NULL per SQLite spec).
- Asserts the new column is writeable post-migration.
- Second test loads the full 70-row `v1_baseline.sql` fixture, migrates to V2, and calls `SchemaSanityChecker.assertNoLoss` to confirm zero row-count decrease across all 6 tables.

The permanent regression guard (`migration_v1_to_v2_data_loss_test.dart`) injects an adversarial migration (ALTER TABLE + `DELETE WHERE rowid % 2 = 0`) and asserts that `SchemaSanityChecker.assertNoLoss` throws `MigrationFailureException` with `t_sessions` + `decreased` in the `reason` field. A false-positive guard (`expect(after < before)`) ensures the DELETE actually ran — the test cannot silently become inert.

Both tests carry `@Tags(['migration'])` for dart_test.yaml tag discipline.

### SC#2 — Domain Purity (no is-chains, no undocumented dynamic, no singletons)

**Status: MET**

- **is-chains:** Zero `is TypeName` chains in handwritten domain files (`.freezed.dart` and `.g.dart` excluded — generated). The sealed `MirkStyleConfig` union dispatches via exhaustive switch pattern-match, not `is`-chains (confirmed `lib/domain/mirk/mirk_style_config.dart` line 16 docstring + freezed generated dispatch). One `if (value is Map)` in `_unknownRawFromJson` is a type-narrowing converter helper (not a polymorphic dispatch chain) — acceptable. `tile_math.dart`'s `operator ==` contains `other is TilePosition` — standard equality override, not a chain.
- **dynamic:** Two `Map<String, dynamic>` occurrences in `envelope.dart` (lines 83, 89) are in private converter functions `_payloadFromJson` / `_payloadToJson` with 4-line docstrings explaining why (`json_serializable` hands a `Map<String, dynamic>` at the JSON boundary; converted to `Object?` inside domain). Documented, not silent. Agent #2 flagged this as `Could` (finding #41) and deferred.
- **singletons:** No `static _instance`, `static shared`, or `getInstance` pattern found anywhere in `lib/domain/` handwritten files. Services are constructor-injected per CLAUDE.md convention.
- **check_domain_purity.dart gate:** Regex covers `package:flutter/`, `package:drift/`, and `package:drift_flutter/` (Batch J, commit `676bcb8`). Adversarial CI run confirmed exit code 1 on real violations (run `24611059783`).

### SC#3 — Review Protocol Applied

**Status: MET**

- **User-first (§1):** `04-REVIEW.md §1` opens with `*Captured verbatim at phase start, BEFORE Claude's audit.*` followed by `*Aucune observation utilisateur — l'user n'a pas identifié de point à revoir dans son IDE.*`. This is the canonical explicit-empty-marker (CLAUDE.md §Decisions records: `'Aucune observation utilisateur' is valid §1 content`). The §1b runtime walk (Plan 04-02) was also conducted BEFORE any agent spawn.
- **Titles + 1-line explanations (§2):** 88 structured entries follow the format `[Severity] Title — explanation — file:line`. No diffs embedded. 4 agent sub-sections + 2 pre-class subsections.
- **Triage per finding (§3):** 95 table rows (9 Blockers, 27 Shoulds, 22 Coulds, 33+ Noted) with per-finding `Decision` and `Rationale / Target` columns. User blanket-approved `fix all Blockers + Shoulds` explicitly (quoted verbatim in §3 header); Coulds deferred; Noteds observation-only.

### SC#4 — Fixes Integrated, Tests Green

**Status: MET**

All 31 unique fix targets resolved across 10 batches:

| Batch | Key fixes | Commit |
| ----- | --------- | ------ |
| pre-A | UTC offset constants extraction | `74f1bb2` |
| A     | Domain @Assert invariants (5 findings) | `82a0ee7` |
| B     | DB CHECK constraints (status/offsets/bitmap) | `b042a1c` |
| C     | parentZoom magic → `kRevealedTileParentZoom` | `54313ce` |
| D     | P4 Zone mismatch option-b | `e45339f` |
| E     | Backup filename-ISO sort | `72da162` |
| F     | cat_default seed + docstrings | `2e528df` |
| G     | Session store error signaling (8 findings) | `6425889` |
| H     | mergeMask INSERT OR IGNORE atomic | `daed232` |
| I     | Typed DSL category reassign + Marker DESC | `5ee9838` |
| J     | Tooling guards + P3 no-callers + P5 pragma | `676bcb8` |

Final `main` HEAD: `401b7b5` (docs closure commit; final code HEAD `26f3d99`).
CI run `24616052442`: all 3 jobs green (gates / android / ios), dated 2026-04-19.
`.fixes-expected` file: deleted (target count met).
`04-REVIEW.md` frontmatter: `Status: closed`.

---

## Additional Verification Items

### P4 Zone Mismatch — Architectural Soundness

`lib/main.dart`: `WidgetsFlutterBinding.ensureInitialized()` is the FIRST statement inside `runZonedGuarded(() async { ... })`. `runApp(const ProviderScope(child: MirkFallApp()))` is the LAST statement inside the same lambda. Both share the identical guarded zone. The 100-line block comment above `main()` documents the option-a → option-b pivot, the failed first attempt (`56b164f`), and why option-b is the canonical Flutter pattern for `runZonedGuarded` bootstraps. User re-walk confirmed clean boot (§5: no zone mismatch assertion, `A Dart VM Service on Windows is available at...`).

### P1 Architectural Fix — Backup Sort Key

`lib/infrastructure/db/backup.dart`: `rotate()` method (line 83) sorts `entries` descending by `_extractBackupSortKey(p.basename(...))`. Private method `_extractBackupSortKey` (line 96–115) extracts the ISO-8601 timestamp from the filename using a regex and returns empty string for malformed filenames (which lex-sort before any valid timestamp, so orphan files rotate out first). No `File.statSync().modified` call anywhere in the file. Production code is deterministic regardless of NTFS mtime resolution or antivirus interference.

### P3 No-Callers Guard

`test/domain/compute_reveal_mask_no_callers_test.dart` exists (38 lines), scans `lib/` + `test/` for `computeRevealMask` occurrences, allowlists 3 paths: definition site, the guard test itself, and the Phase 03 contract test that asserts `throws UnimplementedError`. Any Phase 05–08 code accidentally calling the stub will trip this guard immediately.

### P5 Walk_db Pragma Probe

`tool/walk_db.dart` iterates `['journal_mode', 'synchronous', 'busy_timeout', 'foreign_keys', 'user_version']` via `db.customSelect('PRAGMA $pragma').getSingle()` before `db.close()`. This reads through the live Drift connection (the one `applyRuntimePragmas` set values on in `beforeOpen`), not a separate CLI connection — authoritative per SC#2 walk-tooling gap analysis.

### Adversarial CI Evidence (§4)

- **Test #1** (domain purity gate): branch `adversarial/04-domain-import-flutter-and-drift`, CI run `24611059783`, job `gates` conclusion=failure, step `Check domain purity` exit code 1, 2 violations listed (Flutter in `session.dart`, Drift in `marker.dart`). Branch deleted.
- **Test #2** (schema dump stale): branch `adversarial/04-schema-drift-stale`, CI run `24611132558`, job `gates` conclusion=failure, step `Check drift schema (current) is committed and fresh` exit code 1, `::error::drift_schemas/drift_schema_current.json is stale`. Branch deleted.
- **Test #3** (row-loss permanent guard): commit `9c32eb1` on `main`, local `dart test` passes, adversarial inert-DELETE guard prevents silent test neutralization.

### STATE.md Accumulated Decisions

`STATE.md` records 12 Phase-04-specific accumulated decisions (lines 151–168 + 187), including:
- Blanket-approve triage pattern (Blockers + Shoulds only)
- Option-a → option-b zone pivot and the architectural lesson
- Batched fix strategy with user approval
- Severity-disagreement multi-lens convention
- P1 architectural fragility (production code, not test-only)
- P2 custom_lint silently-degraded state

---

## Anti-Patterns Found

None detected in the artifacts created or modified during this phase. The sole `if (value is Map)` in `mirk_style_config.dart` is a type-narrowing JSON converter, not a polymorphic dispatch chain. The two `dynamic` usages in `envelope.dart` are documented at both the type signature and call site.

---

## Human Verification Required

None. All automated checks pass. The P4 Zone mismatch fix was already re-walk verified by the user in session (§5: clean boot on `flutter run -d windows`, no exception output). No further human action is required before Phase 05 opens.

---

_Verified: 2026-04-18_
_Verifier: Claude (gsd-verifier)_

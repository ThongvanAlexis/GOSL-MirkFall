---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 6
status: executing
stopped_at: Completed 04-01-PLAN.md (scaffold + §1 user-first capture)
last_updated: "2026-04-18T16:53:45.512Z"
last_activity: 2026-04-18
progress:
  total_phases: 16
  completed_phases: 3
  total_plans: 19
  completed_plans: 15
  percent: 86
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-17)

**Core value:** Ne jamais perdre sa progression — import/export JSON versionné durable entre instances.
**Current focus:** Phase 03 — Persistence & Domain Models (03-01 through 03-04 done; 03-05 + 03-06 unblocked in Wave 4)

## Current Position

Phase: 03 of 16 (Persistence & Domain Models)
Current Plan: 6
Total Plans in Phase: 6
Plan: 4 of 6 complete in current phase (03-04 Drift AppDatabase + V1->V2 migration shipped — SC#1 + SESS-06 + MIRK-03 schema-layer closed, 13 DB tests + 82-test pure-Dart suite green)
Status: In Progress
Last Activity: 2026-04-18

Progress: [█████████░] 86%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 h

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| — | — | — | — |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-foundation P01 | 9 min | 1 tasks | 14 files |
| Phase 01-foundation P02 | 13 min | 2 tasks | 15 files |
| Phase 01-foundation P03 | 9 min | 2 tasks | 9 files |
| Phase 01-foundation P04 | 1h 36m | 2 tasks | 2 files |
| Phase 02-review-gate-foundation P01 | 2 min | 2 tasks | 1 files |
| Phase 02-review-gate-foundation P02 | 25 min | 3 tasks | 2 files |
| Phase 02-review-gate-foundation P03 | 10 min | 3 tasks | 1 files |
| Phase 03-persistence-domain-models P01 | 12 min | 3 tasks | 14 files |
| Phase 03-persistence-domain-models P02 | 9 min | 3 tasks | 34 files |
| Phase 03-persistence-domain-models P03 | 19 min | 3 tasks | 41 files |
| Phase 03-persistence-domain-models P04 | 20 min | 3 tasks | 15 files |
| Phase 03-persistence-domain-models P05 | 8 min | 3 tasks | 8 files |
| Phase 03-persistence-domain-models P6 | 12 min | 2 tasks | 28 files |
| Phase 04-review-gate-persistence P01 | 6min | 2 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions carried from research (2026-04-17) :

- Phase 03: Revealed area = zoom-14 parent tiles + 64×64 sub-tile bitmaps (D3)
- Phase 03: Single Drift DB pour toute donnée structurée (D4)
- Phase 03: Envelope JSON `{schemaVersion, type, payload}` pour import/export (D9)
- Phase 05: Pas de `flutter_background_geolocation` — clé de licence payante incompatible GOSL ; geolocator + foreground service Android + iOS background mode à la place
- Phase 05: Exclusivité session enforced par partial unique index Drift, pas par discipline caller (D13)
- Phase 07: `TileSource` seam — V1.0 online OSM, V1.1 MBTiles offline en pur ajout (D7)
- Phase 09: `MirkRenderer` seam — expose uniquement `paint(Canvas, Size, MirkPaintContext)`, aucun détail d'implémentation (D6)
- Project-wide: Riverpod comme unique state management + DI (D5)
- [Phase 01-foundation]: Held analyzer stack at <9.0 for Phase 01 — No compatible custom_lint + riverpod_lint + analyzer trio exists yet; upgrading to analyzer ^9 would force dropping lint tools. Phase 03 will re-evaluate when ecosystem converges.
- [Phase 01-foundation]: Defer custom_lint + riverpod_lint to Phase 03 — Phase 01 has no @riverpod providers; lint tools add no value until codegen starts.
- [Phase 01-foundation]: Empty ios/Podfile.lock placeholder on Windows dev host — CocoaPods not available on Windows; macOS CI regenerates on first pod install.
- [Phase 01-foundation]: FileLogger as static class, not Riverpod provider — owns process-global IOSink + Logger.root subscription — Wrapping process-global singletons in a provider would be cargo-cult DI per CLAUDE.md §Wrappers (no wrappers without added logic)
- [Phase 01-foundation]: Single DEBUG-define test with runtime branching on bool.fromEnvironment('DEBUG') — One test file asserts Level.ALL when --dart-define=DEBUG=true and Level.INFO otherwise — CI never silently skips the DEBUG-define path
- [Phase 01-foundation]: cross_file imported via share_plus re-export (not as direct dep) — share_plus_platform_interface re-exports package:cross_file/cross_file.dart — XFile available through share_plus import, no extra audit entry
- [Phase 01-foundation]: pumpAndSettle() replaced with bounded settleRefresh(tester) in DebugMenuScreen tests — Active FileLogger sink + Logger.root listener feed microtask queue continuously; pump+runAsync helper with bounded iteration avoids timeout
- [Phase 01-foundation]: Accept dbus/geoclue/gsettings MPL-2.0 as Linux-only transitives via narrow _manualOverrides with synthetic SPDX MPL-2.0-Linux-only — Linux plugin surfaces never execute on Android/iOS (MirkFall's ship targets); MPL-2.0 is file-level weak-copyleft so it does not contaminate combined work. Synthetic SPDX keeps exception visible in code review.
- [Phase 01-foundation]: Promote yaml + test from transitive to direct dev dependencies — Our scripts/tests import them directly; depend_on_referenced_packages lint + CLAUDE.md pin policy require explicit declaration.
- [Phase 01-foundation]: CI gate exit code contract: 0=clean, 1=policy violation, 2=misconfiguration — Distinct signals let CI differentiate between a caught violation and a broken run; keeps gate outputs actionable.
- [Phase 01-foundation]: Option A for cross-platform Podfile.lock bootstrap — CI detects placeholder (no COCOAPODS: footer), removes it before pod install, does NOT auto-commit the regenerated lockfile back — Windows dev host cannot generate Podfile.lock (no CocoaPods). Option B (CI auto-commit back) was rejected — creates noisy commit history + requires CI write access to main. Option C (seed once on Mac, commit) was rejected — drifts on every transitive pod upgrade, and author primarily works on Windows. Option A keeps CI read-only, makes the pins the single source of truth, and regenerates from scratch every run.
- [Phase 01-foundation]: Core library desugaring enabled in android/app/build.gradle.kts with pinned desugar_jdk_libs:2.1.4 — flutter_local_notifications 21.0.0 requires java.time APIs at minSdk 24; AGP 8.x needs isCoreLibraryDesugaringEnabled = true + the coreLibraryDesugaring dep. Version 2.1.4 matches the AGP 8.x bundled version as of 2026-04.
- [Phase 01-foundation]: Forensic-analysis diagnostic step added to android + ios CI jobs with continue-on-error — Runs after flutter pub get, before the build step — dumps runner OS, toolchain, SDK, deps, disk, env. continue-on-error guarantees the diagnostic itself can never break a build. Reusable pattern for Phase 15 release CI and beyond.
- [Phase 02-review-gate-foundation]: Review-gate protocol operationalized as Plan 02-01 with blocking checkpoint — Encoding CLAUDE.md §Code Review Phases as a structural gate (scaffold + solicit+capture + commit-before-agents) makes it enforceable under time pressure. Future review gates (04, 06, 08, 10, 12, 14, 16) will reuse this 2-task pattern.
- [Phase 02-review-gate-foundation]: 5-section review artifact contract locked — §1 User-observed / §2 Claude audit / §3 Triage / §4 Adversarial / §5 CI-green. gsd-verifier greps `^## [1-5]\\.` to confirm 5 headings. Reusable across all even-numbered phases.
- [Phase 02-review-gate-foundation]: GOSL Dart copyright header NOT prepended to .md review artifacts — tool/check_headers.dart scans .dart only; markdown exempt. Consistent with Phase 01 header scanner scope.
- [Phase 02-review-gate-foundation]: 4-parallel-sub-agent audit wave template validated — single tool-use message spawning 4 concern-sliced `general-purpose` agents (CI gates / bootstrap runtime / code quality / tests+tooling) yielded 54 findings in one wall-clock slot. Pattern reusable for every future review gate (phases 04, 06, 08, 10, 12, 14, 16).
- [Phase 02-review-gate-foundation]: All 4 audit agents set to `general-purpose` for wave consistency — even the read-only Agent #3 (code sweep) which could have been `Explore` was kept `general-purpose` so future review gates have a predictable agent-type rule. Minor efficiency loss outweighed by rule clarity.
- [Phase 02-review-gate-foundation]: User blanket-fix decision on 42 findings (all Blockers + Shoulds + Coulds) rather than per-finding triage — rationale "setup du projet, autant rendre ça aussi propre qu'on peu maintenant" preserved verbatim in §3. Reduces Plan 02-04 decision overhead at cost of ~13 Could-level polish fixes that might have been deferrable.
- [Phase 02-review-gate-foundation]: Phase 01 closure gap surfaced — `check_licenses.dart` parser has 4 Blocker-level issues (case-sensitivity, compound-AND semantics, license-field-bypass, MPL-unreachable heuristic) despite Phase 01 VERIFIED:PASSED. Gate script was only stressed against happy-path fixtures. Adversarial Plan 02-03 catches 3 of 4; Plan 02-04 must add unit coverage for the 4th (MPL-unreachable branch).
- [Phase 02-review-gate-foundation]: Phase 01 closure gap surfaced — `PlatformDispatcher.onError` missing with no recorded user sign-off. Phase 01 RESEARCH flagged this as needing user confirmation but no decision was captured. Plan 02-04 will either wire `PlatformDispatcher.onError` or record explicit waiver — no silent deferral.
- [Phase 02-review-gate-foundation]: Runtime reachability gap — `/ → /about` has no UI link in `PlaceholderHomeScreen`, so the 7-tap debug menu is unreachable on pristine builds. Agent #2 patched the router temporarily to execute the visual walk, then reverted. Plan 02-04 will add a real UI affordance.
- [Phase 02-review-gate-foundation]: Cross-lens finding overlap handling convention — same-line findings captured by two different audit agents (e.g. `_onToggleVerbose(bool _)` in Agent #2 runtime lens AND Agent #3 style lens) are preserved under BOTH with explicit cross-reference rather than deduplicated. Audit transparency precedent for all future review gates.
- [Phase 02-review-gate-foundation]: Adversarial poison recipes routed through 02-02-SUMMARY.md rather than inlined into 02-03-PLAN.md — keeps recipe freshness (GPL status of `multi_dropdown` can drift between publisher versions) tied to audit wave and gives Plan 02-03 a single source of truth.
- [Phase 02-review-gate-foundation]: Adversarial poison branches pushed CI via inline on.push.branches += 'adversarial/**' trigger expansion on each throwaway branch — not on main. Main-branch trigger stays [main]-only after branch deletion; zero cleanup cost.
- [Phase 02-review-gate-foundation]: Adversarial Test 1 detection path: LICENSE substring match (voie 2 of _resolveSpdx at tool/check_licenses.dart:188-194), NOT _manualOverrides and NOT allowlist-miss — stderr prefix UNKNOWN-FORBIDDEN-MARKER: GNU GENERAL PUBLIC LICENSE uniquely identifies the branch.
- [Phase 02-review-gate-foundation]: Adversarial wave validated 3 of 4 check_licenses.dart Blockers (case-sensitivity, compound-AND, license-field bypass); Blocker #4 MPL-unreachable heuristic has no adversarial test — Plan 02-04 must add unit coverage.
- [Phase 03-persistence-domain-models]: Pin custom_lint 0.8.1 + riverpod_lint 3.1.0 — highest pair compatible with analyzer<9 stack — Closes Phase 01 deferred Open Question #1. flutter_lints 6.0.0 + riverpod_generator 4.0.0+1 both gate analyzer at <9; riverpod_lint 3.1.1+ requires analyzer ^9 which breaks custom_lint 0.8.1.
- [Phase 03-persistence-domain-models]: custom_lint family is Apache-2.0, not MIT (plan correction) — Verified by inspecting LICENSE preambles in pub cache — custom_lint, custom_lint_core, custom_lint_visitor are all Apache-2.0; only riverpod_lint is MIT. Apache-2.0 is on CLAUDE.md allowlist; no GOSL incompatibility. Correction documented in DEPENDENCIES.md row.
- [Phase 03-persistence-domain-models]: CI plain-Dart test step scoped to test/domain/ + test/infrastructure/ subdirs (not catch-all test/) — Existing test/*.dart at the repo root all import package:flutter_test and would crash under the plain-Dart runner. Scoping to subdirs that don't yet exist keeps the step inert until 03-02+ lands pure-Dart suites there. Plan's catch-all interpretation was unsafe.
- [Phase 03-persistence-domain-models]: Drift schema CI guard: drift_schema_current.json is rolling, drift_schema_v{1,2}.json are FROZEN — Dumping into the schemas directory (which the plan's first sketch implied) would overwrite the V1 fixture after a V2 bump and break SchemaVerifier round-trip tests forever. Guard rule: CI re-dumps the rolling current.json and git diff --exit-code proves it is fresh; version-specific snapshots are produced once and never touched.
- [Phase 03-persistence-domain-models]: Hand-rolled ULID in 91 lines (Crockford base32, 48-bit ms timestamp + 80-bit random tail) — zero new dep, k-sortable + reproducible-with-seed, matches CONTEXT.md commitment
- [Phase 03-persistence-domain-models]: All 6 ID wrappers as Dart 3 extension type const — zero runtime cost vs. plain String, compile-time rejects cross-type assignment (a class of bug SQLite cannot catch since both columns are TEXT)
- [Phase 03-persistence-domain-models]: ID prefix stored in the wrapped value (sess_<26 ULID chars>) rather than appended at JSON serialization — copy-pasted IDs are self-describing in logs / SQL inspector / bug reports
- [Phase 03-persistence-domain-models]: All 7 domain exceptions implement Exception (never extends Error) per CLAUDE.md §Error handling — Exception is recoverable, Error is for programming bugs
- [Phase 03-persistence-domain-models]: IdentityMigrationV1.fromVersion = -1 sentinel trick — keeps the class importable + symbolic without ever matching a real version transition; alternative (fromVersion = 1 with conditional) would have double-matched V1ToV2RenameRadius and triggered the duplicate-step failure path
- [Phase 03-persistence-domain-models]: Defensive .clamp(0, n-1) on slippy-map tile indices (auto-fixed Rule 1 - Bug) — float math near Mercator limit lat=±85.0511° produced y=-1 (north pole) and y=16384 (south pole, == n exactly) before the clamp; both out of valid array range
- [Phase 03-persistence-domain-models]: Envelope shipped by 03-03 (Freezed per ROADMAP SC#4) — 03-02 stops at the migration framework; the fixture-driven end-to-end JsonMigrator test is also moved to 03-03 since it depends on Envelope.fromJson. 03-03 now depends_on [03-01, 03-02] (Wave 3, not Wave 2)
- [Phase 03-persistence-domain-models]: Freezed 3.2.3 @Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown') IS supported — RESEARCH Open Question #5 CLOSED. Generator emits dispatching fromJson with UnknownConfig.fromJson fallback.
- [Phase 03-persistence-domain-models]: UnknownConfig.raw captured via @JsonKey(readValue: _readWholeMap) hook — hands the WHOLE source map to the converter instead of a nested 'raw' key. Hand-written dispatch alternative rejected (breaks variant fromJson generation).
- [Phase 03-persistence-domain-models]: JSON timestamp shape: split fields (startedAtUtc, startedAtOffsetMinutes) for Phase 03; combined ISO 8601 'startedAt' export deferred to Phase 13 SCHEMA.md. Either shape is round-trip safe; SC#5 JsonMigrator doesn't depend on shape.
- [Phase 03-persistence-domain-models]: factory (not const factory) on Freezed entities with @Assert — Dart 3.11 rejects method invocation (displayName.trim()) and even getter access (.isNotEmpty) inside const constructor asserts. Affects Session, Marker, MarkerCategory, MirkStyle; PhotoRef + RevealedTile keep const factory (no asserts).
- [Phase 03-persistence-domain-models]: Extension-type IDs need per-field @JsonKey(fromJson: fn, toJson: fn) with top-level converter functions (id_json_converters.dart) — class-level JsonConverter<SessionId, String> does NOT work because json_serializable collapses extension types to their underlying representation at the declared-type resolution boundary.
- [Phase 03-persistence-domain-models]: Envelope.fromJson must stay a pure arrow redirect — Freezed 3.2.3 needsJsonSerializable check requires ExpressionFunctionBody (lib/src/models.dart:1346). Validation lives in static Envelope.validateOrThrow; Envelope.parse composes validate + fromJson for the import boundary.
- [Phase 03-persistence-domain-models]: REVERSED 03-01 analyzer-<9 pin: dependency_overrides analyzer ^10.0.0 + dart_style 3.1.7 forces toolchain onto analyzer-10 because drift_dev 2.32.1 requires it; custom_lint 0.8.1 silently degrades until it ships analyzer-^10 support. Acceptable — no @riverpod targets yet; re-evaluate in 03-06.
- [Phase 03-persistence-domain-models]: V1ToV2Notes uses raw customStatement('ALTER TABLE ... ADD COLUMN') over m.addColumn — portable across Drift 2.x, no AppDatabase circular import, survives column-accessor renames.
- [Phase 03-persistence-domain-models]: AppDatabase exposes onBeforeUpgrade: Future<void> Function(OpeningDetails)? constructor hook — fires inside beforeOpen iff details.hadUpgrade BEFORE onUpgrade. 03-05 wires DbBackupService.takeBackup into it; details.hadUpgrade guard prevents bogus backups on first-open (onCreate) paths.
- [Phase 03-persistence-domain-models]: In-memory SQLite journal_mode always reports 'memory' — WAL requires an on-disk shared-memory region (sqlite.org/wal.html §2.1). Pragma unit test accepts observable; file-backed WAL verification lands in 03-05 integration.
- [Phase 03-persistence-domain-models]: Fixture reconciliation: v1_baseline.sql sessions 04+07 switched from status='paused' to 'stopped' (SessionStatus enum has only active|stopped). Forward-declared in 03-01-SUMMARY §Handoff as 03-04's responsibility.
- [Phase 03-persistence-domain-models]: V1ToV2Notes ALTER SQL locked to frozen V2 dump shape ('ADD COLUMN "notes" TEXT NULL' — quoted identifier + explicit NULL keyword) so SchemaVerifier.migrateAndValidate shape check passes. Retroactively ratifies the 03-04 migration framework.
- [Phase 03-persistence-domain-models]: Byte-count ordering proof for backup-before-onUpgrade — backup.lengthSync() == pre-open DB file size. Robust across Windows/ext4/APFS filesystem timestamp precisions; replaces mtime-based ordering proofs that were considered and rejected as flaky.
- [Phase 03-persistence-domain-models]: SchemaSanityChecker accepts growth silently (only throws on decrease) — CLAUDE.md error-handling level distinction preserves room for future onUpgrade seed-row patterns (e.g. Phase 15 default marker category).
- [Phase 03-persistence-domain-models]: buildAppDatabase uses NativeDatabase (sync) not createInBackground (isolate) — backup hook must run in same isolate as open; Phase 05 can swap to isolate variant if open-path profiling demands it.
- [Phase 03-persistence-domain-models]: Migration tests tagged @Tags(['migration']) — dart test -t migration isolates slow SchemaVerifier suite from fast domain suite; follows 03-01 dart_test.yaml convention.
- [Phase 03-persistence-domain-models]: SqliteException wrapping scope: only extendedResultCode == 2067 on DriftSessionStore.activate is rewrapped into ConcurrentActivationException. All other codes rethrown unchanged (RESEARCH pitfall #4 — never wide-catch driver errors).
- [Phase 03-persistence-domain-models]: DriftMarkerCategoryStore.delete protects kCategoryDefaultId by counting affected markers then throwing CategoryInUseException without touching the DB. markerCount carried in the exception for log reproducibility.
- [Phase 03-persistence-domain-models]: DriftRevealedTileStore takes IdGenerator but DriftMarkerStore does not — tile inserts happen inside mergeMask and mint ids on first write, while marker inserts carry pre-allocated MarkerIds. DriftSessionStore keeps IdGenerator in its constructor for forward-compat (Phase 05 may add SessionStore.create(displayName)).
- [Phase 03-persistence-domain-models]: Marker.photos hydrated as const <PhotoRef>[] in Phase 03 — photo join belongs with FilesystemPhotoStore (Phase 11, decision D8: photos on disk not SQLite BLOB).
- [Phase 03-persistence-domain-models]: All 7 @Riverpod providers use keepAlive: true — DB is a process singleton (re-opening thrashes WAL), and store providers keep the flag for symmetry/invalidate-storm avoidance.
- [Phase 03-persistence-domain-models]: main.dart ProviderScope wiring NOT touched in Phase 03 — CONTEXT.md defers it to Phase 05 where ActiveSessionController is the first productive consumer.
- [Phase 03-persistence-domain-models]: MirkStyle renderer_type column derived from sealed MirkStyleConfig variant via pattern match at insert/update time (AtmosphericConfig->atmospheric, ShaderConfig->shader, UnknownConfig->unknown). Keeps config+column consistent without a separate writer path.
- [Phase 03-persistence-domain-models]: Test convention: drift/drift.dart import uses 'hide isNotNull' in every store test — drift re-exports a column matcher with the same name as matcher's value matcher. Consistent idiom across infra test suite, same as 03-05 migration tests.
- [Phase 04-review-gate-persistence]: 'Aucune observation utilisateur' is valid §1 content — when user has no IDE findings, commit the explicit marker (not silence, not the 'awaiting user input' placeholder) so the grep sanity check passes and the user-first gate is satisfied
- [Phase 04-review-gate-persistence]: Review-gate Plan 01 template (scaffold + user-first §1 capture) validated on second cycle without modification — stable pattern reusable for Phases 06/08/10/12/14/16

### Pending Todos

None yet.

### Blockers/Concerns

**Phase 05 (POC GPS background):** Risque #1 projet. Si la validation background sur OEM Android ou iOS échoue, toute la V1.0 est remise en question. Doit être validé avant d'investir dans Map/Fog/Markers.

**Phase 05 (store policy):** Les strings de justification "Always" location doivent être rédigées humainement pour résister à une revue App Store / Play Store. Texte finalisé en Phase 15.

**Phase 09 (fog perf):** Sub-tile grid size (32/64/128) et batch-flush interval à profiler sur fixture 50k-tiles avant de finaliser les constantes.

**Phase 11 (EXIF strip):** `image_picker` ne strippe pas EXIF nativement ; approche lightweight à évaluer en début de Phase 11.

**Phase 13 (ZIP archive format):** Format ZIP final (.mirkfall extension, layout manifest/photos/) à confirmer au démarrage de la phase ; audit licence du package `archive` à documenter dans DEPENDENCIES.md (O11).

## Session Continuity

Last session: 2026-04-18T16:53:39.375Z
Stopped at: Completed 04-01-PLAN.md (scaffold + §1 user-first capture)
Resume file: None

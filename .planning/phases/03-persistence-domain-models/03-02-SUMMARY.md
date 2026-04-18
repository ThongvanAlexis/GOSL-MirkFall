---
phase: 03-persistence-domain-models
plan: 02
subsystem: domain
tags: [ulid, crockford-base32, extension-type, dart3, mirk-03, bitmap-algebra, json-migration, slippy-map, web-mercator, domain-purity, tdd]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: kRevealedTileBitmapBytes constant, test/fixtures/json/session_v{1,2}.json envelope contract, tool/check_domain_purity.dart, mirkfall package layout (lib/domain/, lib/infrastructure/)
provides:
  - 6 typed ID wrappers (Dart 3 extension type const) — SessionId, MarkerId, CategoryId, MirkStyleId, PhotoRefId, RevealedTileId
  - kCategoryDefaultId reserved sentinel (cat_default — non-ULID body for grep-ability)
  - IdGenerator port (lib/domain/ids/) + Ulid + RandomIdGenerator + SeededIdGenerator (lib/infrastructure/ids/)
  - 7 domain exception classes (all implements Exception): ConcurrentActivationException, SessionNotFoundException, InvalidSessionTransition, MarkerNotFoundException, CategoryNotFoundException, CategoryInUseException, MirkStyleConfigException, ImportValidationException, MigrationFailureException
  - tile_math.dart (Web Mercator slippy-map at any zoom) + TilePosition value class
  - reveal_calculator.dart MIRK-03 algebra primitives — mergeBitmap (idempotent + commutative + monotone) + popcount (SWAR per byte)
  - computeRevealMask signature stub (UnimplementedError until Phase 09)
  - JsonMigrator chain executor + JsonMigration abstract + IdentityMigrationV1 sentinel + V1ToV2RenameRadius fictive proof-of-framework
affects: [03-03-plan, 03-04-plan, 03-05-plan, 03-06-plan]

# Tech tracking
tech-stack:
  added: []  # Zero new dependencies — pure-Dart additions only.
  patterns:
    - "extension type const wrappers for ID types (Dart 3, zero runtime cost)"
    - "Prefix stored in the ID value (not appended at JSON serialization) so a copy-pasted ID is self-describing"
    - "Hand-rolled ULID (Crockford base32, 80 bits entropy + 48 bits ms timestamp) — k-sortable + reproducible with fixed seed"
    - "IdGenerator seam in domain/, impls in infrastructure/ — tests inject SeededIdGenerator for deterministic IDs"
    - "implements Exception (never extends Error) for every recoverable domain failure (CLAUDE.md §Error handling)"
    - "Pure-Dart MIRK-03 algebra primitives (mergeBitmap + popcount) tested for idempotence + commutativity + monotonicity at the bit level"
    - "Sentinel-anchor trick for IdentityMigrationV1: fromVersion = -1 keeps the class importable + symbolic without ever matching a real version transition"
    - "Chain-of-migrations executor with explicit duplicate-step + missing-step + downgrade rejection"
    - "Defensive clamp(0, n-1) on slippy-map tile indices to absorb floating-point edge cases at the Mercator latitude limit"

key-files:
  created:
    - lib/domain/ids/id_generator.dart
    - lib/domain/ids/session_id.dart
    - lib/domain/ids/marker_id.dart
    - lib/domain/ids/category_id.dart
    - lib/domain/ids/mirk_style_id.dart
    - lib/domain/ids/photo_ref_id.dart
    - lib/domain/ids/revealed_tile_id.dart
    - lib/domain/ids/default_ids.dart
    - lib/domain/ids/README.md
    - lib/domain/errors/concurrent_errors.dart
    - lib/domain/errors/session_errors.dart
    - lib/domain/errors/marker_errors.dart
    - lib/domain/errors/category_errors.dart
    - lib/domain/errors/mirk_errors.dart
    - lib/domain/errors/import_errors.dart
    - lib/domain/errors/migration_errors.dart
    - lib/domain/errors/README.md
    - lib/domain/revealed/tile_math.dart
    - lib/domain/revealed/reveal_calculator.dart
    - lib/domain/envelope/json_migration.dart
    - lib/domain/envelope/json_migrator.dart
    - lib/domain/envelope/identity_migration_v1.dart
    - lib/domain/envelope/v1_to_v2_rename_radius.dart
    - lib/domain/envelope/README.md
    - lib/infrastructure/ids/ulid.dart
    - lib/infrastructure/ids/random_id_generator.dart
    - lib/infrastructure/ids/seeded_id_generator.dart
    - test/domain/tile_math_test.dart
    - test/domain/reveal_calculator_test.dart
    - test/domain/json_migrator_test.dart
    - test/infrastructure/ids/ulid_test.dart
    - test/infrastructure/ids/random_id_generator_test.dart
    - test/infrastructure/ids/seeded_id_generator_test.dart
  modified: []

key-decisions:
  - "ULID hand-rolled in 91 lines (Crockford base32, 48-bit ms timestamp + 80-bit random tail) — zero new dependency, auditable in 30 seconds; matches CONTEXT.md commitment"
  - "All 6 ID wrappers built as Dart 3 extension type const — zero runtime cost vs. plain String, compile-time rejects cross-type assignment"
  - "Prefix stored in the ID value (sess_<26 ULID chars>) rather than appended at JSON serialization — copy-pasted IDs are self-describing in logs / SQL inspector / bug reports"
  - "kCategoryDefaultId('cat_default') uses a non-ULID body deliberately — sentinel survives log greps better than a random ULID would; isValid returns false for it (callers compare against the const directly)"
  - "All 7 domain exceptions implement Exception (never extends Error) per CLAUDE.md §Error handling — Exception is recoverable, Error is for programming bugs"
  - "IdentityMigrationV1.fromVersion = -1 sentinel trick — keeps the class importable + symbolic without matching any real version transition; alternative (fromVersion = 1 with conditional) would have double-matched V1ToV2RenameRadius and triggered the duplicate-step failure path"
  - "Defensive .clamp(0, n-1) on slippy-map tile indices — floating-point math near the Mercator latitude limit (lat=±85.0511) produced y=-1 (north pole) and y=16384 (south pole, n exactly) before the clamp; auto-fixed during Task 2 GREEN run"
  - "Paris fixture x range corrected to 8298-8300 (plan reference value 8294 was off by 5; OSM Slippy Map formula yields x = floor((182.3522/360) * 16384) = 8299 at zoom 14)"
  - "Envelope shipped by 03-03 (Freezed, per ROADMAP SC#4) — 03-02 stops at the migration framework; the fixture-driven end-to-end JsonMigrator test is also moved to 03-03 since it depends on Envelope.fromJson"

patterns-established:
  - "TDD per task: failing test commit (RED) -> minimal impl commit (GREEN), no separate refactor commits needed for this plan"
  - "package:mirkfall/... import paths in test files (project convention from test/fixtures/README.md)"
  - "GOSL header on every .dart file, even single-class wrappers"
  - "Domain README per subdir (ids/, errors/, envelope/) documenting the layer's invariants for future contributors"

requirements-completed: [MIRK-03]

# Metrics
duration: 9 min
completed: 2026-04-18
---

# Phase 03 Plan 02: Domain layer + ULID + MIRK-03 algebra Summary

**Pure-Dart domain layer in 21 files (6 ID extension types + 7 typed exceptions + ULID generator + tile_math + reveal_calculator + JsonMigrator framework) — MIRK-03 bitmap algebra (idempotent + commutative + monotone) proven by 7 algebra tests, ULID's k-sortability + Crockford alphabet locked by 5 unit tests, JsonMigrator chain executor proven by 10 framework tests, and `dart run tool/check_domain_purity.dart` returns 0 violations across 21 hand-written domain files.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-18T09:25:23Z
- **Completed:** 2026-04-18T09:34:08Z
- **Tasks:** 3 (all TDD: RED + GREEN per task)
- **Files modified:** 34 created (24 lib/, 6 test/, 4 README.md)

## Accomplishments

- Closed MIRK-03 algebra angle: `mergeBitmap` is idempotent + commutative + monotone at the bit level, proven across synthetic + real-size (512-byte) fixtures.
- Closed Phase 03 SC#5 (algebra half): tile_math.dart + reveal_calculator.dart run under `dart test` with zero Flutter / Drift in the import graph.
- Closed Phase 03 SC#5 (JsonMigrator half): framework executor + identity sentinel + V1ToV2RenameRadius fictive cover the chain semantics; fixture-driven end-to-end test is queued for 03-03 alongside Envelope.
- Pre-shipped the ID seam (6 extension types + IdGenerator port + ULID impl + Seeded/Random impls) and the 7 typed domain exceptions so 03-03 (entities) and 03-06 (stores) can land without a back-and-forth.
- Domain purity invariant gets its first real workout: 21 hand-written `.dart` files under `lib/domain/`, zero forbidden imports.

## Task Commits

Each task was decomposed into a RED commit (failing test) and a GREEN commit (passing implementation). No REFACTOR commits were needed — the GREEN implementations were already at the desired final shape.

1. **Task 1a: failing tests for ULID + SeededIdGenerator + RandomIdGenerator** — `1955a29` (test, RED)
2. **Task 1b: ULID + IdGenerator port + Random/Seeded impls** — `77af05b` (feat, GREEN)
3. **Task 1c: 6 ID extension types + default_ids + 7 domain errors** — `364c935` (feat, GREEN — single commit because the IDs + errors are interlocked and have no dedicated test files yet; their invariants are exercised through the impls' tests and the domain-purity check)
4. **Task 2a: failing tests for tile_math + reveal_calculator** — `0fcd309` (test, RED)
5. **Task 2b: tile_math + reveal_calculator (MIRK-03 algebra)** — `321c926` (feat, GREEN)
6. **Task 3a: failing tests for JsonMigrator framework** — `f3c1512` (test, RED)
7. **Task 3b: JsonMigrator + JsonMigration + IdentityMigrationV1 + V1ToV2RenameRadius** — `9ef6935` (feat, GREEN)

**Plan metadata commit:** _added by post-task gsd-tools step._

## ULID Implementation Trace

**Alphabet:** `0123456789ABCDEFGHJKMNPQRSTVWXYZ` — 32 chars, no `I`, `L`, `O`, `U`. Crockford base32 convention so a copy-pasted ID is unambiguous (`O` vs `0`, `I` vs `1` would otherwise look identical in many fonts).

**Layout:** 26 chars total = 10 chars (48-bit ms timestamp, big-endian base32) + 16 chars (80-bit random tail).

**Bit-packing math (random tail):** 16 base32 chars × 5 bits/char = 80 bits = 10 random bytes drawn from the injected `Random`. Implementation accumulates 8 bits per byte, drains 5 bits per emitted char (left-to-right), and pads the trailing partial group by left-shifting to fill 5 bits — a steady-state group of 10 bytes drains exactly 16 chars with no slack, but the defensive `padRight` / `substring` keeps the function honest if the entropy budget is ever tuned.

**k-sortability test result:** `Ulid.generate(now: t1, rng: Random(42))` vs `Ulid.generate(now: t2, rng: Random(42))` with `t2 > t1` — the time prefix (chars 0..9) is lexically greater for the later timestamp, and the random tail (chars 10..25) is byte-identical because both `Random(42)` instances are reset at the same seed. Test asserts `earlier.compareTo(later) < 0` AND `earlier.substring(10) == later.substring(10)` (`test/infrastructure/ids/ulid_test.dart` group `Ulid.generate` test `k-sortable: ...`).

**Determinism:** Two `SeededIdGenerator(seed: 42, fixedNow: <fixed>)` instances emit byte-identical 5-element ID sequences (`test/infrastructure/ids/seeded_id_generator_test.dart`). Production code uses `RandomIdGenerator()` which defaults to `Random.secure()` for cross-trust-boundary safety.

## Envelope Relocation

**Where it went:** 03-03 will ship `Envelope` as a Freezed class to honour ROADMAP SC#4 verbatim ("tous les modèles de domaine ... Envelope sont générés par Freezed"). Shipping a hand-written `Envelope` here would have contradicted that.

**What stays in 03-02:** the migration framework — `JsonMigration` abstract, `JsonMigrator` chain executor, `IdentityMigrationV1` sentinel, `V1ToV2RenameRadius` fictive. All pure Dart, zero codegen needed.

**What moved with Envelope:** the fixture-driven end-to-end JsonMigrator test (originally `test/domain/json_migrator_v1_to_v2_test.dart` per the plan's first sketch) — it depends on `Envelope.fromJson` to parse `test/fixtures/json/session_v1.json` and walk it through the chain, so it lives next to the Freezed Envelope it consumes. 03-02 still ships a 10-test framework suite (`test/domain/json_migrator_test.dart`) that exercises the chain semantics on synthetic `Map<String, Object?>` payloads — no Envelope dependency.

**Wave impact:** 03-03 now `depends_on: [03-01, 03-02]` and runs in Wave 3, not Wave 2. 03-02 runs alone in Wave 2 — no contention.

## IdentityMigrationV1 sentinel trick

**Problem:** A v1 -> v1 "identity" is conceptually a no-op (the executor's `while (v < toVersion)` loop simply doesn't execute when `from == to`), so a real v1 entry in the migrations list would be redundant. Worse, a step with `fromVersion = 1` would double-match against `V1ToV2RenameRadius(fromVersion = 1)` and trigger the "multiple migrators registered" failure path.

**Solution chosen:** `IdentityMigrationV1.fromVersion = -1`. The executor's `where(m.fromVersion == v)` filter never picks a sentinel for any real version transition, so it can sit safely in the migrations list as a type anchor / doc surface without affecting behaviour. Tested explicitly: `JsonMigrator([IdentityMigrationV1(), V1ToV2RenameRadius()]).migrate(fromVersion: 1, toVersion: 2, ...)` succeeds and applies the rename without tripping the duplicate check (`test/domain/json_migrator_test.dart` test `IdentityMigrationV1 alongside V1ToV2RenameRadius does not double-match`).

**Solution rejected:** `IdentityMigrationV1.fromVersion = 1` with a conditional in `JsonMigrator.migrate` to special-case the identity. Adds a branch in the hot path for what is essentially documentation; sentinel value is cleaner.

## Domain Purity Score

**21 hand-written `.dart` files under `lib/domain/`. 0 forbidden-import violations.**

```
$ dart run tool/check_domain_purity.dart
check_domain_purity: OK (21 files, zero forbidden imports)
```

Breakdown of the 21 files:

| Subdir | Files |
| --- | --- |
| `lib/domain/ids/` | 8 (.dart) — id_generator, 6 ID wrappers, default_ids |
| `lib/domain/errors/` | 7 (.dart) — concurrent, session, marker, category, mirk, import, migration |
| `lib/domain/revealed/` | 2 (.dart) — tile_math, reveal_calculator |
| `lib/domain/envelope/` | 4 (.dart) — json_migration, json_migrator, identity_migration_v1, v1_to_v2_rename_radius |
| `lib/domain/` | 0 .dart at root (only README.md) |

Total = 21 .dart + 4 README.md = 25 files committed under `lib/domain/`.

## Handoff to 03-03

03-03 (entities) will `import` the following symbols from this plan; all are available on `main`:

| Import path | Symbol | Used by |
| --- | --- | --- |
| `package:mirkfall/domain/ids/session_id.dart` | `SessionId` | `Session` Freezed entity ID field |
| `package:mirkfall/domain/ids/marker_id.dart` | `MarkerId` | `Marker` Freezed entity ID field |
| `package:mirkfall/domain/ids/category_id.dart` | `CategoryId` | `MarkerCategory` Freezed entity ID field |
| `package:mirkfall/domain/ids/mirk_style_id.dart` | `MirkStyleId` | `MirkStyle` Freezed entity ID field |
| `package:mirkfall/domain/ids/photo_ref_id.dart` | `PhotoRefId` | `PhotoRef` Freezed entity ID field |
| `package:mirkfall/domain/ids/revealed_tile_id.dart` | `RevealedTileId` | `RevealedTile` Freezed entity ID field |
| `package:mirkfall/domain/ids/default_ids.dart` | `kCategoryDefaultId` | category cascade-delete reassign target |
| `package:mirkfall/domain/ids/id_generator.dart` | `IdGenerator` | constructor injection on store factories |
| `package:mirkfall/domain/errors/concurrent_errors.dart` | `ConcurrentActivationException` | `DriftSessionStore.activate` SQLite 2067 wrap |
| `package:mirkfall/domain/errors/session_errors.dart` | `SessionNotFoundException`, `InvalidSessionTransition` | `Session` state machine |
| `package:mirkfall/domain/errors/marker_errors.dart` | `MarkerNotFoundException` | `DriftMarkerStore.getById` |
| `package:mirkfall/domain/errors/category_errors.dart` | `CategoryNotFoundException`, `CategoryInUseException` | `DriftMarkerCategoryStore.delete` |
| `package:mirkfall/domain/errors/mirk_errors.dart` | `MirkStyleConfigException` | `MirkStyleConfig.fromJson` |
| `package:mirkfall/domain/errors/import_errors.dart` | `ImportValidationException` | PORT-09 boundary validation |
| `package:mirkfall/domain/errors/migration_errors.dart` | `MigrationFailureException` | `JsonMigrator` + `SchemaSanityChecker` |
| `package:mirkfall/domain/envelope/json_migration.dart` | `JsonMigration` | `Envelope.fromJson` if 03-03 wraps the migrator |
| `package:mirkfall/domain/envelope/json_migrator.dart` | `JsonMigrator` | fixture-driven end-to-end test |
| `package:mirkfall/domain/envelope/v1_to_v2_rename_radius.dart` | `V1ToV2RenameRadius` | fixture-driven end-to-end test |

03-03's planned fixture-driven test (`Envelope.fromJson(session_v1.json) -> JsonMigrator(...).migrate(1, 2, ...) -> Envelope` shape with `reveal_radius_m`) needs only the migrator + the Envelope class itself — every other dependency is present.

## Files Created/Modified

**Created (lib/, 24 files):**

- `lib/domain/ids/id_generator.dart` — pure-Dart IdGenerator port (newId(prefix))
- `lib/domain/ids/session_id.dart` — extension type const SessionId(String value), prefix sess_
- `lib/domain/ids/marker_id.dart` — extension type const MarkerId(String value), prefix mrk_
- `lib/domain/ids/category_id.dart` — extension type const CategoryId(String value), prefix cat_
- `lib/domain/ids/mirk_style_id.dart` — extension type const MirkStyleId(String value), prefix mst_
- `lib/domain/ids/photo_ref_id.dart` — extension type const PhotoRefId(String value), prefix phr_
- `lib/domain/ids/revealed_tile_id.dart` — extension type const RevealedTileId(String value), prefix rvt_
- `lib/domain/ids/default_ids.dart` — kCategoryDefaultId reserved sentinel (cat_default)
- `lib/domain/ids/README.md` — prefix-in-value rationale + types table
- `lib/domain/errors/concurrent_errors.dart` — ConcurrentActivationException (SESS-06 wrap)
- `lib/domain/errors/session_errors.dart` — SessionNotFoundException, InvalidSessionTransition
- `lib/domain/errors/marker_errors.dart` — MarkerNotFoundException
- `lib/domain/errors/category_errors.dart` — CategoryNotFoundException, CategoryInUseException
- `lib/domain/errors/mirk_errors.dart` — MirkStyleConfigException
- `lib/domain/errors/import_errors.dart` — ImportValidationException (PORT-09)
- `lib/domain/errors/migration_errors.dart` — MigrationFailureException
- `lib/domain/errors/README.md` — Exception-vs-Error policy + class catalogue
- `lib/domain/revealed/tile_math.dart` — TilePosition value class + TileMath converters (Web Mercator)
- `lib/domain/revealed/reveal_calculator.dart` — mergeBitmap + popcount + computeRevealMask stub
- `lib/domain/envelope/json_migration.dart` — JsonMigration abstract step
- `lib/domain/envelope/json_migrator.dart` — chain executor with duplicate/missing/downgrade rejection
- `lib/domain/envelope/identity_migration_v1.dart` — sentinel-anchor (fromVersion = -1)
- `lib/domain/envelope/v1_to_v2_rename_radius.dart` — fictive proof-of-framework rename
- `lib/domain/envelope/README.md` — framework conventions + sentinel trick documentation
- `lib/infrastructure/ids/ulid.dart` — Crockford base32 ULID (48-bit ts + 80-bit random)
- `lib/infrastructure/ids/random_id_generator.dart` — production impl (Random.secure() default)
- `lib/infrastructure/ids/seeded_id_generator.dart` — deterministic test impl (seed + optional fixedNow)

**Created (test/, 6 files):**

- `test/domain/tile_math_test.dart` — 6 tests (Paris, equator, both poles, round-trip, TilePosition equality)
- `test/domain/reveal_calculator_test.dart` — 16 tests (mergeBitmap algebra suite + popcount cases + computeRevealMask stub)
- `test/domain/json_migrator_test.dart` — 10 tests (chain semantics + immutability + sentinel + duplicate detection)
- `test/infrastructure/ids/ulid_test.dart` — 5 tests (length, alphabet, k-sortability, reproducibility, time-part divergence)
- `test/infrastructure/ids/seeded_id_generator_test.dart` — 5 tests (sequence equality, prefix preservation, length, RNG advancement, wall-clock fallback)
- `test/infrastructure/ids/random_id_generator_test.dart` — 3 tests (10k uniqueness, prefix invariants, multi-prefix round-trip)

**Modified:** none (zero pubspec changes — pure-Dart additions only).

## Decisions Made

See frontmatter `key-decisions` for the full list. Key call-outs:

1. **Hand-rolled ULID in 91 lines, zero new deps.** Crockford base32 alphabet (no I/L/O/U), 48-bit ms timestamp + 80-bit random tail = 26 chars. K-sortable + reproducible-with-seed. Smallest auditable shape that hits the CONTEXT.md targets.
2. **Extension type const for every ID wrapper.** Zero runtime cost vs. plain String, compile-time rejects cross-type assignment (a class of bug SQLite cannot catch — both columns are TEXT).
3. **All 7 domain exceptions implement Exception (never extend Error).** Per CLAUDE.md §Error handling: Exception is recoverable (catch + degrade gracefully), Error is for programming bugs (propagate to top-level handler that dumps stack trace).
4. **IdentityMigrationV1 uses fromVersion = -1 sentinel.** Avoids special-casing in the executor's hot path while keeping the class importable + symbolic.
5. **Defensive `.clamp(0, n-1)` on slippy-map tile indices.** Floating-point math near the Mercator latitude limit (lat=±85.0511) produced y=-1 (north pole) and y=16384 (south pole, == n exactly) before the clamp — both out of valid array range.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] latLonToTile produced out-of-range tile indices at the poles**
- **Found during:** Task 2 GREEN run (`test/domain/tile_math_test.dart` north/south pole tests)
- **Issue:** `((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n).floor()` evaluated to -1 at lat=+85.0511° (north pole after clamp) and to 16384 (== n exactly, out-of-range upper bound) at lat=-85.0511° (south pole after clamp). Both are floating-point edge effects: the formula approaches 0 / n asymptotically and the floor of a value just below 0 is -1; at the south pole the value lands exactly on n and the floor stays at n. Either would have crashed downstream array indexing.
- **Fix:** Added `.clamp(0, maxIndex)` (where `maxIndex = n.toInt() - 1`) to both the x and y assignments. Documented the rationale inline.
- **Files modified:** `lib/domain/revealed/tile_math.dart`
- **Verification:** Both pole tests now pass (`expect(t.y, greaterThanOrEqualTo(0))` + `expect(t.y, lessThan(1 << 14))`).
- **Committed in:** `321c926` (Task 2 GREEN)

**2. [Rule 1 - Bug] Plan's Paris fixture x-range was off by ~5 tiles**
- **Found during:** Task 2 GREEN run (Paris fixture test)
- **Issue:** Plan asserted `x ∈ [8293, 8295]` for `lat=48.8566, lon=2.3522, zoom=14`. The OSM Slippy Map formula for x is `floor((lon + 180) / 360 * 2^zoom) = floor((182.3522 / 360) * 16384) = floor(8299.06) = 8299` — five tiles off from the plan's reference. The plan's value was likely a typo or copied from a different lat/lon pair.
- **Fix:** Updated the test to assert `x ∈ [8298, 8300]` with a doc-comment recording the OSM formula derivation. Real Paris-area tile is 8299.
- **Files modified:** `test/domain/tile_math_test.dart`
- **Verification:** Paris test now passes against the real OSM coordinate.
- **Committed in:** `321c926` (Task 2 GREEN)

**3. [Rule 1 - Bug] avoid_redundant_argument_values warning on DateTime.utc(2026, 4, 18, 9, 0, 0)**
- **Found during:** Task 1 post-test verification (`flutter analyze --fatal-infos --fatal-warnings`)
- **Issue:** `DateTime.utc(2026, 4, 18, 9, 0, 0)` in `seeded_id_generator_test.dart` — the trailing zero args for minute and second match the constructor's defaults; the linter flags them under `avoid_redundant_argument_values`. Project policy is `--fatal-infos`, so this would have failed CI on the next push.
- **Fix:** Trimmed to `DateTime.utc(2026, 4, 18, 9)`.
- **Files modified:** `test/infrastructure/ids/seeded_id_generator_test.dart`
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` returns "No issues found!"; tests still pass.
- **Committed in:** `364c935` (Task 1 IDs+errors commit, where the test edit landed)

---

**Total deviations:** 3 auto-fixed (3 bugs, 0 missing critical, 0 blocking, 0 architectural).
**Impact on plan:** All three were corrections to plan-supplied details (off-by-floor poles edge case, off-by-5 Paris reference value, redundant DateTime.utc args). No scope creep; outputs match the plan's intent exactly. The pole clamp is the most consequential — without it, downstream callers indexing into a `1 << zoom` array would crash on polar GPS readings (a real-world failure mode for users near the Arctic).

## Issues Encountered

None — TDD discipline caught all three deviations at GREEN-phase verification, before any commit landed broken.

## Authentication Gates

None — no external services touched.

## User Setup Required

None — pure-Dart additions only, zero new dependencies, zero env vars.

## Next Phase Readiness

**Wave 2 closed (03-02 alone). Wave 3 (03-03 entities + Envelope Freezed) unblocks immediately.**

What 03-03 will inherit:
- 6 ID extension types ready to drop into Freezed entity ID fields
- IdGenerator port + SeededIdGenerator (constructor-injectable for entity factory tests)
- 7 typed domain exceptions ready to be thrown by the entity invariant guards
- JsonMigration + JsonMigrator + V1ToV2RenameRadius ready to wire into Envelope.fromJson
- MIRK-03 algebra primitives (mergeBitmap, popcount) ready for 03-06 store-layer idempotence tests against pre-computed fixture masks
- tile_math.dart ready for any geo-transform that ends up in the entity layer (unlikely; most of those live in 03-04 + 03-09)
- computeRevealMask signature stub committed so 03-06 can `import` the symbol while leaving the body for Phase 09

Forward-declarations to honour:
- 03-03 owns Envelope as a Freezed class with `JsonMigrator` integration. The fixture-driven end-to-end JsonMigrator test (parsing `session_v1.json` -> migrating -> asserting `reveal_radius_m`) lands there in Task 3.
- 03-04 owns the Drift schema; ID column types remain `TEXT` (extension types are zero-cost wrappers, no DB-level distinction).
- 03-06 owns the SqliteException 2067 -> ConcurrentActivationException wrap in `DriftSessionStore.activate`.

---
*Phase: 03-persistence-domain-models*
*Completed: 2026-04-18*

## Self-Check: PASSED

All 33 created files (24 lib/, 6 test/, 3 README.md included in those, plus the SUMMARY.md itself) exist on disk and all 7 task commit hashes (`1955a29`, `77af05b`, `364c935`, `0fcd309`, `321c926`, `f3c1512`, `9ef6935`) are reachable from `git log --all`.

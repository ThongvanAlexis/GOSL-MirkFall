# domain/envelope/

Versioned JSON envelope migration framework (decision D9).

The `Envelope` data class itself is shipped by **03-03** (Freezed, per
ROADMAP SC#4). This directory hosts only the migration framework, which
is pure Dart and does not need codegen.

## Files

| File | Role |
| --- | --- |
| `json_migration.dart` | `JsonMigration` abstract — single `v_n -> v_n+1` step |
| `json_migrator.dart` | `JsonMigrator` chain executor — composes the list |
| `identity_migration_v1.dart` | `IdentityMigrationV1` — symbolic anchor (sentinel `fromVersion = -1`) |
| `v1_to_v2_rename_radius.dart` | `V1ToV2RenameRadius` — fictive proof-of-framework rename `mirk_radius_m -> reveal_radius_m` |

## Conventions

- **Migrations are additive.** A new `v2 -> v3` step is appended to the
  migrations list at the construction site. Existing tests stay green
  because the chain only walks the steps it needs.
- **Apply MUST NOT mutate the input map.** Every step returns a new
  `Map<String, Object?>`. The chain executor depends on this for the
  downgrade-detection path; tests assert it explicitly.
- **One step per transition.** Two steps with the same `fromVersion`
  trigger `MigrationFailureException("multiple migrators registered")`.
- **No skipping.** The chain refuses to execute if any
  `v_n -> v_n+1` step in the range is missing.

## IdentityMigrationV1 sentinel trick

A v1 -> v1 "identity" is conceptually a no-op — `JsonMigrator.migrate`'s
`while (v < toVersion)` loop simply does not execute when `from == to`.
So a real v1 entry in the migrations list would be redundant. Worse, a
step with `fromVersion = 1` would double-match against
`V1ToV2RenameRadius` and trigger the duplicate-step check.

`IdentityMigrationV1` solves both concerns by setting `fromVersion = -1`.
The migrator's `where(m.fromVersion == v)` filter never picks it for any
real version transition, so it can sit safely in the migrations list as
a type anchor / doc surface without affecting behaviour. Tested
explicitly in `test/domain/json_migrator_test.dart`.

## V1ToV2RenameRadius is fictive

The rename has no production consumer. It exists to prove the framework
end-to-end (test/domain/json_migrator_test.dart asserts the chain walk).
Delete this class the day a real v1 to v2 migration lands (probably
Phase 13 import format hardening).

# domain/errors/

Typed exceptions thrown by the domain layer. Every class here
`implements Exception` (never `extends Error`) per CLAUDE.md §Error
handling:

- `Error` is the language-built-in for **programming bugs** (null
  dereference, invariant violation). They propagate to the top-level
  handler which dumps the stack trace and crashes — that is the
  intended behaviour for a bug.
- `Exception` is the language-built-in for **recoverable failures**
  (DB busy, race, malformed payload). Code is expected to `try`/`catch`
  around the operation and degrade gracefully.

Every typed domain failure must therefore be an `Exception` subtype —
never an `Error`. The store layer wraps any raw third-party exception
(`SqliteException`, `IOException`, ...) into the matching domain
exception so the `application/` layer never imports infrastructure
types. See `concurrent_errors.dart` for the canonical wrap example.

## Catalogue

| File | Class | When |
| --- | --- | --- |
| `concurrent_errors.dart` | `ConcurrentActivationException` | SESS-06: two callers raced to activate a session |
| `session_errors.dart` | `SessionNotFoundException`, `InvalidSessionTransition` | session lookup miss / illegal state transition |
| `marker_errors.dart` | `MarkerNotFoundException` | marker lookup miss |
| `category_errors.dart` | `CategoryNotFoundException`, `CategoryInUseException` | category lookup miss / cascade-delete bypass refused |
| `mirk_errors.dart` | `MirkStyleConfigException` | MirkStyleConfig payload validation failed |
| `import_errors.dart` | `ImportValidationException` | PORT-09 import payload validation failed |
| `migration_errors.dart` | `MigrationFailureException` | JsonMigrator chain incomplete / Drift schema row-count diverged after onUpgrade |

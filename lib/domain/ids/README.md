# domain/ids/

Type-safe identifier wrappers for the persistence layer.

## Why `extension type const`

Each ID is a Dart 3 `extension type const XxxId(String value)`. At runtime
the value is a plain `String` — zero allocation, zero indirection. At
compile time the wrapper is a distinct type, so `MarkerId` cannot be
silently passed where a `SessionId` is expected (a class of bug
SQLite cannot catch on its own — both columns are TEXT).

## Why the prefix lives inside the value

Every ID stores its prefix in the wrapped string (e.g. `sess_01JBA...`)
rather than appending the prefix only at JSON serialization. Two
benefits:

1. A copy-pasted ID lifted from logs, the SQL inspector, or a bug
   report is immediately identifiable without context.
2. `isValid` becomes a pure-string check — no need for a separate
   "type" enum to disambiguate ID classes when validating import
   payloads.

## ID types

| Wrapper | Prefix | Body | Total length |
| --- | --- | --- | --- |
| `SessionId` | `sess_` | 26-char ULID | 31 |
| `MarkerId` | `mrk_` | 26-char ULID | 30 |
| `CategoryId` | `cat_` | 26-char ULID | 30 |
| `MirkStyleId` | `mst_` | 26-char ULID | 30 |
| `PhotoRefId` | `phr_` | 26-char ULID | 30 |
| `RevealedTileId` | `rvt_` | 26-char ULID | 30 |

## Reserved sentinels

`kCategoryDefaultId = CategoryId('cat_default')` — the reassign target
for the marker-category cascade-delete policy. Body is not a ULID by
design, so the sentinel stands out at a glance. `isValid` returns
`false` for it; callers that need to accept the sentinel should compare
against `kCategoryDefaultId` directly.

## Generator seam

The `IdGenerator` interface lives here (in `domain/`) so the domain layer
stays toolchain-independent. Concrete impls are in
`lib/infrastructure/ids/` (`RandomIdGenerator` for production,
`SeededIdGenerator` for tests).

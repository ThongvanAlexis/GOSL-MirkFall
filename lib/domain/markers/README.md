# lib/domain/markers/

Pure-Dart domain layer for geo-located markers + user-defined categories.
No `package:flutter` / `package:drift` imports (enforced by
`tool/check_domain_purity.dart`).

## Contents

- `marker.dart` — Freezed `Marker` entity (position + title + attached
  photos list + category + session FK). `@Assert` invariant: non-empty
  `title`.
- `marker_category.dart` — Freezed `MarkerCategory` (displayName + icon
  name). `@Assert` invariant: non-empty `displayName`.
- `marker_store.dart` — Abstract `MarkerStore` port.
- `marker_category_store.dart` — Abstract `MarkerCategoryStore` port.

## Invariants

- Every `Marker` belongs to exactly one `Session` (FK `sessionId`) and
  exactly one `MarkerCategory` (FK `categoryId`).
- Deleting a `MarkerCategory` reassigns its markers to
  [`kCategoryDefaultId`] (`cat_default`) inside the same transaction
  (CONTEXT.md §Politique cascade). Deleting `kCategoryDefaultId` itself
  is forbidden (`CategoryInUseException`).
- Photos are persisted on disk (Phase 11); the inlined `photos` list on a
  `Marker` is rehydrated from the photos store at read time.

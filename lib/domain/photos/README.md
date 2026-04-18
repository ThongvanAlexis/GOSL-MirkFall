# lib/domain/photos/

Pure-Dart domain layer for user-attached marker photos. No
`package:flutter` / `package:drift` imports (enforced by
`tool/check_domain_purity.dart`).

## Contents

- `photo_ref.dart` — Freezed `PhotoRef` entity (markerId FK + relative
  basename + dimensions + file size + timestamps).
- `photo_store.dart` — Abstract `PhotoStore` port. The filesystem-backed
  implementation (`FilesystemPhotoStore`) lands in Phase 11.

## Invariants

- Photos live on disk (decision D8: filesystem at
  `<app_documents>/photos/<markerId>/...`, NOT in a SQLite BLOB table —
  keeps the DB small and makes `path_provider` backups cheaper).
- `PhotoRef.relativeBasename` is the path relative to
  `<app_documents>/photos/` (e.g.
  `mrk_01JBA.../img_001.jpg`), stored verbatim so a rename of the root
  directory is transparent.
- Deleting a `Marker` cascades its `PhotoRef` rows AND deletes the files
  on disk (Phase 11 responsibility). Phase 03 ships only the port + the
  Freezed entity — no store implementation yet.

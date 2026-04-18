// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/marker_id.dart';
import '../ids/photo_ref_id.dart';
import 'photo_ref.dart';

/// Port for photo-reference persistence.
///
/// The filesystem-backed implementation (`FilesystemPhotoStore`) arrives in
/// Phase 11: photos live on disk at `<app_documents>/photos/<markerId>/...`
/// (decision D8), NOT in a SQLite BLOB table. Phase 03 ships the port + the
/// Freezed [PhotoRef] entity only — no impl, no persistence tests here.
///
/// The find-vs-require split mirrors the other stores (CONTEXT.md
/// §Stratégie erreurs).
abstract class PhotoStore {
  /// Returns every photo ref attached to [markerId], ordered by
  /// `createdAtUtc` ascending.
  Future<List<PhotoRef>> listByMarker(MarkerId markerId);

  /// Returns the photo ref with [id] or null (find semantic).
  Future<PhotoRef?> findById(PhotoRefId id);

  /// Returns the photo ref with [id] or throws (require semantic). The
  /// exact exception type is declared at the impl level — Phase 03 domain
  /// has no dedicated `PhotoRefNotFoundException` yet (Phase 11 will add
  /// it when the filesystem impl lands).
  Future<PhotoRef> requireById(PhotoRefId id);

  Future<void> insert(PhotoRef photo);

  /// Deletes [id] and the associated file on disk in the same logical
  /// unit of work. Phase 11 implementation details are captured in that
  /// phase's plan — the port only documents the contract.
  Future<void> delete(PhotoRefId id);
}

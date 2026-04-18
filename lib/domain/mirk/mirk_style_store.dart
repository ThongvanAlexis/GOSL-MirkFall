// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/mirk_style_id.dart';
import 'mirk_style.dart';

/// Port for mirk-style persistence.
///
/// Implementations live in `lib/infrastructure/stores/` (Phase 03-06 Drift
/// impl). MirkStyle rows are user-editable in Phase 09; Phase 03 ships the
/// port + the Freezed entity only.
abstract class MirkStyleStore {
  /// Returns every mirk style, ordered by display name.
  Future<List<MirkStyle>> listAll();

  /// Returns the style with [id] or null (find semantic).
  Future<MirkStyle?> findById(MirkStyleId id);

  /// Returns the style with [id] or throws (require semantic). The exact
  /// exception type is declared at the impl level — Phase 03 domain layer
  /// has no dedicated `MirkStyleNotFoundException` yet (Phase 09 will add
  /// it when the editor lands).
  Future<MirkStyle> requireById(MirkStyleId id);

  Future<void> insert(MirkStyle style);

  Future<void> update(MirkStyle style);

  Future<void> delete(MirkStyleId id);
}

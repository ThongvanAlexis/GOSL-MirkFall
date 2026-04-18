// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/category_id.dart';
import 'marker_category.dart';

/// Port for marker-category persistence + cascade policy.
///
/// Implementations live in `lib/infrastructure/stores/` (Phase 03-06 Drift
/// impl).
abstract class MarkerCategoryStore {
  /// Returns every category, including the reserved [`kCategoryDefaultId`],
  /// ordered by display name.
  Future<List<MarkerCategory>> listAll();

  /// Returns the category with [id] or null (find semantic).
  Future<MarkerCategory?> findById(CategoryId id);

  /// Returns the category with [id] or throws `CategoryNotFoundException`
  /// (require semantic).
  Future<MarkerCategory> requireById(CategoryId id);

  Future<void> insert(MarkerCategory category);

  Future<void> update(MarkerCategory category);

  /// Deletes [id] and, in the same transaction, reassigns every marker
  /// previously referencing [id] to [`kCategoryDefaultId`] (CONTEXT.md
  /// §Politique cascade).
  ///
  /// Deleting [`kCategoryDefaultId`] itself is forbidden: the reassign
  /// target must always exist. The Drift impl throws
  /// `CategoryInUseException` if a caller attempts it.
  Future<void> delete(CategoryId id);
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'category_id.dart';

/// Reserved category ID used by the marker-category cascade-delete policy
/// (CONTEXT.md §Politique cascade): when a custom category is deleted, all
/// markers that referenced it are reassigned to [`kCategoryDefaultId`] in
/// the same transaction, then the row itself is dropped.
///
/// The default category row is seeded by the `AppDatabase` `onCreate`
/// migration (04-rev Batch F fix for finding #2) — previously the symbol
/// was reserved but never seeded, which made `MarkerCategoryStore.delete`
/// blow up with `SQLITE_CONSTRAINT_FOREIGNKEY` on a fresh DB when reassign
/// targeted a row that did not exist yet. Phase 11 owns the UI to create
/// additional custom categories; the sentinel row itself is a Phase 03
/// schema invariant.
///
/// The body deliberately is NOT a ULID: a recognizable sentinel survives
/// log greps and SQL inspector reads better than a random ULID would.
const CategoryId kCategoryDefaultId = CategoryId('cat_default');

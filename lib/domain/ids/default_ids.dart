// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'category_id.dart';

/// Reserved category ID used by the marker-category cascade-delete policy
/// (CONTEXT.md §Politique cascade): when a custom category is deleted, all
/// markers that referenced it are reassigned to [`kCategoryDefaultId`] in
/// the same transaction, then the row itself is dropped.
///
/// The default category row is seeded by Phase 11 (markers + icons) — Phase
/// 03 only reserves the ID slot so the deletion logic (and its tests) can
/// compile and reference the symbol.
///
/// The body deliberately is NOT a ULID: a recognizable sentinel survives
/// log greps and SQL inspector reads better than a random ULID would.
const CategoryId kCategoryDefaultId = CategoryId('cat_default');

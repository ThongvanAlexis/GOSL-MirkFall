// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/category_id.dart';

/// Thrown when a category lookup-by-ID returns no row.
class CategoryNotFoundException implements Exception {
  const CategoryNotFoundException({required this.id});

  final CategoryId id;

  @override
  String toString() => 'CategoryNotFoundException(id=${id.value})';
}

/// Reserved for Phase 11 — thrown when a caller bypasses the
/// reassign-to-default cascade and tries to delete a category still
/// referenced by markers.
///
/// 03-06 always reassigns to [`kCategoryDefaultId`] in the same
/// transaction, so this exception never surfaces in the default flow;
/// it exists so a future caller that opts out of the reassign step
/// (e.g. an admin import path) can be told why the deletion failed.
class CategoryInUseException implements Exception {
  const CategoryInUseException({required this.id, required this.markerCount});

  final CategoryId id;
  final int markerCount;

  @override
  String toString() => 'CategoryInUseException(id=${id.value}, markerCount=$markerCount)';
}

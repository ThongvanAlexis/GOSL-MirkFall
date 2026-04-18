// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/category_id.dart';
import '../ids/id_json_converters.dart';

part 'marker_category.freezed.dart';
part 'marker_category.g.dart';

/// User-defined marker category (display name + icon).
///
/// The reserved [`kCategoryDefaultId`] is the reassign target when a custom
/// category is deleted (see CONTEXT.md §Politique cascade). Its row is
/// seeded by Phase 11; Phase 03 only reserves the ID slot.
@freezed
abstract class MarkerCategory with _$MarkerCategory {
  @Assert(
    'displayName.trim().isNotEmpty',
    'MarkerCategory.displayName must be non-empty',
  )
  factory MarkerCategory({
    @JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson)
    required CategoryId id,
    required String displayName,
    required String iconName,
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
  }) = _MarkerCategory;

  factory MarkerCategory.fromJson(Map<String, Object?> json) =>
      _$MarkerCategoryFromJson(json);
}

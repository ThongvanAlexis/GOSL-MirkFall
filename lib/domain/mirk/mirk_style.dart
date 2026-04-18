// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/id_json_converters.dart';
import '../ids/mirk_style_id.dart';
import 'mirk_style_config.dart';

part 'mirk_style.freezed.dart';
part 'mirk_style.g.dart';

/// Named, user-selectable fog rendering style.
///
/// The renderer-specific parameters live in [config] (sealed union) —
/// `MirkStyle` itself is the metadata wrapper (display name + id + creation
/// timestamp). See CONTEXT.md §MirkStyle seam for the render-side contract.
@freezed
abstract class MirkStyle with _$MirkStyle {
  @Assert('displayName.trim().isNotEmpty', 'MirkStyle.displayName must be non-empty')
  factory MirkStyle({
    @JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson) required MirkStyleId id,
    required String displayName,
    required MirkStyleConfig config,
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
  }) = _MirkStyle;

  factory MirkStyle.fromJson(Map<String, Object?> json) => _$MirkStyleFromJson(json);
}

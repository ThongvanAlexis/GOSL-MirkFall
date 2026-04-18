// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/id_json_converters.dart';
import '../ids/marker_id.dart';
import '../ids/photo_ref_id.dart';

part 'photo_ref.freezed.dart';
part 'photo_ref.g.dart';

/// Reference to a photo stored on the filesystem, attached to a marker.
///
/// [relativeBasename] is relative to `<app_documents>/photos/` (decision D8 —
/// photos live on disk, not inside the SQLite blob table, for size + backup
/// friendliness). The filesystem-backed implementation arrives in Phase 11.
@freezed
abstract class PhotoRef with _$PhotoRef {
  @Assert('widthPx > 0', 'PhotoRef.widthPx must be > 0')
  @Assert('heightPx > 0', 'PhotoRef.heightPx must be > 0')
  @Assert('fileSizeBytes > 0', 'PhotoRef.fileSizeBytes must be > 0')
  @Assert('createdAtOffsetMinutes >= -720 && createdAtOffsetMinutes <= 840', 'PhotoRef.createdAtOffsetMinutes out of range (UTC-12 to UTC+14)')
  const factory PhotoRef({
    @JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson) required PhotoRefId id,
    @JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) required MarkerId markerId,
    required String relativeBasename,
    required int widthPx,
    required int heightPx,
    required int fileSizeBytes,
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
  }) = _PhotoRef;

  factory PhotoRef.fromJson(Map<String, Object?> json) => _$PhotoRefFromJson(json);
}

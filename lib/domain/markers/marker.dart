// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/category_id.dart';
import '../ids/id_json_converters.dart';
import '../ids/marker_id.dart';
import '../ids/session_id.dart';
import '../photos/photo_ref.dart';

part 'marker.freezed.dart';
part 'marker.g.dart';

/// Geo-located marker dropped by the user during a [Session].
///
/// Every marker belongs to exactly one session (FK `sessionId`) and exactly
/// one category (FK `categoryId`). Attached photos travel with the marker
/// through the import/export pipeline — the inlined [photos] list is
/// rehydrated from the photos store at read time.
@freezed
abstract class Marker with _$Marker {
  @Assert('title.trim().isNotEmpty', 'Marker.title must be non-empty')
  factory Marker({
    @JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) required MarkerId id,
    @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) required SessionId sessionId,
    @JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) required CategoryId categoryId,
    required double lat,
    required double lon,
    required String title,
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
    String? notes,
    @Default(<PhotoRef>[]) List<PhotoRef> photos,
  }) = _Marker;

  factory Marker.fromJson(Map<String, Object?> json) => _$MarkerFromJson(json);
}

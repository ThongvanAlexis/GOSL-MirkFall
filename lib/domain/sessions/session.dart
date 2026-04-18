// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/id_json_converters.dart';
import '../ids/session_id.dart';
import 'session_status.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// Tracking session — a time-bounded period during which GPS fixes are
/// recorded and the mirk is revealed (SESS-* requirements).
///
/// Carries both [startedAtUtc] (UTC instant) and [startedAtOffsetMinutes]
/// (wall-clock offset at session start) per CONTEXT.md §DateTime strategy:
/// the pair is sufficient to reconstruct the local wall-clock a user saw
/// when they started the session, even if the device has since moved
/// between time zones.
///
/// Phase 03 ships JSON with split fields `(startedAtUtc, startedAtOffsetMinutes)`;
/// the Phase 13 SCHEMA.md finalization will decide whether to collapse
/// them into a single combined ISO 8601 `"startedAt"` string for export
/// readability. Either representation is round-trip safe.
@freezed
abstract class Session with _$Session {
  @Assert('displayName.trim().isNotEmpty', 'Session.displayName must be non-empty')
  @Assert('startedAtOffsetMinutes >= -720 && startedAtOffsetMinutes <= 840', 'Session.startedAtOffsetMinutes out of range (UTC-12 to UTC+14)')
  @Assert(
    'stoppedAtOffsetMinutes == null || (stoppedAtOffsetMinutes >= -720 && stoppedAtOffsetMinutes <= 840)',
    'Session.stoppedAtOffsetMinutes out of range (UTC-12 to UTC+14)',
  )
  factory Session({
    @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) required SessionId id,
    required String displayName,
    required SessionStatus status,
    required DateTime startedAtUtc,
    required int startedAtOffsetMinutes,
    DateTime? stoppedAtUtc,
    int? stoppedAtOffsetMinutes,
    String? notes,
  }) = _Session;

  factory Session.fromJson(Map<String, Object?> json) => _$SessionFromJson(json);
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/id_json_converters.dart';
import '../ids/mirk_style_id.dart';
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
///
/// Phase 09 plan 09-05: [mirkStyleId] is the per-session pointer to a
/// `MirkStyle` row. `null` means "no explicit selection — render with the
/// default atmospheric style"; a non-null value referencing a deleted style
/// also degrades to the atmospheric default at the renderer-resolution
/// layer (`activeMirkRendererProvider`). The DB-side FK uses
/// `ON DELETE SET NULL` so a deleted style does not orphan the session row;
/// see `migrations/v3_to_v4_session_mirk_style.dart`.
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
    @JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable) MirkStyleId? mirkStyleId,
  }) = _Session;

  factory Session.fromJson(Map<String, Object?> json) => _$SessionFromJson(json);
}

/// Nullable JSON converter for [MirkStyleId] — wraps [mirkStyleIdFromJson]
/// with the null-passthrough semantics needed for Freezed optional fields.
///
/// `id_json_converters.dart` exposes only the non-null pair (extension types
/// cannot be `T extends Object?` in `JsonConverter`); the optional Session
/// field needs its own pair so json_serializable does not try to call the
/// non-null converter with `null`.
MirkStyleId? _mirkStyleIdFromJsonNullable(String? json) => json == null ? null : mirkStyleIdFromJson(json);

String? _mirkStyleIdToJsonNullable(MirkStyleId? value) => value == null ? null : mirkStyleIdToJson(value);

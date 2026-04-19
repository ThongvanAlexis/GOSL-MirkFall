// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — @JsonKey is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection (mirrors the
// carve-out already documented in lib/domain/sessions/session.dart).

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/fix_id.dart';
import '../ids/id_json_converters.dart';
import '../ids/session_id.dart';

part 'fix.freezed.dart';
part 'fix.g.dart';

/// A single GPS fix recorded during a session. One-to-many with `Session`.
///
/// `@Assert` invariants mirror the DB CHECKs on `t_fixes`. The domain
/// REJECTS invalid instances at construction time, which guarantees that
/// a CHECK-violation SqliteException at the store layer is always an
/// infrastructure bug (e.g. bypassing the converter), never a domain
/// contract break.
///
/// Literal-bound `@Assert` expressions (`-720`, `840`) echo
/// `kMinUtcOffsetMinutes` / `kMaxUtcOffsetMinutes` from
/// `lib/config/constants.dart`. Freezed `@Assert('expr', 'msg')`
/// evaluates the expression STRING at compile-time and annotation bodies
/// cannot reference top-level `const int` identifiers inside the string,
/// so the literal is paired with a test-level guard (see
/// `test/domain/fix_invariants_test.dart`) referencing the constant —
/// same carve-out pattern already used for `Session.startedAtOffsetMinutes`.
///
/// `factory` (not `const factory`) — Phase 03 precedent for Freezed
/// classes with `@Assert`s that call getters (`displayName.trim()` etc.):
/// Dart 3.11 rejects method invocation inside const constructor asserts.
/// No methods are invoked here, but keeping `factory` keeps Phase 03
/// consistency and leaves room for future asserts that read getters.
@freezed
abstract class Fix with _$Fix {
  @Assert('latitude >= -90.0 && latitude <= 90.0', 'Fix.latitude out of [-90, 90]')
  @Assert('longitude >= -180.0 && longitude <= 180.0', 'Fix.longitude out of [-180, 180]')
  @Assert('accuracyMeters >= 0.0', 'Fix.accuracyMeters must be non-negative')
  @Assert('recordedAtOffsetMinutes >= -720 && recordedAtOffsetMinutes <= 840', 'Fix.recordedAtOffsetMinutes out of range (UTC-12 to UTC+14)')
  factory Fix({
    @JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson) required FixId id,
    @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) required SessionId sessionId,
    required DateTime recordedAtUtc,
    required int recordedAtOffsetMinutes,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    double? altitudeMeters,
    double? speedMps,
    double? headingDegrees,
  }) = _Fix;

  factory Fix.fromJson(Map<String, Object?> json) => _$FixFromJson(json);
}

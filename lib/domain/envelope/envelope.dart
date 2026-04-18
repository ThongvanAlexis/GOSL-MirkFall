// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../errors/import_errors.dart';

part 'envelope.freezed.dart';
part 'envelope.g.dart';

/// Versioned JSON envelope for import/export (decision D9).
///
/// Shape: `{ schemaVersion: int, type: string, payload: {...} }`. Every
/// shareable document wraps its body in this envelope so [`JsonMigrator`]
/// can read [schemaVersion] and dispatch migrations before handing
/// [payload] to the appropriate entity factory.
///
/// [Envelope.fromJson] pre-validates the shape and throws
/// `ImportValidationException` on malformed input. The exception surfaces
/// the user-facing reason directly (PORT-09 boundary validation).
@freezed
abstract class Envelope with _$Envelope {
  const factory Envelope({
    required int schemaVersion,
    required String type,
    @JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson)
    required Map<String, Object?> payload,
  }) = _Envelope;

  /// Parses [json] into an [Envelope].
  ///
  /// Must remain a bare redirect to `_$EnvelopeFromJson(json)` — any
  /// other shape stops Freezed from emitting the `@JsonSerializable`
  /// annotation on the generated class, breaking codegen. Pre-validation
  /// lives in the static [validateOrThrow] helper; callers that want
  /// the domain exception (`ImportValidationException`) call
  /// [validateOrThrow] first and then [Envelope.fromJson].
  factory Envelope.fromJson(Map<String, Object?> json) =>
      _$EnvelopeFromJson(json);

  /// Pre-validates [json] and throws [ImportValidationException] on any
  /// missing or malformed required key. Call before [Envelope.fromJson]
  /// at the import boundary so the caller sees the domain exception with
  /// a user-readable `reason` instead of a codegen-level
  /// `CheckedFromJsonException`.
  static void validateOrThrow(Map<String, Object?> json) {
    final Object? rawVersion = json['schemaVersion'];
    if (rawVersion is! int) {
      throw ImportValidationException(
        reason:
            'envelope: schemaVersion must be an int, got ${rawVersion?.runtimeType ?? 'missing'}',
      );
    }
    final Object? rawType = json['type'];
    if (rawType is! String || rawType.isEmpty) {
      throw const ImportValidationException(
        reason: 'envelope: type must be a non-empty string',
      );
    }
    final Object? rawPayload = json['payload'];
    if (rawPayload is! Map) {
      throw ImportValidationException(
        reason:
            'envelope: payload must be an object, got ${rawPayload?.runtimeType ?? 'missing'}',
      );
    }
  }

  /// Convenience: validate + parse in one call. Semantics identical to
  /// `Envelope.validateOrThrow(json); return Envelope.fromJson(json);`.
  /// Prefer this at the import boundary; prefer [Envelope.fromJson] for
  /// internal-only uses where the shape is already trusted.
  static Envelope parse(Map<String, Object?> json) {
    validateOrThrow(json);
    return Envelope.fromJson(json);
  }
}

/// Converter from JSON → `Map<String, Object?>` for [Envelope.payload].
///
/// json_serializable hands us a `Map<String, dynamic>` (its default map
/// representation); we upgrade it to the strictly typed domain form so
/// the rest of the codebase works with `Object?` values under
/// `strict-casts`.
Map<String, Object?> _payloadFromJson(Map<String, dynamic> raw) =>
    Map<String, Object?>.from(raw);

/// Converter from `Map<String, Object?>` → JSON for [Envelope.payload].
///
/// Returns a fresh `Map<String, dynamic>` so the caller cannot mutate the
/// envelope's internal state by editing the returned reference.
Map<String, dynamic> _payloadToJson(Map<String, Object?> payload) =>
    Map<String, dynamic>.from(payload);

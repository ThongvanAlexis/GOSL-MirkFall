// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'mirk_style_config.freezed.dart';
part 'mirk_style_config.g.dart';

/// Renderer-specific configuration attached to a [MirkStyle].
///
/// Sealed union — exhaustive switch at the render call site (Phase 09).
/// Unknown `rendererType` values (imports from future app versions, or a
/// payload produced by an adversarial/unknown source) fall through to
/// [UnknownConfig] carrying the raw map, preserving data survival across
/// version skew without requiring an app upgrade (decision D9 — forward
/// compatibility through version-carrying envelopes).
///
/// Implementation notes:
/// * `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` — Freezed
///   3.2.3 accepts both named params. The generator emits a `fromJson`
///   dispatching on `rendererType` and falling back to
///   [UnknownConfig.fromJson] on any unrecognized value.
/// * [UnknownConfig.raw] is read via `@JsonKey(fromJson: _passThroughMap,
///   toJson: _passThroughMap)` so the "raw" field captures the ENTIRE
///   source payload (not just a nested `'raw'` key). The helper is
///   declared at the bottom of this file.
@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')
sealed class MirkStyleConfig with _$MirkStyleConfig {
  /// Atmospheric fog — base color + procedural noise.
  const factory MirkStyleConfig.atmospheric({
    @Default(0xFF000000) int baseColorArgb,
    @Default(0.5) double noiseScale,
  }) = AtmosphericConfig;

  /// GPU shader-backed fog (Phase 09 advanced renderer).
  const factory MirkStyleConfig.shader({required String shaderAssetPath}) =
      ShaderConfig;

  /// Forward-compatibility fallback: preserves the original JSON map verbatim
  /// when the local app version does not recognize `rendererType`. The
  /// special `@JsonKey` converters on [raw] make the generated
  /// `UnknownConfig.fromJson(json)` capture the WHOLE `json` map into
  /// [raw] instead of looking for a nested `'raw'` key.
  const factory MirkStyleConfig.unknown({
    @JsonKey(
      fromJson: _unknownRawFromJson,
      toJson: _unknownRawToJson,
      disallowNullValue: true,
      readValue: _readWholeMap,
    )
    required Map<String, Object?> raw,
  }) = UnknownConfig;

  factory MirkStyleConfig.fromJson(Map<String, Object?> json) =>
      _$MirkStyleConfigFromJson(json);
}

/// `readValue` hook — instructs json_serializable to pass the ENTIRE source
/// map (not a nested field) to the `fromJson` converter for [UnknownConfig.raw].
/// The [_] argument is the field name json_serializable was going to look
/// up; ignoring it means we always return the parent map.
Object? _readWholeMap(Map<Object?, Object?> map, String _) => map;

/// Converter from raw JSON → `Map<String, Object?>`. Accepts either a
/// pre-typed map (test-constructed) or the untyped shape produced by
/// `jsonDecode` (`Map<String, dynamic>`).
Map<String, Object?> _unknownRawFromJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return <String, Object?>{};
}

/// Converter `Map<String, Object?>` → JSON. Returns the map unchanged so
/// `MirkStyleConfigToJson` on an unknown variant is byte-equal to the
/// original payload.
Map<String, Object?> _unknownRawToJson(Map<String, Object?> value) => value;

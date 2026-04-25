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
/// ## Phase 09 extension (plan 09-02)
///
/// Phase 03 shipped 3 variants (`atmospheric`, `shader`, `unknown`).
/// Phase 09 promotes the sealed union to its **6-variant target**:
///
/// * `atmospheric` — extended with 6 new params (all `@Default`-guarded
///   so Phase 03 callers stay compatible). Drives the noise-animated
///   default fog.
/// * `solid` — minimalist proof-of-seam: uniform colour fill, no animation.
/// * `candlelight` — warm radial flicker centred on the current GPS fix.
/// * `heavenly` — light drifting clouds (note the JSON discriminator is
///   `heavenly`, NOT `heavenly_clouds` — the renderer class name is
///   [HeavenlyCloudsConfig] but the wire shape uses the shorter token
///   per research §Registration Pattern Choice).
/// * `shader` — UNCHANGED Phase 03 stub. Renderer body lands in Phase 13.
/// * `unknown` — UNCHANGED forward-compat fallback.
///
/// Implementation notes:
/// * `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` — Freezed
///   3.2.5 accepts both named params. The generator emits a `fromJson`
///   dispatching on `rendererType` and falling back to
///   [UnknownConfig.fromJson] on any unrecognized value.
/// * [UnknownConfig.raw] is read via `@JsonKey(fromJson: _passThroughMap,
///   toJson: _passThroughMap)` so the "raw" field captures the ENTIRE
///   source payload (not just a nested `'raw'` key). The helper is
///   declared at the bottom of this file.
@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')
sealed class MirkStyleConfig with _$MirkStyleConfig {
  /// Atmospheric fog — base color + procedural noise. **Phase 09: 8 params.**
  ///
  /// New params (Phase 09) all `@Default`-guarded so Phase 03 / 04 callers
  /// using only `baseColorArgb` + `noiseScale` continue to compile +
  /// fromJson-deserialize unchanged.
  const factory MirkStyleConfig.atmospheric({
    @Default(0xFF000000) int baseColorArgb,
    int? secondaryColorArgb,
    @Default(0.5) double noiseScale,
    @Default(0.05) double noiseSpeed,
    @Default(0.0) double driftDirectionDeg,
    @Default(0.99) double densityBaselineAlpha,
    @Default(0.1) double featherRadiusFraction,
    @Default(0.5) double edgeSoftness,
  }) = AtmosphericConfig;

  /// Solid fill — no noise, no animation. Proof-of-seam minimalist.
  const factory MirkStyleConfig.solid({@Default(0xFF1A1A1A) int colorArgb, @Default(0.99) double baselineAlpha}) = SolidConfig;

  /// Warm candlelight glow with high-frequency flicker.
  const factory MirkStyleConfig.candlelight({
    @Default(0xFFFF8F6A) int centerColorArgb,
    @Default(0xFFC2542E) int peripheryColorArgb,
    @Default(0.8) double noiseScale,
    @Default(0.1) double noiseSpeed,
    @Default(0.85) double baselineAlpha,
    @Default(0.1) double featherRadiusFraction,
  }) = CandlelightConfig;

  /// Light drifting clouds — airy explorer feel.
  ///
  /// Note: the JSON discriminator is `"heavenly"` (NOT `"heavenly_clouds"`)
  /// per research §Registration Pattern Choice — the class name keeps the
  /// long form (`HeavenlyCloudsConfig`) for readability while the wire
  /// shape uses the short token shared with the user-facing UI label.
  const factory MirkStyleConfig.heavenly({
    @Default(0xFFE8E8EE) int colorArgb,
    @Default(0.3) double noiseScale,
    @Default(0.08) double noiseSpeed,
    @Default(45.0) double driftDirectionDeg,
    @Default(0.80) double baselineAlpha,
  }) = HeavenlyCloudsConfig;

  /// GPU shader-backed fog (Phase 09 advanced renderer — body lands in Phase 13).
  const factory MirkStyleConfig.shader({required String shaderAssetPath}) = ShaderConfig;

  /// Forward-compatibility fallback: preserves the original JSON map verbatim
  /// when the local app version does not recognize `rendererType`. The
  /// special `@JsonKey` converters on [raw] make the generated
  /// `UnknownConfig.fromJson(json)` capture the WHOLE `json` map into
  /// [raw] instead of looking for a nested `'raw'` key.
  const factory MirkStyleConfig.unknown({
    @JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap) required Map<String, Object?> raw,
  }) = UnknownConfig;

  factory MirkStyleConfig.fromJson(Map<String, Object?> json) => _$MirkStyleConfigFromJson(json);
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirk_style_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AtmosphericConfig _$AtmosphericConfigFromJson(Map<String, dynamic> json) =>
    AtmosphericConfig(
      baseColorArgb: (json['baseColorArgb'] as num?)?.toInt() ?? 0xFF000000,
      secondaryColorArgb: (json['secondaryColorArgb'] as num?)?.toInt(),
      noiseScale: (json['noiseScale'] as num?)?.toDouble() ?? 0.5,
      noiseSpeed: (json['noiseSpeed'] as num?)?.toDouble() ?? 0.05,
      driftDirectionDeg: (json['driftDirectionDeg'] as num?)?.toDouble() ?? 0.0,
      densityBaselineAlpha:
          (json['densityBaselineAlpha'] as num?)?.toDouble() ?? 0.99,
      featherRadiusFraction:
          (json['featherRadiusFraction'] as num?)?.toDouble() ?? 0.1,
      edgeSoftness: (json['edgeSoftness'] as num?)?.toDouble() ?? 0.5,
      $type: json['rendererType'] as String?,
    );

Map<String, dynamic> _$AtmosphericConfigToJson(AtmosphericConfig instance) =>
    <String, dynamic>{
      'baseColorArgb': instance.baseColorArgb,
      'secondaryColorArgb': instance.secondaryColorArgb,
      'noiseScale': instance.noiseScale,
      'noiseSpeed': instance.noiseSpeed,
      'driftDirectionDeg': instance.driftDirectionDeg,
      'densityBaselineAlpha': instance.densityBaselineAlpha,
      'featherRadiusFraction': instance.featherRadiusFraction,
      'edgeSoftness': instance.edgeSoftness,
      'rendererType': instance.$type,
    };

SolidConfig _$SolidConfigFromJson(Map<String, dynamic> json) => SolidConfig(
  colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFF1A1A1A,
  baselineAlpha: (json['baselineAlpha'] as num?)?.toDouble() ?? 0.99,
  $type: json['rendererType'] as String?,
);

Map<String, dynamic> _$SolidConfigToJson(SolidConfig instance) =>
    <String, dynamic>{
      'colorArgb': instance.colorArgb,
      'baselineAlpha': instance.baselineAlpha,
      'rendererType': instance.$type,
    };

CandlelightConfig _$CandlelightConfigFromJson(Map<String, dynamic> json) =>
    CandlelightConfig(
      centerColorArgb: (json['centerColorArgb'] as num?)?.toInt() ?? 0xFFFF8F6A,
      peripheryColorArgb:
          (json['peripheryColorArgb'] as num?)?.toInt() ?? 0xFFC2542E,
      noiseScale: (json['noiseScale'] as num?)?.toDouble() ?? 0.8,
      noiseSpeed: (json['noiseSpeed'] as num?)?.toDouble() ?? 0.1,
      baselineAlpha: (json['baselineAlpha'] as num?)?.toDouble() ?? 0.85,
      featherRadiusFraction:
          (json['featherRadiusFraction'] as num?)?.toDouble() ?? 0.1,
      $type: json['rendererType'] as String?,
    );

Map<String, dynamic> _$CandlelightConfigToJson(CandlelightConfig instance) =>
    <String, dynamic>{
      'centerColorArgb': instance.centerColorArgb,
      'peripheryColorArgb': instance.peripheryColorArgb,
      'noiseScale': instance.noiseScale,
      'noiseSpeed': instance.noiseSpeed,
      'baselineAlpha': instance.baselineAlpha,
      'featherRadiusFraction': instance.featherRadiusFraction,
      'rendererType': instance.$type,
    };

HeavenlyCloudsConfig _$HeavenlyCloudsConfigFromJson(
  Map<String, dynamic> json,
) => HeavenlyCloudsConfig(
  colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFFE8E8EE,
  noiseScale: (json['noiseScale'] as num?)?.toDouble() ?? 0.3,
  noiseSpeed: (json['noiseSpeed'] as num?)?.toDouble() ?? 0.08,
  driftDirectionDeg: (json['driftDirectionDeg'] as num?)?.toDouble() ?? 45.0,
  baselineAlpha: (json['baselineAlpha'] as num?)?.toDouble() ?? 0.80,
  $type: json['rendererType'] as String?,
);

Map<String, dynamic> _$HeavenlyCloudsConfigToJson(
  HeavenlyCloudsConfig instance,
) => <String, dynamic>{
  'colorArgb': instance.colorArgb,
  'noiseScale': instance.noiseScale,
  'noiseSpeed': instance.noiseSpeed,
  'driftDirectionDeg': instance.driftDirectionDeg,
  'baselineAlpha': instance.baselineAlpha,
  'rendererType': instance.$type,
};

ShaderConfig _$ShaderConfigFromJson(Map<String, dynamic> json) => ShaderConfig(
  shaderAssetPath: json['shaderAssetPath'] as String,
  $type: json['rendererType'] as String?,
);

Map<String, dynamic> _$ShaderConfigToJson(ShaderConfig instance) =>
    <String, dynamic>{
      'shaderAssetPath': instance.shaderAssetPath,
      'rendererType': instance.$type,
    };

UnknownConfig _$UnknownConfigFromJson(Map<String, dynamic> json) {
  $checkKeys(json, disallowNullValues: const ['raw']);
  return UnknownConfig(
    raw: _unknownRawFromJson(_readWholeMap(json, 'raw')),
    $type: json['rendererType'] as String?,
  );
}

Map<String, dynamic> _$UnknownConfigToJson(UnknownConfig instance) =>
    <String, dynamic>{
      'raw': _unknownRawToJson(instance.raw),
      'rendererType': instance.$type,
    };

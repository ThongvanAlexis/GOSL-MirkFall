// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirk_style_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AtmosphericConfig _$AtmosphericConfigFromJson(Map<String, dynamic> json) =>
    AtmosphericConfig(
      baseColorArgb: (json['baseColorArgb'] as num?)?.toInt() ?? 0xFF000000,
      noiseScale: (json['noiseScale'] as num?)?.toDouble() ?? 0.5,
      $type: json['rendererType'] as String?,
    );

Map<String, dynamic> _$AtmosphericConfigToJson(AtmosphericConfig instance) =>
    <String, dynamic>{
      'baseColorArgb': instance.baseColorArgb,
      'noiseScale': instance.noiseScale,
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirk_style.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MirkStyle _$MirkStyleFromJson(Map<String, dynamic> json) => _MirkStyle(
  id: mirkStyleIdFromJson(json['id'] as String),
  displayName: json['displayName'] as String,
  config: MirkStyleConfig.fromJson(json['config'] as Map<String, dynamic>),
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  createdAtOffsetMinutes: (json['createdAtOffsetMinutes'] as num).toInt(),
);

Map<String, dynamic> _$MirkStyleToJson(_MirkStyle instance) => <String, dynamic>{
  'id': mirkStyleIdToJson(instance.id),
  'displayName': instance.displayName,
  'config': instance.config,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'createdAtOffsetMinutes': instance.createdAtOffsetMinutes,
};

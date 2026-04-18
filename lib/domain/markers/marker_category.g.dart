// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marker_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MarkerCategory _$MarkerCategoryFromJson(Map<String, dynamic> json) => _MarkerCategory(
  id: categoryIdFromJson(json['id'] as String),
  displayName: json['displayName'] as String,
  iconName: json['iconName'] as String,
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  createdAtOffsetMinutes: (json['createdAtOffsetMinutes'] as num).toInt(),
);

Map<String, dynamic> _$MarkerCategoryToJson(_MarkerCategory instance) => <String, dynamic>{
  'id': categoryIdToJson(instance.id),
  'displayName': instance.displayName,
  'iconName': instance.iconName,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'createdAtOffsetMinutes': instance.createdAtOffsetMinutes,
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marker.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Marker _$MarkerFromJson(Map<String, dynamic> json) => _Marker(
  id: markerIdFromJson(json['id'] as String),
  sessionId: sessionIdFromJson(json['sessionId'] as String),
  categoryId: categoryIdFromJson(json['categoryId'] as String),
  lat: (json['lat'] as num).toDouble(),
  lon: (json['lon'] as num).toDouble(),
  title: json['title'] as String,
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  createdAtOffsetMinutes: (json['createdAtOffsetMinutes'] as num).toInt(),
  notes: json['notes'] as String?,
  photos: (json['photos'] as List<dynamic>?)?.map((e) => PhotoRef.fromJson(e as Map<String, dynamic>)).toList() ?? const <PhotoRef>[],
);

Map<String, dynamic> _$MarkerToJson(_Marker instance) => <String, dynamic>{
  'id': markerIdToJson(instance.id),
  'sessionId': sessionIdToJson(instance.sessionId),
  'categoryId': categoryIdToJson(instance.categoryId),
  'lat': instance.lat,
  'lon': instance.lon,
  'title': instance.title,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'createdAtOffsetMinutes': instance.createdAtOffsetMinutes,
  'notes': instance.notes,
  'photos': instance.photos,
};

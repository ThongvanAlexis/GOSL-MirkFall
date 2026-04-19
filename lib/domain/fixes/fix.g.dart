// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fix.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Fix _$FixFromJson(Map<String, dynamic> json) => _Fix(
  id: fixIdFromJson(json['id'] as String),
  sessionId: sessionIdFromJson(json['sessionId'] as String),
  recordedAtUtc: DateTime.parse(json['recordedAtUtc'] as String),
  recordedAtOffsetMinutes: (json['recordedAtOffsetMinutes'] as num).toInt(),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
  altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
  speedMps: (json['speedMps'] as num?)?.toDouble(),
  headingDegrees: (json['headingDegrees'] as num?)?.toDouble(),
);

Map<String, dynamic> _$FixToJson(_Fix instance) => <String, dynamic>{
  'id': fixIdToJson(instance.id),
  'sessionId': sessionIdToJson(instance.sessionId),
  'recordedAtUtc': instance.recordedAtUtc.toIso8601String(),
  'recordedAtOffsetMinutes': instance.recordedAtOffsetMinutes,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'accuracyMeters': instance.accuracyMeters,
  'altitudeMeters': instance.altitudeMeters,
  'speedMps': instance.speedMps,
  'headingDegrees': instance.headingDegrees,
};

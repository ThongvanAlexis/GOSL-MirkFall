// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Session _$SessionFromJson(Map<String, dynamic> json) => _Session(
  id: sessionIdFromJson(json['id'] as String),
  displayName: json['displayName'] as String,
  status: $enumDecode(_$SessionStatusEnumMap, json['status']),
  startedAtUtc: DateTime.parse(json['startedAtUtc'] as String),
  startedAtOffsetMinutes: (json['startedAtOffsetMinutes'] as num).toInt(),
  stoppedAtUtc: json['stoppedAtUtc'] == null
      ? null
      : DateTime.parse(json['stoppedAtUtc'] as String),
  stoppedAtOffsetMinutes: (json['stoppedAtOffsetMinutes'] as num?)?.toInt(),
  notes: json['notes'] as String?,
  mirkStyleId: _mirkStyleIdFromJsonNullable(json['mirkStyleId'] as String?),
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': sessionIdToJson(instance.id),
  'displayName': instance.displayName,
  'status': _$SessionStatusEnumMap[instance.status]!,
  'startedAtUtc': instance.startedAtUtc.toIso8601String(),
  'startedAtOffsetMinutes': instance.startedAtOffsetMinutes,
  'stoppedAtUtc': instance.stoppedAtUtc?.toIso8601String(),
  'stoppedAtOffsetMinutes': instance.stoppedAtOffsetMinutes,
  'notes': instance.notes,
  'mirkStyleId': _mirkStyleIdToJsonNullable(instance.mirkStyleId),
};

const _$SessionStatusEnumMap = {
  SessionStatus.active: 'active',
  SessionStatus.stopped: 'stopped',
};

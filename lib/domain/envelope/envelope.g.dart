// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Envelope _$EnvelopeFromJson(Map<String, dynamic> json) => _Envelope(
  schemaVersion: (json['schemaVersion'] as num).toInt(),
  type: json['type'] as String,
  payload: _payloadFromJson(json['payload'] as Map<String, dynamic>),
);

Map<String, dynamic> _$EnvelopeToJson(_Envelope instance) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'type': instance.type,
  'payload': _payloadToJson(instance.payload),
};

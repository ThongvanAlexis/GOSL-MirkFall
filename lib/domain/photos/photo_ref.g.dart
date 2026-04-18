// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PhotoRef _$PhotoRefFromJson(Map<String, dynamic> json) => _PhotoRef(
  id: photoRefIdFromJson(json['id'] as String),
  markerId: markerIdFromJson(json['markerId'] as String),
  relativeBasename: json['relativeBasename'] as String,
  widthPx: (json['widthPx'] as num).toInt(),
  heightPx: (json['heightPx'] as num).toInt(),
  fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  createdAtOffsetMinutes: (json['createdAtOffsetMinutes'] as num).toInt(),
);

Map<String, dynamic> _$PhotoRefToJson(_PhotoRef instance) => <String, dynamic>{
  'id': photoRefIdToJson(instance.id),
  'markerId': markerIdToJson(instance.markerId),
  'relativeBasename': instance.relativeBasename,
  'widthPx': instance.widthPx,
  'heightPx': instance.heightPx,
  'fileSizeBytes': instance.fileSizeBytes,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'createdAtOffsetMinutes': instance.createdAtOffsetMinutes,
};

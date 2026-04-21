// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InstalledManifest _$InstalledManifestFromJson(Map<String, dynamic> json) =>
    _InstalledManifest(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      catalogVersion: json['catalogVersion'] as String,
      installed: (json['installed'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, InstalledCountry.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$InstalledManifestToJson(_InstalledManifest instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'catalogVersion': instance.catalogVersion,
      'installed': instance.installed,
    };

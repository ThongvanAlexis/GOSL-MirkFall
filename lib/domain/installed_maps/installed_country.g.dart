// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_country.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InstalledCountry _$InstalledCountryFromJson(Map<String, dynamic> json) =>
    _InstalledCountry(
      alpha3: countryCodeFromJson(json['alpha3'] as String),
      installedAtUtc: DateTime.parse(json['installedAtUtc'] as String),
      fileSize: (json['fileSize'] as num).toInt(),
      pmtilesVersion: json['pmtilesVersion'] as String,
      sha256: json['sha256'] as String,
      filePath: json['filePath'] as String,
    );

Map<String, dynamic> _$InstalledCountryToJson(_InstalledCountry instance) =>
    <String, dynamic>{
      'alpha3': countryCodeToJson(instance.alpha3),
      'installedAtUtc': instance.installedAtUtc.toIso8601String(),
      'fileSize': instance.fileSize,
      'pmtilesVersion': instance.pmtilesVersion,
      'sha256': instance.sha256,
      'filePath': instance.filePath,
    };

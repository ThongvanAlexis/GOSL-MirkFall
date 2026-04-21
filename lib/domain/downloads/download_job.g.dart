// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DownloadJob _$DownloadJobFromJson(Map<String, dynamic> json) => _DownloadJob(
  alpha3: countryCodeFromJson(json['alpha3'] as String),
  entry: CountryEntry.fromJson(json['entry'] as Map<String, dynamic>),
  enqueuedAtUtc: DateTime.parse(json['enqueuedAtUtc'] as String),
  userPausedFlag: json['userPausedFlag'] as bool? ?? false,
);

Map<String, dynamic> _$DownloadJobToJson(_DownloadJob instance) =>
    <String, dynamic>{
      'alpha3': countryCodeToJson(instance.alpha3),
      'entry': instance.entry,
      'enqueuedAtUtc': instance.enqueuedAtUtc.toIso8601String(),
      'userPausedFlag': instance.userPausedFlag,
    };

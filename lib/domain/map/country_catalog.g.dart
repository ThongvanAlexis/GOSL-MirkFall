// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'country_catalog.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CountryCatalog _$CountryCatalogFromJson(Map<String, dynamic> json) =>
    _CountryCatalog(
      countries: (json['countries'] as List<dynamic>)
          .map((e) => CountryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CountryCatalogToJson(_CountryCatalog instance) =>
    <String, dynamic>{'countries': instance.countries};

_CountryEntry _$CountryEntryFromJson(Map<String, dynamic> json) =>
    _CountryEntry(
      alpha3: countryCodeFromJson(json['alpha3'] as String),
      name: json['name'] as String,
      parts: (json['parts'] as List<dynamic>)
          .map((e) => ChunkPart.fromJson(e as Map<String, dynamic>))
          .toList(),
      reassembled: ReassembledMeta.fromJson(
        json['reassembled'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$CountryEntryToJson(_CountryEntry instance) =>
    <String, dynamic>{
      'alpha3': countryCodeToJson(instance.alpha3),
      'name': instance.name,
      'parts': instance.parts,
      'reassembled': instance.reassembled,
    };

_ChunkPart _$ChunkPartFromJson(Map<String, dynamic> json) => _ChunkPart(
  sha256: json['sha256'] as String,
  size: (json['size'] as num).toInt(),
  url: json['url'] as String,
);

Map<String, dynamic> _$ChunkPartToJson(_ChunkPart instance) =>
    <String, dynamic>{
      'sha256': instance.sha256,
      'size': instance.size,
      'url': instance.url,
    };

_ReassembledMeta _$ReassembledMetaFromJson(Map<String, dynamic> json) =>
    _ReassembledMeta(
      sha256: json['sha256'] as String,
      size: (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$ReassembledMetaToJson(_ReassembledMeta instance) =>
    <String, dynamic>{'sha256': instance.sha256, 'size': instance.size};

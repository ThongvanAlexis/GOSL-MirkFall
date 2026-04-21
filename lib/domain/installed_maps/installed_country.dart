// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters (analyzer can't see it through the factory indirection).

import 'package:freezed_annotation/freezed_annotation.dart';

import '../map/country_code.dart';

part 'installed_country.freezed.dart';
part 'installed_country.g.dart';

/// One installed country entry in the `installed.json` manifest.
///
/// Every field is required and corresponds directly to an on-disk
/// property of the country PMTiles bundle:
/// - [alpha3]: validated country code (key in the manifest's `installed` map)
/// - [installedAtUtc]: timestamp at which the install step completed
/// - [fileSize]: byte length of the `.pmtiles` file (cross-check vs disk)
/// - [pmtilesVersion]: catalog tag at install time (e.g. `"v20260419"`);
///   drives update detection when a newer catalog ships
/// - [sha256]: 64-char hex digest of the reassembled file (for on-disk
///   integrity verification — drift catches bit rot + partial writes)
/// - [filePath]: relative path from `<app_support>` (e.g.
///   `"maps/countries/fra.pmtiles"`); kept relative so the manifest
///   survives the Android storage-migration API moving the sandbox.
@freezed
abstract class InstalledCountry with _$InstalledCountry {
  @Assert('fileSize > 0', 'InstalledCountry.fileSize must be positive')
  @Assert('sha256.length == 64', 'InstalledCountry.sha256 must be 64 hex chars')
  @Assert('pmtilesVersion.length > 0', 'InstalledCountry.pmtilesVersion must be non-empty')
  @Assert('filePath.length > 0', 'InstalledCountry.filePath must be non-empty')
  factory InstalledCountry({
    @JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) required CountryCode alpha3,
    required DateTime installedAtUtc,
    required int fileSize,
    required String pmtilesVersion,
    required String sha256,
    required String filePath,
  }) = _InstalledCountry;

  factory InstalledCountry.fromJson(Map<String, Object?> json) => _$InstalledCountryFromJson(json);
}

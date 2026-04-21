// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:freezed_annotation/freezed_annotation.dart';

import '../map/country_code.dart';
import 'installed_country.dart';

part 'installed_manifest.freezed.dart';
part 'installed_manifest.g.dart';

/// Root document of `<app_support>/maps/installed.json` — the manifest
/// of per-country PMTiles bundles currently resident on disk.
///
/// Fields:
/// - [schemaVersion]: always `1` in Phase 07. A bump in later phases
///   pairs with a migration step (see Plan 07-04 for the read path).
/// - [catalogVersion]: catalog tag the manifest was last reconciled
///   against. Drives the "catalog drifted; re-download?" flow.
/// - [installed]: per-alpha3 dictionary of [InstalledCountry] entries.
///   The outer key is `alpha3.value` (lower-case 3-letter string), which
///   allows vanilla `Map<String, InstalledCountry>` JSON round-tripping
///   through json_serializable's default map handler.
///
/// Helpers ([empty], [copyWithInsert], [copyWithRemove], [totalSizeBytes])
/// live in the [InstalledManifestHelpers] extension to keep the Freezed
/// factory signature minimal.
@freezed
abstract class InstalledManifest with _$InstalledManifest {
  @Assert('schemaVersion == 1', 'InstalledManifest.schemaVersion must be 1 in Phase 07')
  factory InstalledManifest({required int schemaVersion, required String catalogVersion, required Map<String, InstalledCountry> installed}) =
      _InstalledManifest;

  factory InstalledManifest.fromJson(Map<String, Object?> json) => _$InstalledManifestFromJson(json);

  /// Empty manifest — the initial state before any country is installed.
  /// `catalogVersion` is empty until the first successful install
  /// reconciles it against the bundled catalog.
  factory InstalledManifest.empty() => InstalledManifest(schemaVersion: 1, catalogVersion: '', installed: <String, InstalledCountry>{});
}

/// Pure functional helpers over [InstalledManifest].
///
/// Kept in an extension so the Freezed-generated `copyWith` stays clean.
/// Every helper returns a new [InstalledManifest] — never mutates
/// `installed` in place (CLAUDE.md §Mutation de collection).
extension InstalledManifestHelpers on InstalledManifest {
  /// Sum of all installed country file sizes. Used by the Plan 07-05
  /// storage-usage UI.
  int get totalSizeBytes => installed.values.fold<int>(0, (int acc, InstalledCountry c) => acc + c.fileSize);

  /// Returns a copy with [entry] inserted (or replaced if the alpha3 key
  /// already exists). Does NOT mutate the receiver.
  InstalledManifest copyWithInsert(InstalledCountry entry) {
    final Map<String, InstalledCountry> next = <String, InstalledCountry>{...installed, entry.alpha3.value: entry};
    return copyWith(installed: next);
  }

  /// Returns a copy with the entry for [alpha3] removed. No-op when the
  /// key is absent.
  InstalledManifest copyWithRemove(CountryCode alpha3) {
    if (!installed.containsKey(alpha3.value)) return this;
    final Map<String, InstalledCountry> next = <String, InstalledCountry>{...installed}..remove(alpha3.value);
    return copyWith(installed: next);
  }
}

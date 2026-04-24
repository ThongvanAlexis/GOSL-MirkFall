// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'installed_maps_controller.g.dart';

/// Derived per-country view consumed by the Plan 07-06 installed-maps
/// screen + AppBar badge.
///
/// - [installed]: alpha3 → [InstalledCountry] snapshot. Map, not list,
///   so callers look up by alpha3 in O(1).
/// - [updatesAvailableSet]: subset of alpha3 keys whose
///   `pmtilesVersion != currentCatalogVersion`. Drives the "update
///   available" badge.
/// - [totalDiskUsageBytes]: sum of `fileSize` across every installed
///   country, for the settings storage row.
class InstalledMapsState {
  const InstalledMapsState({required this.installed, required this.updatesAvailableSet, required this.totalDiskUsageBytes});

  const InstalledMapsState.empty() : installed = const <CountryCode, InstalledCountry>{}, updatesAvailableSet = const <CountryCode>{}, totalDiskUsageBytes = 0;

  final Map<CountryCode, InstalledCountry> installed;
  // Renamed from `updatesAvailable` to follow CLAUDE.md §Naming — `Set<T>`
  // fields carry a `Set` suffix (row #46).
  final Set<CountryCode> updatesAvailableSet;
  final int totalDiskUsageBytes;
}

/// Presentation-facing view over the installed-maps manifest + catalog.
///
/// Watches [installedManifestProvider] + [countryCatalogProvider] and
/// projects the triple of `(installed map, updatesAvailableSet,
/// totalDiskUsageBytes)`. Exposes a [deleteCountry] method that
/// delegates to the Plan 07-04 `CountryDeleteService` (which enforces
/// the `CountryCode.world` sentinel guard) + the repo's atomic write
/// triggers a manifest refresh via the broadcast stream.
///
/// The `updatesAvailableSet` set is a strict inequality check:
/// `installedCountry.pmtilesVersion != catalog.catalogVersion`. A
/// manifest entry with pmtilesVersion `"v20260419"` against a catalog
/// tagged `"v20260501"` flags the country as updatable; same tag means
/// no update needed. New countries in the catalog that aren't installed
/// are NOT in this set — they're handled by the Plan 07-06 "download"
/// flow instead.
@Riverpod(keepAlive: true)
class InstalledMapsController extends _$InstalledMapsController {
  static final Logger _log = Logger('application.controllers.installed_maps');

  @override
  InstalledMapsState build() {
    // Catalog + manifest both flow through the existing providers.
    // Row #13 (Should) — previously this controller opened a direct
    // `repo.updates.listen(...)` subscription next to the
    // `installedManifestProvider` StreamProvider, producing two
    // parallel listener paths over the same broadcast stream. Using
    // `ref.watch` on the provider is the idiomatic Riverpod way; the
    // StreamProvider already seeds from `repo.read()` on subscribe +
    // forwards `repo.updates`, and `keepAlive: true` on both this
    // controller and the StreamProvider guarantees a single subscriber.
    final AsyncValue<CountryCatalog> catalogSnap = ref.watch(countryCatalogProvider);
    final AsyncValue<InstalledManifest> manifestSnap = ref.watch(installedManifestProvider);

    final CountryCatalog? catalog = catalogSnap.value;
    final InstalledManifest manifest = manifestSnap.value ?? InstalledManifest.empty();

    return _derive(manifest: manifest, catalog: catalog);
  }

  /// Deletes a country via the Plan 07-04 [CountryDeleteService]. The
  /// service writes a new manifest; the StreamProvider's broadcast
  /// emission invalidates this controller's `build()` and the derived
  /// state refreshes automatically — no explicit refresh call required.
  ///
  /// Throws [CannotDeleteWorldBundleException] when [alpha3] is
  /// [CountryCode.world]. Callers surface this via a dialog.
  Future<void> deleteCountry(CountryCode alpha3) async {
    final svc = await ref.read(countryDeleteServiceProvider.future);
    await svc.deleteCountry(alpha3);
  }

  InstalledMapsState _derive({required InstalledManifest manifest, required CountryCatalog? catalog}) {
    final Map<CountryCode, InstalledCountry> installedByCode = <CountryCode, InstalledCountry>{};
    int totalBytes = 0;
    for (final InstalledCountry entry in manifest.installed.values) {
      installedByCode[entry.alpha3] = entry;
      totalBytes += entry.fileSize;
    }

    final Set<CountryCode> updatesSet = <CountryCode>{};
    if (catalog != null) {
      final String catalogVersion;
      try {
        catalogVersion = catalog.catalogVersion;
      } on FormatException catch (e) {
        _log.warning('catalog.catalogVersion extraction failed: $e — updatesAvailableSet will be empty');
        return InstalledMapsState(installed: installedByCode, updatesAvailableSet: const <CountryCode>{}, totalDiskUsageBytes: totalBytes);
      }
      for (final InstalledCountry entry in installedByCode.values) {
        if (entry.pmtilesVersion != catalogVersion) {
          updatesSet.add(entry.alpha3);
        }
      }
    }

    return InstalledMapsState(installed: installedByCode, updatesAvailableSet: updatesSet, totalDiskUsageBytes: totalBytes);
  }
}

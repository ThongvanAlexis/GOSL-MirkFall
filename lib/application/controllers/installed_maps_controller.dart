// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'installed_maps_controller.g.dart';

/// Derived per-country view consumed by the Plan 07-06 installed-maps
/// screen + AppBar badge.
///
/// - [installed]: alpha3 → [InstalledCountry] snapshot. Map, not list,
///   so callers look up by alpha3 in O(1).
/// - [updatesAvailable]: subset of alpha3 keys whose
///   `pmtilesVersion != currentCatalogVersion`. Drives the "update
///   available" badge.
/// - [totalDiskUsageBytes]: sum of `fileSize` across every installed
///   country, for the settings storage row.
class InstalledMapsState {
  const InstalledMapsState({required this.installed, required this.updatesAvailable, required this.totalDiskUsageBytes});

  const InstalledMapsState.empty()
    : installed = const <CountryCode, InstalledCountry>{},
      updatesAvailable = const <CountryCode>{},
      totalDiskUsageBytes = 0;

  final Map<CountryCode, InstalledCountry> installed;
  final Set<CountryCode> updatesAvailable;
  final int totalDiskUsageBytes;
}

/// Presentation-facing view over the installed-maps manifest + catalog.
///
/// Watches [installedManifestProvider] + [countryCatalogProvider] and
/// projects the triple of `(installed map, updatesAvailable set,
/// totalDiskUsageBytes)`. Exposes a [deleteCountry] method that
/// delegates to the Plan 07-04 `CountryDeleteService` (which enforces
/// the `CountryCode.world` sentinel guard) + the repo's atomic write
/// triggers a manifest refresh via the broadcast stream.
///
/// The `updatesAvailable` set is a strict inequality check:
/// `installedCountry.pmtilesVersion != catalog.catalogVersion`. A
/// manifest entry with pmtilesVersion `"v20260419"` against a catalog
/// tagged `"v20260501"` flags the country as updatable; same tag means
/// no update needed. New countries in the catalog that aren't installed
/// are NOT in this set — they're handled by the Plan 07-06 "download"
/// flow instead.
@Riverpod(keepAlive: true)
class InstalledMapsController extends _$InstalledMapsController {
  static final Logger _log = Logger('application.controllers.installed_maps');

  StreamSubscription<InstalledManifest>? _manifestSub;
  InstalledManifest _latestManifest = InstalledManifest.empty();

  @override
  InstalledMapsState build() {
    // Catalog is read via ref.watch so the derived state refreshes on
    // catalog load (first-frame AsyncLoading -> AsyncData transition).
    final catalogSnap = ref.watch(countryCatalogProvider);
    final CountryCatalog? catalog = catalogSnap.value;

    ref.onDispose(() async {
      await _manifestSub?.cancel();
      _manifestSub = null;
    });

    // Attach directly to the manifest repository's broadcast stream
    // rather than going through the StreamProvider layer — the
    // StreamProvider's value propagation to ref.watch has timing
    // edge cases we would rather not race with. Also seed the initial
    // _latestManifest from a synchronous read so the first build()
    // already reflects on-disk state.
    _attachRepoListenerIfNeeded();

    return _derive(manifest: _latestManifest, catalog: catalog);
  }

  void _attachRepoListenerIfNeeded() {
    if (_manifestSub != null) return;
    unawaited(() async {
      try {
        final InstalledManifestRepository repo = await ref.read(installedManifestRepositoryProvider.future);
        final InstalledManifest initial = await repo.read();
        _latestManifest = initial;
        // Rebuild with the freshly-read manifest.
        final catalogSnap = ref.read(countryCatalogProvider);
        state = _derive(manifest: _latestManifest, catalog: catalogSnap.value);
        _manifestSub = repo.updates.listen((m) {
          _latestManifest = m;
          final catalogSnap = ref.read(countryCatalogProvider);
          state = _derive(manifest: _latestManifest, catalog: catalogSnap.value);
        });
      } on Object catch (e, st) {
        _log.warning('failed to attach manifest listener', e, st);
      }
    }());
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

    final Set<CountryCode> updates = <CountryCode>{};
    if (catalog != null) {
      final String catalogVersion;
      try {
        catalogVersion = catalog.catalogVersion;
      } on FormatException catch (e) {
        _log.warning('catalog.catalogVersion extraction failed: $e — updatesAvailable will be empty');
        return InstalledMapsState(
          installed: installedByCode,
          updatesAvailable: const <CountryCode>{},
          totalDiskUsageBytes: totalBytes,
        );
      }
      for (final InstalledCountry entry in installedByCode.values) {
        if (entry.pmtilesVersion != catalogVersion) {
          updates.add(entry.alpha3);
        }
      }
    }

    return InstalledMapsState(
      installed: installedByCode,
      updatesAvailable: updates,
      totalDiskUsageBytes: totalBytes,
    );
  }
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:path/path.dart' as p;

/// Deletes an installed per-country PMTiles bundle + removes the
/// corresponding manifest entry.
///
/// The world basemap is a domain-reserved sentinel ([CountryCode.world]);
/// deleting it would leave the user with a completely blank map and no
/// recovery path short of reinstalling the app. The sentinel compare
/// happens against [CountryCode.world] — NEVER against the raw string
/// literal `'wld'`, per the reservation contract documented on
/// [CountryCode].
///
/// Order of operations:
/// 1. Read current manifest.
/// 2. If alpha3 missing from manifest → no-op (service is idempotent).
/// 3. Delete the `.pmtiles` file on disk (best-effort; filesystem errors
///    propagate as [FileSystemException]).
/// 4. Atomically rewrite the manifest without the entry.
///
/// Why file-first then manifest: a crash between step 3 and step 4
/// leaves an orphan manifest entry pointing at a missing file — the
/// next-launch bootstrap (`FirstLaunchBootstrap._purgeOrphanManifestEntries`)
/// scans manifest entries whose backing file is absent and removes
/// them. The inverse ordering (manifest first) would leave a stale
/// `.pmtiles` on disk with no reference — wasted storage with no
/// automatic cleanup path.
class CountryDeleteService {
  CountryDeleteService({required InstalledManifestRepository manifestRepository, required String appSupportDir, Logger? logger})
    : _manifestRepository = manifestRepository,
      _appSupportDir = appSupportDir,
      _log = logger ?? Logger('infrastructure.installed_maps.country_delete_service');

  final InstalledManifestRepository _manifestRepository;
  final String _appSupportDir;
  final Logger _log;

  /// Deletes the country identified by [alpha3].
  ///
  /// Throws:
  /// - [CannotDeleteWorldBundleException] when [alpha3] equals
  ///   [CountryCode.world] — including the case where it was produced
  ///   via `CountryCode.parse('wld')` (equal to the sentinel by design).
  /// - [FileSystemException] when the `.pmtiles` file delete fails for
  ///   an unexpected reason.
  Future<void> deleteCountry(CountryCode alpha3) async {
    if (alpha3 == CountryCode.world) {
      _log.warning('deleteCountry: refused — cannot delete the bundled world basemap');
      throw const CannotDeleteWorldBundleException(reason: 'world basemap is non-deletable per MAP-07 floor');
    }

    final InstalledManifest current = await _manifestRepository.read();
    if (!current.installed.containsKey(alpha3.value)) {
      _log.info('deleteCountry: ${alpha3.value} not in manifest — no-op');
      return;
    }

    final String relative = current.installed[alpha3.value]!.filePath;
    final File file = File(p.join(_appSupportDir, relative));
    if (file.existsSync()) {
      await file.delete();
      _log.info('deleteCountry: deleted ${file.path}');
    }

    await _manifestRepository.write(current.copyWithRemove(alpha3));
  }
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/downloads/sha256_verifier.dart';
import 'package:mirkfall/infrastructure/map/first_launch_world_copier.dart';
import 'package:mirkfall/infrastructure/platform/ios_backup_excluder.dart';
import 'package:path/path.dart' as p;

/// Orchestrates cold-start Phase 07 bootstrap.
///
/// Call once from the application bootstrap (Plan 07-05 ties it to a
/// Riverpod `@Riverpod(keepAlive: true)` provider that is eagerly
/// invalidated on app open).
///
/// Responsibilities:
/// 1. Delegate the world-bundle copy to [FirstLaunchWorldCopier] — same
///    idempotence + auto-heal semantics as Plan 07-03.
/// 2. Scan `<app_support>/[kStagingDir]` (aka `maps/staging/`) for
///    per-alpha3 subdirectories. Each one corresponds to a previous
///    download session that was interrupted. Log each orphan at INFO;
///    do NOT delete — the user may want to resume, and Plan 07-05's
///    `DownloadQueueController` is responsible for the prompt +
///    on-confirm cleanup.
/// 3. On iOS only, invoke [IosBackupExcluder.excludePath] on the whole
///    `<app_support>/maps` tree. Closes Open Question #3: per-country
///    PMTiles bundles can be hundreds of MB, and iCloud backup of
///    re-downloadable data wastes quota + breaks the mental model. The
///    attribute is idempotent; repeat invocations no-op on already-
///    excluded paths.
class FirstLaunchBootstrap {
  FirstLaunchBootstrap({
    required FirstLaunchWorldCopier worldCopier,
    required String appSupportDir,
    required InstalledManifestRepository manifestRepository,
    CountryCatalog? catalog,
    IosBackupExcluder? iosBackupExcluder,
    Sha256Verifier? sha256Verifier,
    TargetPlatform? platformOverride,
    Logger? logger,
  }) : _worldCopier = worldCopier,
       _appSupportDir = appSupportDir,
       _manifestRepository = manifestRepository,
       _catalog = catalog,
       _iosBackupExcluder = iosBackupExcluder ?? IosBackupExcluder(),
       _sha256Verifier = sha256Verifier ?? const Sha256Verifier(),
       _platformOverride = platformOverride,
       _log = logger ?? Logger('infrastructure.installed_maps.first_launch_bootstrap');

  final FirstLaunchWorldCopier _worldCopier;
  final String _appSupportDir;
  final InstalledManifestRepository _manifestRepository;
  final CountryCatalog? _catalog;
  final IosBackupExcluder _iosBackupExcluder;
  final Sha256Verifier _sha256Verifier;
  final TargetPlatform? _platformOverride;
  final Logger _log;

  /// Absolute path of the staging root scanned for orphans.
  String get stagingDirFilename => p.join(_appSupportDir, kStagingDir);

  /// Absolute path of the maps root that gets backup-excluded on iOS.
  String get mapsRootFilename => p.join(_appSupportDir, 'maps');

  /// List of alpha3 directory basenames flagged as orphan staging
  /// directories on the most recent [run]. Populated by [run]; useful
  /// for Plan 07-05's resume-prompt UI to display "we found pending
  /// downloads for FRA + DEU, continue or abandon?".
  List<String> orphanStagingAlpha3s = <String>[];

  /// List of alpha3 keys healed during the most recent [run] — i.e.
  /// `.pmtiles` files that existed in the `countries/` directory but
  /// were missing from `installed.json`. The bootstrap re-computed the
  /// on-disk sha256 and reinserted the manifest entry (Plan 07-04
  /// atomic_cleanup scenario — the heal path chosen over destructive
  /// pmtiles deletion).
  List<String> healedAlpha3s = <String>[];

  /// Runs the full bootstrap sequence. Idempotent; safe to call on
  /// every app launch.
  Future<void> run() async {
    await _worldCopier.ensureInstalled();

    InstalledManifest manifest = await _manifestRepository.read();

    // Heal step: if a `.pmtiles` file exists under countries/ but has no
    // manifest entry, recompute its sha256 and reinsert the entry. The
    // catalog is used to fetch the expected hash + per-chunk metadata
    // when available; otherwise we keep the on-disk hash verbatim (the
    // file is trusted as the source of truth at heal time).
    manifest = await _healOrphanCountryFiles(manifest);

    orphanStagingAlpha3s = await _scanStagingOrphans(manifest);

    final TargetPlatform platform = _platformOverride ?? defaultTargetPlatform;
    if (platform == TargetPlatform.iOS) {
      await _iosBackupExcluder.excludePath(mapsRootFilename);
    }
  }

  /// Scans `<app_support>/[kCountriesDir]/` for `.pmtiles` files whose
  /// alpha3 key is absent from [manifest.installed]. For each one,
  /// recompute the sha256 + (if the catalog is available) cross-check
  /// against the catalog's `reassembled.sha256`. Matching files are
  /// re-inserted into the manifest; mismatches are left alone + logged.
  ///
  /// The heal path is the recovery mechanism for a crash between step
  /// 5 (atomic rename) and step 6 (manifest write) of the Plan 07-04
  /// download protocol.
  Future<InstalledManifest> _healOrphanCountryFiles(InstalledManifest manifest) async {
    final Directory countriesDir = Directory(p.join(_appSupportDir, kCountriesDir));
    if (!countriesDir.existsSync()) return manifest;

    InstalledManifest current = manifest;
    healedAlpha3s = <String>[];
    await for (final FileSystemEntity entity in countriesDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final String basename = p.basename(entity.path);
      if (!basename.endsWith('.pmtiles')) continue;
      final String alpha3Raw = basename.substring(0, basename.length - '.pmtiles'.length);
      if (alpha3Raw.length != 3) continue;
      if (current.installed.containsKey(alpha3Raw)) continue;

      final CountryCode alpha3;
      try {
        alpha3 = CountryCode.parse(alpha3Raw);
      } on FormatException catch (e) {
        _log.warning('heal: ${entity.path} has a non-alpha3 name — skipping: $e');
        continue;
      }

      final String computedSha;
      try {
        computedSha = await _sha256Verifier.ofFile(entity);
      } on Exception catch (e) {
        _log.warning('heal: could not sha256 ${entity.path}: $e — leaving file alone');
        continue;
      }

      String expectedSha = computedSha;
      String catalogVersion = '';
      CountryEntry? catalogEntry;
      if (_catalog != null) {
        for (final CountryEntry c in _catalog.countries) {
          if (c.alpha3 == alpha3) {
            catalogEntry = c;
            break;
          }
        }
        if (catalogEntry != null) {
          expectedSha = catalogEntry.reassembled.sha256;
          try {
            catalogVersion = _catalog.catalogVersion;
          } on FormatException {
            catalogVersion = '';
          }
        }
      }

      if (catalogEntry != null && computedSha != expectedSha) {
        _log.warning('heal: ${entity.path} sha256 mismatch (computed=$computedSha, catalog=$expectedSha) — leaving file alone for operator review');
        continue;
      }

      final int fileSize = await entity.length();
      final InstalledCountry installed = InstalledCountry(
        alpha3: alpha3,
        installedAtUtc: DateTime.now().toUtc(),
        fileSize: fileSize,
        pmtilesVersion: catalogVersion.isEmpty ? 'healed-${DateTime.now().toUtc().toIso8601String().substring(0, 10)}' : catalogVersion,
        sha256: computedSha,
        filePath: p.join(kCountriesDir, basename),
      );
      current = current.copyWithInsert(installed);
      healedAlpha3s.add(alpha3Raw);
      _log.info('heal: re-inserted manifest entry for alpha3=$alpha3Raw (sha256=$computedSha)');
    }

    if (healedAlpha3s.isNotEmpty) {
      await _manifestRepository.write(current);
    }
    return current;
  }


  Future<List<String>> _scanStagingOrphans(InstalledManifest manifest) async {
    final Directory staging = Directory(stagingDirFilename);
    if (!staging.existsSync()) return <String>[];

    final List<String> orphans = <String>[];
    await for (final FileSystemEntity entity in staging.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final String alpha3 = p.basename(entity.path);
      // A staging dir is only an orphan if there is no corresponding
      // entry in the manifest. Presence in the manifest means a prior
      // commit succeeded and cleanup is a no-op we can schedule.
      if (!manifest.installed.containsKey(alpha3)) {
        _log.info('orphan staging dir found for alpha3=$alpha3 at ${entity.path}; resume/abandon decision deferred to Plan 07-05 controller');
        orphans.add(alpha3);
      } else {
        _log.info('staging dir for alpha3=$alpha3 matches installed manifest entry; cleanup deferred to Plan 07-05 controller');
      }
    }
    return orphans;
  }
}

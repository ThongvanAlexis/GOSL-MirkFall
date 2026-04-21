// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
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
    IosBackupExcluder? iosBackupExcluder,
    TargetPlatform? platformOverride,
    Logger? logger,
  }) : _worldCopier = worldCopier,
       _appSupportDir = appSupportDir,
       _manifestRepository = manifestRepository,
       _iosBackupExcluder = iosBackupExcluder ?? IosBackupExcluder(),
       _platformOverride = platformOverride,
       _log = logger ?? Logger('infrastructure.installed_maps.first_launch_bootstrap');

  final FirstLaunchWorldCopier _worldCopier;
  final String _appSupportDir;
  final InstalledManifestRepository _manifestRepository;
  final IosBackupExcluder _iosBackupExcluder;
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

  /// Runs the full bootstrap sequence. Idempotent; safe to call on
  /// every app launch.
  Future<void> run() async {
    await _worldCopier.ensureInstalled();

    final InstalledManifest manifest = await _manifestRepository.read();
    orphanStagingAlpha3s = await _scanStagingOrphans(manifest);

    final TargetPlatform platform = _platformOverride ?? defaultTargetPlatform;
    if (platform == TargetPlatform.iOS) {
      await _iosBackupExcluder.excludePath(mapsRootFilename);
    }
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

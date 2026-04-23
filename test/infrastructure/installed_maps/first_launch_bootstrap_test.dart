// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/downloads/download_queue_store.dart';
import 'package:mirkfall/infrastructure/installed_maps/first_launch_bootstrap.dart';
import 'package:mirkfall/infrastructure/map/first_launch_world_copier.dart';
import 'package:mirkfall/infrastructure/platform/ios_backup_excluder.dart';
import 'package:path/path.dart' as p;

import '../../fakes/fake_installed_manifest_repository.dart';

/// Minimal test double for [IosBackupExcluder]. Records every
/// [excludePath] call so the bootstrap platform-branching can be
/// asserted without touching the real platform channel.
class _RecordingIosBackupExcluder extends Fake implements IosBackupExcluder {
  final List<String> calls = <String>[];
  @override
  Future<void> excludePath(String absolutePath) async {
    calls.add(absolutePath);
  }
}

InstalledCountry _makeCountry(String alpha3Raw) {
  return InstalledCountry(
    alpha3: CountryCode.parse(alpha3Raw),
    installedAtUtc: DateTime.utc(2026, 4, 21, 12),
    fileSize: 1024,
    pmtilesVersion: 'v20260419',
    sha256: '0' * 64,
    filePath: 'maps/countries/$alpha3Raw.pmtiles',
  );
}

DownloadJob _makeJob(String alpha3Raw) {
  final CountryCode alpha3 = CountryCode.parse(alpha3Raw);
  final CountryEntry entry = CountryEntry(
    alpha3: alpha3,
    name: alpha3Raw.toUpperCase(),
    parts: <ChunkPart>[ChunkPart(sha256: 'a' * 64, size: 1024, url: 'https://example.test/releases/download/v20260419/$alpha3Raw.part01')],
    reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1024),
  );
  return DownloadJob(alpha3: alpha3, entry: entry, enqueuedAtUtc: DateTime.utc(2026, 4, 21));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Uint8List syntheticWorldBytes;
  late String syntheticWorldSha;
  late ByteData syntheticWorldByteData;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_bootstrap_');
    syntheticWorldBytes = Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);
    syntheticWorldSha = sha256.convert(syntheticWorldBytes).toString();
    syntheticWorldByteData = ByteData.sublistView(syntheticWorldBytes);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  FirstLaunchWorldCopier makeCopier() {
    return FirstLaunchWorldCopierTestSeam.withAssetLoader(
      appSupportDir: tempDir.path,
      expectedSha256: syntheticWorldSha,
      loader: (_) async => syntheticWorldByteData,
    );
  }

  DownloadQueueStore makeEmptyQueueStore() => DownloadQueueStore(appSupportDir: tempDir.path);

  Future<DownloadQueueStore> makeQueueStoreWith(List<DownloadJob> jobs) async {
    final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
    await store.save(jobs);
    return store;
  }

  group('FirstLaunchBootstrap — world copy delegation', () {
    test('copier is invoked on run(); world bundle lands on disk', () async {
      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );

      await bootstrap.run();

      final File world = File(p.join(tempDir.path, kWorldPmtilesInternalPath));
      expect(world.existsSync(), isTrue);
      expect(await world.readAsBytes(), syntheticWorldBytes);
    });
  });

  group('FirstLaunchBootstrap — orphan staging scan', () {
    test('no staging dir → empty orphan list', () async {
      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(bootstrap.orphanStagingAlpha3s, isEmpty);
    });

    test('staging dir for an installed alpha3 (post-commit leftover) is DELETED', () async {
      final Directory staging = Directory(p.join(tempDir.path, kStagingDir));
      await staging.create(recursive: true);
      final Directory fraStaging = Directory(p.join(staging.path, 'fra'));
      await fraStaging.create();
      await File(p.join(fraStaging.path, 'part00')).writeAsString('leftover');

      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository(initial: InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(fraStaging.existsSync(), isFalse, reason: 'post-commit leftover should be deleted');
      expect(bootstrap.orphanStagingAlpha3s, isEmpty);
    });

    test('staging dir matching a queued job is PRESERVED + reported', () async {
      final Directory staging = Directory(p.join(tempDir.path, kStagingDir));
      await staging.create(recursive: true);
      final Directory fraStaging = Directory(p.join(staging.path, 'fra'));
      await fraStaging.create();
      await File(p.join(fraStaging.path, 'part00')).writeAsString('in-flight bytes');

      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: await makeQueueStoreWith(<DownloadJob>[_makeJob('fra')]),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(fraStaging.existsSync(), isTrue, reason: 'in-flight staging must survive bootstrap');
      expect(File(p.join(fraStaging.path, 'part00')).existsSync(), isTrue, reason: 'rehydrate() reuses the bytes');
      expect(bootstrap.orphanStagingAlpha3s, <String>['fra']);
    });

    test('staging dir with no manifest + no queue entry (abandoned) is DELETED', () async {
      final Directory staging = Directory(p.join(tempDir.path, kStagingDir));
      await staging.create(recursive: true);
      final Directory deuStaging = Directory(p.join(staging.path, 'deu'));
      await deuStaging.create();
      await File(p.join(deuStaging.path, 'part00')).writeAsString('abandoned bytes');

      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(deuStaging.existsSync(), isFalse, reason: 'abandoned staging should be deleted');
      expect(bootstrap.orphanStagingAlpha3s, isEmpty);
    });

    test('mixed — in-queue keep / everything else delete', () async {
      final Directory staging = Directory(p.join(tempDir.path, kStagingDir));
      await staging.create(recursive: true);
      final Directory fra = Directory(p.join(staging.path, 'fra'))..createSync(); // in manifest (post-commit leftover)
      final Directory deu = Directory(p.join(staging.path, 'deu'))..createSync(); // in queue (resumable)
      final Directory esp = Directory(p.join(staging.path, 'esp'))..createSync(); // abandoned

      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository(initial: InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: await makeQueueStoreWith(<DownloadJob>[_makeJob('deu')]),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(fra.existsSync(), isFalse);
      expect(deu.existsSync(), isTrue);
      expect(esp.existsSync(), isFalse);
      expect(bootstrap.orphanStagingAlpha3s, <String>['deu']);
    });
  });

  group('FirstLaunchBootstrap — orphan manifest purge (row #8 regression)', () {
    test('manifest entry with missing backing file is REMOVED on next launch', () async {
      // Regression guard for row #8 (Should) : before this fix, a crash
      // between CountryDeleteService's file-delete + manifest-rewrite
      // steps left a stale manifest entry pointing at nothing, and the
      // bootstrap's heal path never touched it (heal walks the
      // directory, not the manifest). The symmetric purge path now
      // removes manifest entries whose backing file is absent.
      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository(
        initial: InstalledManifest.empty().copyWithInsert(_makeCountry('fra')).copyWithInsert(_makeCountry('deu')),
      );
      addTearDown(manifest.close);

      // Seed deu.pmtiles on disk; leave fra.pmtiles missing (the crash
      // scenario: deleteCountry deleted the file but never rewrote the
      // manifest).
      final Directory countries = Directory(p.join(tempDir.path, kCountriesDir));
      await countries.create(recursive: true);
      await File(p.join(countries.path, 'deu.pmtiles')).writeAsBytes(<int>[0xDE, 0xAD]);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      final InstalledManifest after = await manifest.read();
      expect(after.installed.containsKey('fra'), isFalse, reason: 'orphan manifest entry for missing file must be purged');
      expect(after.installed.containsKey('deu'), isTrue, reason: 'entry with backing file must survive');
      expect(bootstrap.purgedOrphanManifestAlpha3s, <String>['fra']);
    });

    test('world sentinel entry is NEVER purged even if scan logic misfires', () async {
      // Defensive: the world entry is restored by FirstLaunchWorldCopier
      // before the purge runs, so this should never trigger. Test
      // encodes the contract: purge must skip CountryCode.world.
      final InstalledCountry worldEntry = InstalledCountry(
        alpha3: CountryCode.world,
        installedAtUtc: DateTime.utc(2026, 4, 21),
        fileSize: 8,
        pmtilesVersion: 'v20260419',
        sha256: syntheticWorldSha,
        // Deliberately an unresolvable path — this is the stress test.
        filePath: 'maps/countries/wld.pmtiles',
      );
      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository(initial: InstalledManifest.empty().copyWithInsert(worldEntry));
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(bootstrap.purgedOrphanManifestAlpha3s, isEmpty, reason: 'world sentinel must be skipped by purge');
    });

    test('no orphans → purge is a no-op + empty tracker list', () async {
      final InstalledCountry fra = _makeCountry('fra');
      final Directory countries = Directory(p.join(tempDir.path, kCountriesDir));
      await countries.create(recursive: true);
      await File(p.join(countries.path, 'fra.pmtiles')).writeAsBytes(<int>[0x11, 0x22]);

      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository(initial: InstalledManifest.empty().copyWithInsert(fra));
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(bootstrap.purgedOrphanManifestAlpha3s, isEmpty);
      final InstalledManifest after = await manifest.read();
      expect(after.installed.containsKey('fra'), isTrue);
    });
  });

  group('FirstLaunchBootstrap — iOS backup-exclude branch', () {
    test('iOS platform triggers excludePath on the maps root', () async {
      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);
      final _RecordingIosBackupExcluder excluder = _RecordingIosBackupExcluder();

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: excluder,
        platformOverride: TargetPlatform.iOS,
      );
      await bootstrap.run();

      expect(excluder.calls, <String>[p.join(tempDir.path, 'maps')]);
    });

    test('Android platform does NOT trigger excludePath', () async {
      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);
      final _RecordingIosBackupExcluder excluder = _RecordingIosBackupExcluder();

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: makeEmptyQueueStore(),
        iosBackupExcluder: excluder,
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(excluder.calls, isEmpty);
    });
  });
}

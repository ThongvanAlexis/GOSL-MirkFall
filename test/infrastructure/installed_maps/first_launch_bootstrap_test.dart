// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
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

  group('FirstLaunchBootstrap — world copy delegation', () {
    test('copier is invoked on run(); world bundle lands on disk', () async {
      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
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
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(bootstrap.orphanStagingAlpha3s, isEmpty);
    });

    test('staging dir with alpha3 subdirs not in manifest → each alpha3 reported', () async {
      final Directory staging = Directory(p.join(tempDir.path, kStagingDir));
      await staging.create(recursive: true);
      await Directory(p.join(staging.path, 'fra')).create();
      await Directory(p.join(staging.path, 'deu')).create();

      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(bootstrap.orphanStagingAlpha3s.toSet(), <String>{'fra', 'deu'});
    });

    test('staging dir matching an installed entry is NOT flagged as orphan', () async {
      final Directory staging = Directory(p.join(tempDir.path, kStagingDir));
      await staging.create(recursive: true);
      await Directory(p.join(staging.path, 'fra')).create();
      await Directory(p.join(staging.path, 'deu')).create();

      final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository(initial: InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));
      addTearDown(manifest.close);

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: makeCopier(),
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        iosBackupExcluder: _RecordingIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(bootstrap.orphanStagingAlpha3s, <String>['deu']);
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
        iosBackupExcluder: excluder,
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(excluder.calls, isEmpty);
    });
  });
}

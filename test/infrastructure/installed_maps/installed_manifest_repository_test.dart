// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/infrastructure/installed_maps/installed_manifest_repository.dart';
import 'package:path/path.dart' as p;

InstalledCountry _makeCountry(String alpha3Raw, {int size = 1024, String? sha}) {
  final String resolvedSha = sha ?? ('0' * 64);
  return InstalledCountry(
    alpha3: CountryCode.parse(alpha3Raw),
    installedAtUtc: DateTime.utc(2026, 4, 21, 12),
    fileSize: size,
    pmtilesVersion: 'v20260419',
    sha256: resolvedSha,
    filePath: 'maps/countries/$alpha3Raw.pmtiles',
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_manifest_repo_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('JsonFileInstalledManifestRepository — read path', () {
    test('missing file returns InstalledManifest.empty', () async {
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      final InstalledManifest loaded = await repo.read();
      expect(loaded.installed, isEmpty);
      expect(loaded.schemaVersion, 1);
      expect(loaded.catalogVersion, '');
    });

    test('empty file returns InstalledManifest.empty', () async {
      final File f = File(p.join(tempDir.path, kInstalledManifestPath));
      await f.parent.create(recursive: true);
      await f.writeAsString('');

      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      final InstalledManifest loaded = await repo.read();
      expect(loaded.installed, isEmpty);
    });

    test('corrupted JSON throws SchemaValidationException', () async {
      final File f = File(p.join(tempDir.path, kInstalledManifestPath));
      await f.parent.create(recursive: true);
      await f.writeAsString('{not-json[[');

      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      await expectLater(repo.read(), throwsA(isA<SchemaValidationException>()));
    });

    test('JSON list at top level throws SchemaValidationException', () async {
      final File f = File(p.join(tempDir.path, kInstalledManifestPath));
      await f.parent.create(recursive: true);
      await f.writeAsString('[1, 2, 3]');

      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      await expectLater(repo.read(), throwsA(isA<SchemaValidationException>()));
    });
  });

  group('JsonFileInstalledManifestRepository — write + roundtrip', () {
    test('write + read roundtrips a single country', () async {
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      final InstalledManifest seed = InstalledManifest.empty().copyWithInsert(_makeCountry('fra', size: 123_456_789));
      await repo.write(seed);

      final InstalledManifest loaded = await repo.read();
      expect(loaded.installed.keys, <String>['fra']);
      expect(loaded.installed['fra']!.fileSize, 123_456_789);
      expect(loaded.installed['fra']!.filePath, 'maps/countries/fra.pmtiles');
    });

    test('write + read roundtrips multiple countries in insertion order', () async {
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      final InstalledManifest seed = InstalledManifest.empty()
          .copyWithInsert(_makeCountry('fra'))
          .copyWithInsert(_makeCountry('deu'))
          .copyWithInsert(_makeCountry('esp'));
      await repo.write(seed);

      final InstalledManifest loaded = await repo.read();
      expect(loaded.installed.keys.toList(), <String>['fra', 'deu', 'esp']);
    });

    test('write replaces a previous write atomically (no stale bytes)', () async {
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      await repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('fra', size: 100)));
      await repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('deu', size: 200)));

      final InstalledManifest loaded = await repo.read();
      expect(loaded.installed.keys, <String>['deu']);
      expect(loaded.installed['deu']!.fileSize, 200);
    });
  });

  group('JsonFileInstalledManifestRepository — atomic-write contract', () {
    test('stale .tmp file is ignored by subsequent reads', () async {
      // Simulate a previous crash that left a .tmp file AND a valid
      // canonical file. The repository read path must ignore the .tmp
      // entirely and return the canonical state.
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      await repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));
      // Now plant a garbage .tmp alongside the canonical file.
      final File tmp = File('${repo.filename}.tmp');
      await tmp.writeAsString('{corrupted tempfile leftover from previous crash[[');

      final InstalledManifest loaded = await repo.read();
      expect(loaded.installed.keys, <String>['fra']);
      expect(tmp.existsSync(), isTrue, reason: 'stale .tmp is not cleaned up until the next successful write');
    });

    test('successive write cleans up the .tmp (rename swaps it away)', () async {
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      await repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));

      final File tmp = File('${repo.filename}.tmp');
      expect(tmp.existsSync(), isFalse, reason: 'after a successful write the .tmp has been renamed to canonical');
    });
  });

  group('JsonFileInstalledManifestRepository — updates stream', () {
    test('emits on the broadcast stream after every write', () async {
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      final List<int> sizes = <int>[];
      final StreamSubscription<InstalledManifest> sub = repo.updates.listen((InstalledManifest m) {
        sizes.add(m.installed.length);
      });
      addTearDown(sub.cancel);

      await repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));
      await repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('fra')).copyWithInsert(_makeCountry('deu')));
      // Let broadcast stream microtasks drain.
      await Future<void>.delayed(Duration.zero);

      expect(sizes, <int>[1, 2]);
    });

    test('serialises concurrent writes — stream events match last-written ordering', () async {
      final JsonFileInstalledManifestRepository repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(repo.close);

      final List<String> emitted = <String>[];
      final StreamSubscription<InstalledManifest> sub = repo.updates.listen((InstalledManifest m) {
        emitted.add(m.installed.keys.join(','));
      });
      addTearDown(sub.cancel);

      // Fire two writes without awaiting in between; the repo's
      // internal mutex must serialise them so the emitted order
      // matches the call order.
      final Future<void> a = repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));
      final Future<void> b = repo.write(InstalledManifest.empty().copyWithInsert(_makeCountry('deu')));
      await Future.wait(<Future<void>>[a, b]);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, <String>['fra', 'deu']);
      // Final on-disk state matches the last write.
      final InstalledManifest finalState = await repo.read();
      expect(finalState.installed.keys, <String>['deu']);
    });
  });
}

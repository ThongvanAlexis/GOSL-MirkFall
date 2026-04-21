// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/infrastructure/map/first_launch_world_copier.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  // Synthetic 8-byte "world" payload + its sha256 — fixture is tiny so
  // the test does not need to pull in the real 856 KB asset.
  final Uint8List syntheticBytes = Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);
  final String syntheticSha256 = sha256.convert(syntheticBytes).toString();
  final ByteData syntheticByteData = ByteData.sublistView(syntheticBytes);

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_copier_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FirstLaunchWorldCopier — first run', () {
    test('creates the target file with matching sha256', () async {
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: syntheticSha256,
        loader: (_) async => syntheticByteData,
      );

      await copier.ensureInstalled();
      final File target = File(p.join(tempDir.path, kWorldPmtilesInternalPath));
      expect(await target.exists(), isTrue);
      expect(await target.readAsBytes(), syntheticBytes);
    });

    test('creates the maps/ parent directory if missing', () async {
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: syntheticSha256,
        loader: (_) async => syntheticByteData,
      );

      // tempDir starts flat — maps/ does not exist yet.
      final Directory maps = Directory(p.join(tempDir.path, 'maps'));
      expect(await maps.exists(), isFalse);
      await copier.ensureInstalled();
      expect(await maps.exists(), isTrue);
    });
  });

  group('FirstLaunchWorldCopier — idempotence', () {
    test('second call is a no-op — loader not invoked', () async {
      int loaderCallCount = 0;
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: syntheticSha256,
        loader: (_) async {
          loaderCallCount++;
          return syntheticByteData;
        },
      );

      await copier.ensureInstalled();
      expect(loaderCallCount, 1);

      await copier.ensureInstalled();
      expect(loaderCallCount, 1, reason: 'healthy file on disk → asset loader must NOT be invoked on subsequent runs');
    });
  });

  group('FirstLaunchWorldCopier — auto-heal', () {
    test('seeded corrupted file triggers re-copy', () async {
      // Seed a corrupted file at the target path.
      final File target = File(p.join(tempDir.path, kWorldPmtilesInternalPath));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(<int>[0xFF, 0xFF]);

      int loaderCallCount = 0;
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: syntheticSha256,
        loader: (_) async {
          loaderCallCount++;
          return syntheticByteData;
        },
      );
      await copier.ensureInstalled();

      expect(loaderCallCount, 1, reason: 'corrupted file must trigger a re-copy');
      expect(await target.readAsBytes(), syntheticBytes);
    });
  });

  group('FirstLaunchWorldCopier — error paths', () {
    test('throws MapAssetMissingException on asset load failure', () async {
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: syntheticSha256,
        loader: (_) async => throw Exception('asset missing'),
      );

      await expectLater(copier.ensureInstalled(), throwsA(isA<MapAssetMissingException>()));
    });

    test('throws on empty asset byte stream', () async {
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: syntheticSha256,
        loader: (_) async => ByteData(0),
      );

      await expectLater(copier.ensureInstalled(), throwsA(isA<MapAssetMissingException>()));
    });

    test('throws on post-write sha256 mismatch (expected constant diverges from asset)', () async {
      // Pretend expectedSha256 is for a different payload — post-write
      // hash of `syntheticBytes` will not match, triggering the
      // catastrophic guard.
      // `'b' * 64` is not a const expression in Dart 3 — compute at runtime.
      final String wrongSha = 'b' * 64;
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: wrongSha,
        loader: (_) async => syntheticByteData,
      );

      await expectLater(copier.ensureInstalled(), throwsA(isA<MapAssetMissingException>()));

      // Target file must be cleaned up on the failure path.
      final File target = File(p.join(tempDir.path, kWorldPmtilesInternalPath));
      expect(await target.exists(), isFalse);
    });
  });
}

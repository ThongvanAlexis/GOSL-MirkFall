// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// First-launch world-bundle copy verification (MAP-07).
//
// Drives the `FirstLaunchWorldCopier` + `FirstLaunchBootstrap`
// composition end-to-end against a fresh temporary directory:
//
// 1. Tempdir contains no `<app_support>/maps/world.pmtiles` at start.
// 2. Invoke the copier -> post-invocation the file exists on disk,
//    matches the bundled asset length, and sha256 matches the expected
//    hash passed to the copier.
// 3. Mutation test: corrupt the on-disk file (flip a byte), re-invoke
//    the copier -> auto-heal kicks in (file re-copied + sha256 matches
//    again).
//
// This test lives under `integration_test/` per the plan's spec; it
// runs under `flutter test` (TestWidgetsFlutterBinding) because the
// FirstLaunchWorldCopier has a test-seam (`withAssetLoader`) that lets
// us drive it with an in-memory byte stream instead of `rootBundle`.
// Plan 07-07 Task 2 covers the real-asset path on a physical device.

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/map/first_launch_world_copier.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Synthetic 32-byte "world" payload. The real Phase 07-01 bundled
  // asset is 856 KB; the test substitutes a smaller payload because
  // the copier's contract is agnostic to size, and CI hosts run faster
  // with tiny fixtures. Plan 07-07 Task 2 covers the real-asset path.
  final Uint8List worldBytes = Uint8List.fromList(
    List<int>.generate(32, (int i) => (i * 7) & 0xFF, growable: false),
  );
  final String worldSha256 = sha256.convert(worldBytes).toString();
  final ByteData worldByteData = ByteData.sublistView(worldBytes);

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('first_launch_world_copy_test_');
  });

  tearDown(() async {
    try {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    } on Object {
      // Windows occasionally holds file handles; tolerate.
    }
  });

  test('first launch on clean tempdir writes world.pmtiles with correct sha256', () async {
    // Sanity: world.pmtiles does NOT exist pre-invocation.
    final File target = File(p.join(tmpDir.path, kWorldPmtilesInternalPath));
    expect(target.existsSync(), isFalse, reason: 'precondition: tempdir must be clean');

    // Build the copier with the test seam so we do not depend on the
    // bundled asset in rootBundle (which requires a platform-view
    // binding + flutter_assets table that the default flutter_test
    // host runner does not always set up for 856 KB binary assets).
    final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
      appSupportDir: tmpDir.path,
      expectedSha256: worldSha256,
      loader: (_) async => worldByteData,
    );

    await copier.ensureInstalled();

    // Post-condition: file exists, length matches, sha256 matches.
    expect(target.existsSync(), isTrue);
    final Uint8List actualBytes = await target.readAsBytes();
    expect(actualBytes, equals(worldBytes));
    expect(sha256.convert(actualBytes).toString(), worldSha256);
  });

  test('idempotent second call does not re-invoke the asset loader', () async {
    int loaderCallCount = 0;
    final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
      appSupportDir: tmpDir.path,
      expectedSha256: worldSha256,
      loader: (_) async {
        loaderCallCount++;
        return worldByteData;
      },
    );

    await copier.ensureInstalled();
    expect(loaderCallCount, 1, reason: 'first launch must invoke the loader once');

    // Second call on a healthy disk: the copier hashes the existing
    // file, confirms the sha256 matches, returns early. The loader
    // must NOT be invoked again.
    await copier.ensureInstalled();
    expect(loaderCallCount, 1, reason: 'idempotent second call must skip the loader');
  });

  test('mutation: corrupt file on disk -> auto-heal re-copies + sha256 matches', () async {
    int loaderCallCount = 0;
    final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
      appSupportDir: tmpDir.path,
      expectedSha256: worldSha256,
      loader: (_) async {
        loaderCallCount++;
        return worldByteData;
      },
    );

    // Seed the happy path first.
    await copier.ensureInstalled();
    expect(loaderCallCount, 1);

    // Corrupt the file on disk by flipping a byte — simulates bit rot
    // / a previous partial write that a prior process left behind.
    final File target = File(p.join(tmpDir.path, kWorldPmtilesInternalPath));
    final Uint8List bytes = await target.readAsBytes();
    final Uint8List corrupted = Uint8List.fromList(bytes);
    corrupted[0] = corrupted[0] ^ 0xFF;
    await target.writeAsBytes(corrupted, flush: true);
    expect(
      sha256.convert(await target.readAsBytes()).toString(),
      isNot(worldSha256),
      reason: 'precondition: file must be corrupted after the flip',
    );

    // Invoke again: copier detects sha mismatch + re-copies from the
    // loader. Post-heal: file bytes match the original + loader was
    // invoked a second time.
    await copier.ensureInstalled();
    expect(loaderCallCount, 2, reason: 'corrupt file must trigger the loader to re-copy');
    final Uint8List healedBytes = await target.readAsBytes();
    expect(healedBytes, equals(worldBytes));
    expect(sha256.convert(healedBytes).toString(), worldSha256);
  });
}

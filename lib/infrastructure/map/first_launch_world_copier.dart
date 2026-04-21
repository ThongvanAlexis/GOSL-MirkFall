// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/config/world_bundle_sha256.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:path/path.dart' as p;

/// Copies the bundled world PMTiles asset to the app-support directory
/// on first launch and auto-heals on corruption.
///
/// Behaviour (MAP-07 — non-deletable floor):
/// - If `<app_support>/maps/world.pmtiles` exists and its sha256 matches
///   [kWorldBundleSha256]: no-op, return immediately.
/// - Otherwise (missing or corrupted): delete any stale file, load the
///   asset from `rootBundle`, write it to disk using a streamed sink,
///   verify the post-write sha256. A mismatch at this stage throws
///   [MapAssetMissingException] (the asset bundle itself is broken —
///   shipping an APK without a valid world.pmtiles is catastrophic).
///
/// Why streamed write + not `writeAsBytes` on a 856 KB buffer:
/// - Establishes the streaming-write pattern Plan 07-04 reuses for the
///   1.5 GB chunk-reassembly case. Keeping the shape consistent across
///   both plans means any future refactor of the filesystem pattern
///   (e.g. `Isolate.spawn` for very large writes) applies to both.
/// - `File.openWrite` + `IOSink.add` avoids holding two copies of the
///   byte list in memory (one in the asset cache, one for the write
///   buffer) when the write is actually happening — marginal on 856 KB
///   but free to do correctly from day one.
class FirstLaunchWorldCopier {
  FirstLaunchWorldCopier({required String appSupportDir, String expectedSha256 = kWorldBundleSha256, WorldAssetLoader? assetLoader})
    : _appSupportDir = appSupportDir,
      _expectedSha256 = expectedSha256,
      _assetLoader = assetLoader ?? _defaultAssetLoader;

  final String _appSupportDir;
  final String _expectedSha256;
  final WorldAssetLoader _assetLoader;

  /// Absolute path where the world PMTiles lives at runtime.
  String get worldFilename => p.join(_appSupportDir, kWorldPmtilesInternalPath);

  /// Ensures the world PMTiles is on disk + matches the expected sha256.
  /// Idempotent — call once per app launch from the bootstrap.
  Future<void> ensureInstalled() async {
    final File target = File(worldFilename);
    if (await target.exists()) {
      final String actual = await _hashFile(target);
      if (actual == _expectedSha256) {
        // Already healthy, nothing to do.
        return;
      }
      // Corrupted or previous-version copy — wipe and re-copy.
      await target.delete();
    }

    // Ensure parent dir exists.
    await target.parent.create(recursive: true);

    final ByteData assetBytes;
    try {
      assetBytes = await _assetLoader(kWorldPmtilesAssetPath);
    } on Object catch (e) {
      throw MapAssetMissingException(assetPath: kWorldPmtilesAssetPath, reason: 'rootBundle.load failed: $e');
    }
    final Uint8List buffer = assetBytes.buffer.asUint8List(assetBytes.offsetInBytes, assetBytes.lengthInBytes);
    if (buffer.isEmpty) {
      throw const MapAssetMissingException(assetPath: kWorldPmtilesAssetPath, reason: 'asset byte stream was empty');
    }

    // Streamed write — mirrors the chunk-reassembly shape Plan 07-04
    // will reuse for 1.5 GB payloads.
    final IOSink sink = target.openWrite();
    try {
      sink.add(buffer);
      await sink.flush();
    } finally {
      await sink.close();
    }

    // Post-write verification.
    final String postHash = await _hashFile(target);
    if (postHash != _expectedSha256) {
      await target.delete().catchError((Object _) => target);
      throw MapAssetMissingException(assetPath: kWorldPmtilesAssetPath, reason: 'post-write sha256 mismatch: expected=$_expectedSha256, actual=$postHash');
    }
  }

  Future<String> _hashFile(File f) async {
    final Digest digest = await sha256.bind(f.openRead()).first;
    return digest.toString();
  }
}

typedef WorldAssetLoader = Future<ByteData> Function(String path);

Future<ByteData> _defaultAssetLoader(String path) => rootBundle.load(path);

/// Test-facing hook for [FirstLaunchWorldCopier]. Production call sites
/// never see this injection point.
extension FirstLaunchWorldCopierTestSeam on FirstLaunchWorldCopier {
  static FirstLaunchWorldCopier withAssetLoader({
    required String appSupportDir,
    required String expectedSha256,
    required Future<ByteData> Function(String path) loader,
  }) {
    return FirstLaunchWorldCopier(appSupportDir: appSupportDir, expectedSha256: expectedSha256, assetLoader: loader);
  }
}

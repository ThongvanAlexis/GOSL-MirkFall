// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:path/path.dart' as p;

/// Filesystem-backed [InstalledManifestRepository].
///
/// Storage path: `<app_support>/[kInstalledManifestPath]` →
/// `<app_support>/maps/installed.json`.
///
/// ## Atomic write
///
/// Mirrors the Phase 03 `DbBackupService` atomic-write precedent (and
/// the same pattern Plan 07-04's [DownloadQueueStore] uses for the
/// queue file):
///
/// 1. Serialize the manifest to JSON.
/// 2. Write to `<path>.tmp` with `flush: true` (forces fsync).
/// 3. `tmp.rename(<path>)` — atomic on ext4/APFS/NTFS.
///
/// A crash between steps 2 and 3 leaves a stale `.tmp` file; subsequent
/// [read] calls ignore it (we only look at the canonical path) and the
/// next successful [write] overwrites the `.tmp` with fresh bytes. The
/// alternative — leaving half-written JSON under the canonical name —
/// is exactly what this pattern prevents (RESEARCH Pitfall #1).
///
/// ## Serialization policy
///
/// The serializer guarantees stable key order by delegating to
/// `json_serializable`-emitted `toJson()`. Field order within nested
/// `InstalledCountry` entries matches their Freezed declaration order;
/// the outer `installed` map serializes its alpha3 keys in insertion
/// order (Dart's `Map` preserves insertion order), which matches how
/// [copyWithInsert] adds entries.
///
/// Corrupted-file policy: any parse failure raises
/// [SchemaValidationException] so the bootstrap surface can decide
/// whether to heal (re-scan the `countries/` tree + rebuild the
/// manifest from on-disk sha256s) or fall back to [InstalledManifest.empty].
/// The plan's bootstrap attempts a heal first.
class JsonFileInstalledManifestRepository implements InstalledManifestRepository {
  JsonFileInstalledManifestRepository({required String appSupportDir, Logger? logger})
    : _filename = p.join(appSupportDir, kInstalledManifestPath),
      _log = logger ?? Logger('infrastructure.installed_maps.manifest_repository');

  final String _filename;
  final Logger _log;

  final StreamController<InstalledManifest> _updatesCtrl = StreamController<InstalledManifest>.broadcast();

  // A single-writer mutex: Plan 07-04 serializes manifest writes behind
  // its download controller, but the port contract also accepts a
  // settings-screen "delete country" path that may land concurrently.
  // Queueing writes here preserves the broadcast-stream ordering
  // invariant documented in `installed_manifest_repository.dart`.
  Future<void> _writeTail = Future<void>.value();

  /// Absolute path to the canonical manifest file.
  String get filename => _filename;

  @override
  Future<InstalledManifest> read() async {
    final File f = File(_filename);
    if (!f.existsSync()) return InstalledManifest.empty();
    final String contents;
    try {
      contents = await f.readAsString();
    } on FileSystemException catch (e) {
      _log.warning('read: filesystem error for $_filename: $e');
      throw SchemaValidationException(documentPath: _filename, reason: 'filesystem error: $e');
    }
    if (contents.isEmpty) {
      // Treat empty file the same as missing — empty manifest.
      return InstalledManifest.empty();
    }
    try {
      final Object? decoded = jsonDecode(contents);
      if (decoded is! Map<String, Object?>) {
        throw SchemaValidationException(documentPath: _filename, reason: 'expected top-level JSON object, got ${decoded.runtimeType}');
      }
      return InstalledManifest.fromJson(decoded);
    } on SchemaValidationException {
      rethrow;
    } on Object catch (e) {
      throw SchemaValidationException(documentPath: _filename, reason: 'parse error: $e');
    }
  }

  @override
  Future<void> write(InstalledManifest manifest) {
    // Chain each write onto the previous one to preserve ordering on the
    // broadcast stream + avoid interleaved `.tmp` renames racing each
    // other on the same canonical filename.
    final Future<void> previous = _writeTail;
    final Completer<void> gate = Completer<void>();
    _writeTail = gate.future;
    return previous.then((_) => _doWrite(manifest)).whenComplete(() => gate.complete());
  }

  Future<void> _doWrite(InstalledManifest manifest) async {
    final File canonical = File(_filename);
    await canonical.parent.create(recursive: true);
    final File tmp = File('$_filename.tmp');
    final String encoded = jsonEncode(manifest.toJson());
    await tmp.writeAsString(encoded, flush: true);
    await tmp.rename(_filename);
    _updatesCtrl.add(manifest);
  }

  @override
  Stream<InstalledManifest> get updates => _updatesCtrl.stream;

  /// Closes the broadcast controller. Call once at app shutdown; tests
  /// that wire up this repo in `setUp` should call it from `tearDown`.
  Future<void> close() async {
    await _updatesCtrl.close();
  }
}

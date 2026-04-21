// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:path/path.dart' as p;

/// Persistent JSON-backed queue of pending [DownloadJob] entries.
///
/// Survives app restarts: the Plan 07-05 `DownloadQueueController`
/// rehydrates its in-memory queue from here at startup. The queue file
/// lives at `<app_support>/maps/download_queue.json`; the atomic write
/// path mirrors `JsonFileInstalledManifestRepository` (tempfile +
/// rename, Phase 03 `DbBackupService`-style precedent).
///
/// Corrupted-file policy: if the JSON is truncated or malformed, [load]
/// returns an empty list and logs a warning. The alternative — throwing —
/// would leave the user's queue unrecoverable with no resume path; the
/// worst case here is a queue reset after a rare crash, which is
/// recoverable by re-adding the countries.
class DownloadQueueStore {
  DownloadQueueStore({required String appSupportDir, Logger? logger})
    : _filename = p.join(appSupportDir, _kRelativePath),
      _log = logger ?? Logger('infrastructure.downloads.download_queue_store');

  static const String _kRelativePath = 'maps/download_queue.json';

  final String _filename;
  final Logger _log;

  /// Absolute path to the backing JSON file.
  String get filename => _filename;

  /// Loads the queue from disk. Returns an empty list if the file does
  /// not exist or cannot be parsed (warning logged).
  Future<List<DownloadJob>> load() async {
    final File f = File(_filename);
    if (!f.existsSync()) return <DownloadJob>[];
    final String contents;
    try {
      contents = await f.readAsString();
    } on FileSystemException catch (e) {
      _log.warning('load: could not read $_filename: $e — returning empty queue');
      return <DownloadJob>[];
    }
    if (contents.isEmpty) return <DownloadJob>[];
    try {
      final Object? decoded = jsonDecode(contents);
      if (decoded is! List) {
        _log.warning('load: expected top-level JSON list, got ${decoded.runtimeType} — returning empty queue');
        return <DownloadJob>[];
      }
      return decoded
          .whereType<Map<String, Object?>>()
          .map(DownloadJob.fromJson)
          .toList(growable: false);
    } on Object catch (e) {
      _log.warning('load: JSON decode failed for $_filename: $e — returning empty queue');
      return <DownloadJob>[];
    }
  }

  /// Writes [queue] atomically via tempfile + rename. A crash mid-write
  /// leaves either the previous file or nothing visible — never a
  /// truncated JSON document.
  Future<void> save(List<DownloadJob> queue) async {
    final File f = File(_filename);
    await f.parent.create(recursive: true);
    final File tmp = File('$_filename.tmp');
    final String encoded = jsonEncode(queue.map((DownloadJob j) => j.toJson()).toList(growable: false));
    // flush: true forces fsync so the tempfile's bytes are durable
    // before the rename swap happens.
    await tmp.writeAsString(encoded, flush: true);
    await tmp.rename(_filename);
  }
}

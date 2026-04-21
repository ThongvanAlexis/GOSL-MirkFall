// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:mirkfall/domain/downloads/download_errors.dart';

/// Streams the bytes of every file in [parts] into [destination] via
/// `File.openWrite()` / `IOSink.add` without loading any part into heap.
///
/// Contract:
/// - Parts are concatenated **in the order provided** — callers are
///   responsible for giving the chunks in part-index order.
/// - A partial write aborts the destination file: on any failure the
///   returned [Future] completes with [ConcatFailureException] AND the
///   destination is deleted before the exception propagates. Keeps the
///   "staging or absent, never garbage" invariant at the file-level.
/// - The destination's parent directory is created if missing (same
///   idiom as `FirstLaunchWorldCopier` from Plan 07-03).
///
/// Memory footprint: the only in-RAM buffer is one filesystem read
/// chunk (typically 64 KB on POSIX) — a 1.5 GB reassembled country
/// bundle flows through this helper without an extra heap spike.
class BinaryConcatenator {
  const BinaryConcatenator();

  /// Concatenates every file in [parts] into [destination].
  ///
  /// Throws:
  /// - [ConcatFailureException] when the parts list is empty, a part is
  ///   missing, or the underlying IOSink write fails mid-stream. The
  ///   partially-written [destination] is unlinked before the exception
  ///   propagates.
  Future<void> concat({required List<File> parts, required File destination}) async {
    if (parts.isEmpty) {
      throw const ConcatFailureException(reason: 'parts list was empty');
    }
    for (final File part in parts) {
      if (!part.existsSync()) {
        throw ConcatFailureException(reason: 'part missing: ${part.path}');
      }
    }
    await destination.parent.create(recursive: true);

    final IOSink sink = destination.openWrite();
    bool closed = false;
    try {
      for (final File part in parts) {
        // addStream drains the file byte stream into the destination
        // sink one filesystem chunk at a time — constant memory.
        await sink.addStream(part.openRead());
      }
      await sink.flush();
      await sink.close();
      closed = true;
    } on Object catch (e) {
      if (!closed) {
        // Best-effort close; ignore failures, the write path already failed.
        await sink.close().catchError((Object _) => sink);
      }
      if (destination.existsSync()) {
        try {
          await destination.delete();
        } on FileSystemException {
          // Best-effort cleanup; don't mask the original failure.
        }
      }
      if (e is ConcatFailureException) rethrow;
      throw ConcatFailureException(reason: 'IOSink write failed: $e');
    }
  }
}

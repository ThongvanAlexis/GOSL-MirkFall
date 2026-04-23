// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mirkfall/domain/downloads/download_errors.dart';

/// Streams the bytes of every file in [parts] into [destination] via
/// `File.openWrite()` / `IOSink.add` without loading any part into heap,
/// AND computes the sha256 of the reassembled bytes in the same pass.
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
/// - The returned [String] is the hex-encoded sha256 of the bytes
///   written to [destination]. Piped through `startChunkedConversion`
///   so the hash comes for free in the same disk read — no second
///   pass over the reassembled file.
///
/// Memory footprint: the only in-RAM buffer is one filesystem read
/// chunk (typically 64 KB on POSIX) — a 1.5 GB reassembled country
/// bundle flows through this helper without an extra heap spike.
class BinaryConcatenator {
  const BinaryConcatenator();

  /// Concatenates every file in [parts] into [destination] and returns
  /// the sha256 (hex) of the reassembled bytes.
  ///
  /// Throws:
  /// - [ConcatFailureException] when the parts list is empty, a part is
  ///   missing, or the underlying IOSink write fails mid-stream. The
  ///   partially-written [destination] is unlinked before the exception
  ///   propagates.
  Future<String> concat({required List<File> parts, required File destination}) async {
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
    final _DigestCollector collector = _DigestCollector();
    final ByteConversionSink hasher = sha256.startChunkedConversion(collector);
    bool closed = false;
    bool hasherClosed = false;
    try {
      for (final File part in parts) {
        // Iterate filesystem chunks ourselves (instead of addStream) so
        // we can tee each buffer into both the destination sink and the
        // sha256 chunked converter — one disk read feeds both.
        await for (final List<int> bytes in part.openRead()) {
          sink.add(bytes);
          hasher.add(bytes);
        }
      }
      await sink.flush();
      await sink.close();
      closed = true;
      hasher.close();
      hasherClosed = true;
      return collector.digest.toString();
    } on Object catch (e) {
      if (!closed) {
        // Best-effort close; ignore failures, the write path already failed.
        await sink.close().catchError((Object _) => sink);
      }
      if (!hasherClosed) {
        hasher.close();
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

/// Minimal `Sink<Digest>` that captures the single final digest emitted
/// by `sha256.startChunkedConversion`. Kept local to avoid pulling
/// `package:convert`'s `AccumulatorSink` as a direct dependency.
class _DigestCollector implements Sink<Digest> {
  Digest? _digest;

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}

  Digest get digest {
    final Digest? d = _digest;
    if (d == null) {
      throw StateError('sha256 digest was never emitted — the chunked-conversion sink was not closed');
    }
    return d;
  }
}

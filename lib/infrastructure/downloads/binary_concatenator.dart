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
  /// [onPartStart] (optional) fires BEFORE the bytes of each part are
  /// streamed, with the 0-indexed part number and the total parts
  /// count. Drives the "Assemblage du bloc N/M" subtitle in the
  /// download UI — concat on a 5 GB bundle takes minutes, and without
  /// these emits the user sees a frozen progress bar.
  ///
  /// Throws:
  /// - [ConcatFailureException] when the parts list is empty, a part is
  ///   missing, or the underlying IOSink write fails mid-stream. The
  ///   partially-written [destination] is unlinked before the exception
  ///   propagates.
  Future<String> concat({required List<File> parts, required File destination, void Function(int partIndex, int totalParts)? onPartStart}) async {
    // Pre-open guards: throw ConcatFailureException directly without going through the
    // try/catch below. Addresses row #30 (§3) — wrapping these would have produced
    // misleading "IOSink write failed: ConcatFailureException(...)" rewrap chains.
    if (parts.isEmpty) {
      throw const ConcatFailureException(reason: 'parts list was empty');
    }
    for (final File part in parts) {
      if (!part.existsSync()) {
        throw ConcatFailureException(reason: 'part missing: ${part.path}');
      }
    }
    try {
      await destination.parent.create(recursive: true);
    } on FileSystemException catch (e) {
      throw ConcatFailureException(reason: 'could not create destination parent ${destination.parent.path}: ${e.message}');
    }

    final IOSink sink = destination.openWrite();
    final _DigestCollector collector = _DigestCollector();
    final ByteConversionSink hasher = sha256.startChunkedConversion(collector);
    bool closed = false;
    bool hasherClosed = false;
    try {
      for (int i = 0; i < parts.length; i++) {
        onPartStart?.call(i, parts.length);
        final File part = parts[i];
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
    } on FileSystemException catch (e) {
      await _cleanup(sink: sink, sinkClosed: closed, hasher: hasher, hasherClosed: hasherClosed, destination: destination);
      throw ConcatFailureException(reason: 'filesystem I/O failed during concat: ${e.message}');
    } on IOException catch (e) {
      await _cleanup(sink: sink, sinkClosed: closed, hasher: hasher, hasherClosed: hasherClosed, destination: destination);
      throw ConcatFailureException(reason: 'I/O error during concat: $e');
    }
  }

  /// Cleanup on concat failure — close sink (best-effort), close hasher, delete partial destination.
  /// Keeps the "staging or absent, never garbage" invariant on the failure path.
  Future<void> _cleanup({
    required IOSink sink,
    required bool sinkClosed,
    required ByteConversionSink hasher,
    required bool hasherClosed,
    required File destination,
  }) async {
    if (!sinkClosed) {
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

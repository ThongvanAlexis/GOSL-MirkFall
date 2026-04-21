// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Streams sha256 hash of a file with constant memory footprint.
///
/// Why a dedicated class rather than the raw one-liner: keeping a
/// single canonical helper around the streaming idiom means every
/// caller gets the constant-memory guarantee without re-discovering
/// the shape, and tests exercising this contract stay focussed on one
/// surface.
///
/// Implementation: `sha256.bind(file.openRead())` produces a
/// `Stream<Digest>` that pulls byte chunks from the file's openRead
/// stream into sha256's internal hash state one filesystem chunk at a
/// time (typically 64 KB on POSIX). No full-file buffer is ever
/// materialized in heap — 1.5 GB reassembled country bundles flow
/// through this helper without an extra allocation spike.
///
/// Phase 07-01 SUMMARY §Issues Encountered issue #1 explicitly decided
/// to keep `package:convert` out of direct deps, so we avoid the
/// `AccumulatorSink` idiom from that package. `sha256.bind` is
/// functionally equivalent and ships with `package:crypto` alone.
///
/// Contract:
/// - [ofFile] returns the lower-case hex digest as `String` (64 chars).
/// - Throws [FileSystemException] when the file does not exist or is
///   unreadable.
class Sha256Verifier {
  /// Default ctor; the class is stateless. Left instantiable (rather
  /// than a set of static helpers) so `PmtilesDownloadController` can
  /// inject a test fake that records every verified path without
  /// monkey-patching.
  const Sha256Verifier();

  /// Streams [file]'s bytes through sha256 and returns the hex digest.
  ///
  /// Used by:
  /// - Plan 07-04 per-chunk verification (after each part lands).
  /// - Plan 07-04 reassembled-file verification (after concat).
  Future<String> ofFile(File file) async {
    if (!file.existsSync()) {
      throw FileSystemException('Sha256Verifier.ofFile: file does not exist', file.path);
    }
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

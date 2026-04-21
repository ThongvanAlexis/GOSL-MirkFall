// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Download-layer domain exceptions.
//
// Every class `implements Exception` — never `extends Error` — per
// CLAUDE.md §Error handling. `toString()` inlines structured fields so
// log inspection reveals the full context.

/// Thrown when an in-flight transfer is interrupted before all bytes are
/// received (socket hangup, timeout, airplane-mode toggle). [reason]
/// carries the upstream message (e.g. `"connection reset"`,
/// `"timeout after 60s"`).
///
/// The pipeline catches, retries up to `kDownloadRetryAttempts`, and
/// only surfaces [DownloadInterruptedException] to the caller on final
/// failure.
class DownloadInterruptedException implements Exception {
  const DownloadInterruptedException({required this.reason});

  final String reason;

  @override
  String toString() => 'DownloadInterruptedException(reason=$reason)';
}

/// Thrown when a downloaded artifact's sha256 does not match the
/// catalog's declared hash. [expected] and [actual] are 64-char hex
/// digests (lower-case). [at] identifies which artifact — either a
/// specific chunk (`"parts[3]"`) or the reassembled file
/// (`"reassembled"`).
class Sha256MismatchException implements Exception {
  const Sha256MismatchException({required this.expected, required this.actual, required this.at});

  final String expected;
  final String actual;

  /// Location identifier — e.g. `"parts[2]"` for the 3rd chunk or
  /// `"reassembled"` for the post-concatenation verification.
  final String at;

  @override
  String toString() => 'Sha256MismatchException(at=$at, expected=$expected, actual=$actual)';
}

/// Thrown when chunks fail to concatenate into the expected reassembled
/// file (I/O error during append, byte-count mismatch mid-flush, etc.).
///
/// Distinct from [DownloadInterruptedException] — the network phase
/// already completed when this fires. Recovery: delete the staging
/// directory + restart from the first chunk.
class ConcatFailureException implements Exception {
  const ConcatFailureException({required this.reason});

  final String reason;

  @override
  String toString() => 'ConcatFailureException(reason=$reason)';
}

/// Thrown when the CDN does not honour an HTTP Range request, so the
/// pipeline cannot resume a partially-transferred chunk.
///
/// Current Phase 07 hosting (GitHub Releases) always supports Range
/// requests, so this is defensive: a future mirror migration that drops
/// Range support will surface this exception instead of silently
/// re-downloading the entire chunk.
class HttpRangeNotSupportedException implements Exception {
  const HttpRangeNotSupportedException({required this.responseCode});

  final int responseCode;

  @override
  String toString() => 'HttpRangeNotSupportedException(responseCode=$responseCode)';
}

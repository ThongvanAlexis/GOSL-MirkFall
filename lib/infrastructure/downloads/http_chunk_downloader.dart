// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/downloads/download_errors.dart';

/// Result of a single [HttpChunkDownloader.downloadWithResume] call.
///
/// Callers only branch on [restartedFrom200] — that's the one value that
/// carries a semantic obligation (re-baseline the accumulated-bytes
/// counter because the onProgress callback reported the full part.size
/// instead of the delta; see §3 row #7 regression evidence).
///
/// The other two values ([resumedWith206], [downloadedFresh]) exist to
/// make the happy-path observable in tests and logs — they do not drive
/// caller behavior. Consumers should use [DownloadChunkResultX.isUnexpectedRestart]
/// instead of pattern-matching on all three variants.
///
/// - [resumedWith206] — the server honoured the Range header and appended
///   to the existing destination (Partial Content).
/// - [restartedFrom200] — the server ignored the Range header; the
///   destination was truncated and rewritten from byte 0.
/// - [downloadedFresh] — the destination did not exist before the call,
///   so no Range header was sent; the full response was written from
///   scratch.
enum DownloadChunkResult { resumedWith206, restartedFrom200, downloadedFresh }

/// Semantic predicates over [DownloadChunkResult]. Extension rather than
/// plain methods so the enum can stay a canonical const list — callers
/// should reach for [isUnexpectedRestart] instead of comparing against
/// [DownloadChunkResult.restartedFrom200] by hand (addresses §3 row #31).
extension DownloadChunkResultX on DownloadChunkResult {
  /// `true` when the server ignored the Range request and rewrote the
  /// destination from byte 0. Resume-path callers must use this to
  /// un-pre-add any bytes they credited to the progress counter before
  /// issuing the Range request.
  bool get isUnexpectedRestart => this == DownloadChunkResult.restartedFrom200;
}

/// HTTP chunk downloader with Range resume + graceful 200-OK fallback.
///
/// Pure `dart:io` — deliberately does NOT adopt `package:http` (no new
/// audited transitive, and the platform HttpClient gives finer control
/// over redirects + compression than the high-level wrapper).
///
/// Contract:
/// - Sends `Range: bytes=N-` when the destination file already has N
///   bytes on disk. The server MUST respond with:
///   - `206 Partial Content` → append mode.
///   - `200 OK` → truncate the destination + rewrite from byte 0.
/// - Follows redirects (needed for GitHub CDN per RESEARCH Pitfall #7).
/// - Returns an [HttpRangeNotSupportedException] when the server
///   responds with a non-Range-compatible 4xx/5xx after a resume
///   request (e.g. GitHub CDN 403 on expired redirect).
/// - All other error paths raise [DownloadInterruptedException] with
///   a descriptive reason; callers (Plan 07-04 controller) wrap a
///   retry policy around this.
///
/// `autoUncompress: false` is mandatory: chunks are binary (not gzip),
/// and HttpClient's transparent decompression would corrupt byte counts.
class HttpChunkDownloader {
  HttpChunkDownloader({HttpClient? client, Duration? timeout, Logger? logger})
    : _client = client ?? _defaultClient(),
      _timeout = timeout ?? const Duration(milliseconds: kHttpTimeout),
      _log = logger ?? Logger('infrastructure.downloads.http_chunk_downloader');

  static HttpClient _defaultClient() {
    final HttpClient c = HttpClient();
    c.autoUncompress = false;
    return c;
  }

  final HttpClient _client;
  final Duration _timeout;
  final Logger _log;

  /// Downloads [url] into [destination], honouring Range headers for
  /// resume.
  ///
  /// [onProgress] is invoked after every byte-chunk write with the
  /// number of bytes just written and the total expected bytes (may be
  /// null when the server does not advertise Content-Length).
  Future<DownloadChunkResult> downloadWithResume({
    required Uri url,
    required File destination,
    void Function(int bytesDelta, int? totalBytes)? onProgress,
  }) async {
    await destination.parent.create(recursive: true);

    final int resumeByte = destination.existsSync() ? await destination.length() : 0;
    DownloadChunkResult result;

    final HttpClientRequest req;
    try {
      req = await _client.getUrl(url).timeout(_timeout);
    } on TimeoutException catch (e) {
      throw DownloadInterruptedException(reason: 'connect timeout after ${_timeout.inSeconds}s: $e');
    } on SocketException catch (e) {
      throw DownloadInterruptedException(reason: 'socket error on connect: $e');
    } on HttpException catch (e) {
      throw DownloadInterruptedException(reason: 'http error on connect: $e');
    }

    if (resumeByte > 0) {
      req.headers.add(HttpHeaders.rangeHeader, 'bytes=$resumeByte-');
    }
    req.followRedirects = true;
    req.maxRedirects = 5;

    final HttpClientResponse res;
    try {
      res = await req.close().timeout(_timeout);
    } on TimeoutException catch (e) {
      throw DownloadInterruptedException(reason: 'response timeout after ${_timeout.inSeconds}s: $e');
    } on SocketException catch (e) {
      throw DownloadInterruptedException(reason: 'socket error while awaiting response: $e');
    } on HttpException catch (e) {
      throw DownloadInterruptedException(reason: 'http error while awaiting response: $e');
    }

    final int statusCode = res.statusCode;
    final bool asResumed = resumeByte > 0;

    if (asResumed && statusCode == HttpStatus.partialContent) {
      result = DownloadChunkResult.resumedWith206;
    } else if (asResumed && statusCode == HttpStatus.ok) {
      // Server ignored the Range header — safe fallback is to truncate
      // the destination and rewrite from byte 0. Log a warning so the
      // UI layer can surface it if it ever happens repeatedly.
      _log.warning('downloadWithResume: server ignored Range header (statusCode=200, resumeByte=$resumeByte) for $url — restarting from byte 0');
      await destination.writeAsBytes(<int>[], flush: true);
      result = DownloadChunkResult.restartedFrom200;
    } else if (!asResumed && statusCode == HttpStatus.ok) {
      result = DownloadChunkResult.downloadedFresh;
    } else if (asResumed && statusCode == HttpStatus.forbidden) {
      // GitHub CDN returns 403 on expired pre-signed URLs. Caller should
      // re-request the canonical URL to obtain a fresh redirect.
      await res.drain<void>();
      throw const DownloadInterruptedException(reason: 'CDN 403 on resume — signed redirect likely expired; caller should re-fetch canonical URL');
    } else if (statusCode >= 400 && statusCode < 500 && asResumed && statusCode != HttpStatus.forbidden) {
      // Range-specific 4xx error — classify as unsupported-Range.
      await res.drain<void>();
      throw HttpRangeNotSupportedException(responseCode: statusCode);
    } else {
      await res.drain<void>();
      throw DownloadInterruptedException(reason: 'HTTP $statusCode on ${url.toString()}');
    }

    final int? contentLength = res.contentLength >= 0 ? res.contentLength : null;
    final bool append = result == DownloadChunkResult.resumedWith206;
    final IOSink sink = destination.openWrite(mode: append ? FileMode.append : FileMode.write);
    try {
      await for (final List<int> chunk in res.timeout(_timeout)) {
        sink.add(chunk);
        onProgress?.call(chunk.length, contentLength);
      }
      await sink.flush();
      await sink.close();
    } on TimeoutException catch (e) {
      await sink.close().catchError((Object _) => sink);
      throw DownloadInterruptedException(reason: 'stream stalled past ${_timeout.inSeconds}s: $e');
    } on SocketException catch (e) {
      await sink.close().catchError((Object _) => sink);
      throw DownloadInterruptedException(reason: 'socket error mid-stream: $e');
    } on HttpException catch (e) {
      await sink.close().catchError((Object _) => sink);
      throw DownloadInterruptedException(reason: 'http error mid-stream: $e');
    }

    return result;
  }

  /// Closes the internal HttpClient. Call on app shutdown or from a
  /// `tearDown` in tests that inject their own client (passing a
  /// pre-owned client means the caller still owns the lifecycle).
  void close({bool force = false}) {
    _client.close(force: force);
  }
}

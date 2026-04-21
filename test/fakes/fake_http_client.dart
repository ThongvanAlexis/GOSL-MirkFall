// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// In-process shelf-backed HTTP server used by every chunk-download
/// test in Plan 07-04.
///
/// Rationale for the shelf approach (vs. mocking `dart:io`'s HttpClient
/// via `HttpOverrides.runZoned`):
///
/// - `HttpClient` is abstract + relies heavily on private implementations
///   (`_HttpClient`, `_HttpClientRequest`, `_HttpClientResponse`);
///   hand-rolled fakes have to stub a couple dozen methods each and are
///   notoriously brittle.
/// - A real shelf server exercises the same code path a production GitHub
///   CDN hits — headers flow through the OS socket, Content-Length is
///   emitted by shelf_io, Range responses follow the RFC 7233 wire format.
///   Bugs that only manifest at the wire level (missing Accept-Ranges,
///   wrong 206 status, truncated Content-Range) get caught here.
/// - `package:shelf` is already a direct dev_dependency since Plan 07-01
///   (promoted for Phase 07 download soak tests).
///
/// The server exposes a narrow configurable surface: each "behaviour"
/// is swappable at runtime via [behaviour]. Tests reshape the behaviour
/// between requests — supports mid-test "first GET fails, second GET
/// succeeds" recovery scenarios.
///
/// ## Supported behaviours
///
/// - [ServeHappy] — serves [bytes] with 200 OK (or 206 when Range is set).
/// - [ServeIgnoringRange] — ignores any Range header + serves 200 OK.
/// - [Serve403] — every request returns 403 Forbidden.
/// - [Serve500] — every request returns 500 Internal Server Error.
/// - [ServeDropConnectionAfterBytes] — writes `bytesBeforeDrop` bytes,
///   then closes the socket mid-stream (simulates real-world network
///   drop scenarios).
/// - [ServeRedirect] — returns 302 Found with Location header → the
///   caller follows redirects transparently.
class FakeHttpServer {
  FakeHttpServer._(this._inner, this.bytes);

  final HttpServer _inner;

  /// The bytes exposed by a [ServeHappy]/[ServeIgnoringRange] response.
  /// Mutable so tests can shift the payload between requests (e.g.
  /// "first GET corrupted, second GET clean").
  Uint8List bytes;

  /// Current behaviour. Mutable; change it between requests to exercise
  /// state-transition paths.
  FakeServerBehaviour behaviour = const ServeHappy();

  /// Ordered log of every request received. Exposes the request method,
  /// full path, and the Range header value (null when absent) — enough
  /// to assert on retry + resume semantics.
  final List<RecordedRequest> recordedRequests = <RecordedRequest>[];

  /// The base URL the HTTP client should target.
  Uri get base => Uri.parse('http://${_inner.address.host}:${_inner.port}');

  /// Spawns a bound server on a random free port.
  static Future<FakeHttpServer> bind({Uint8List? initialBytes}) async {
    final FakeHttpServer holder = FakeHttpServer._(await _bindSilently(), initialBytes ?? Uint8List(0));
    shelf_io.serveRequests(holder._inner, holder._handle);
    return holder;
  }

  static Future<HttpServer> _bindSilently() => HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  Future<shelf.Response> _handle(shelf.Request req) async {
    final String? rangeHeader = req.headers['range'];
    recordedRequests.add(RecordedRequest(method: req.method, path: req.requestedUri.path, rangeHeader: rangeHeader));

    final FakeServerBehaviour current = behaviour;
    switch (current) {
      case ServeHappy():
        return _serveHappy(rangeHeader);
      case ServeIgnoringRange():
        return shelf.Response.ok(bytes, headers: <String, Object>{'content-length': '${bytes.length}'});
      case Serve403():
        return shelf.Response.forbidden('forbidden');
      case Serve500():
        return shelf.Response.internalServerError(body: 'server error');
      case ServeDropConnectionAfterBytes(:final int bytesBeforeDrop):
        return _serveDrop(bytesBeforeDrop);
      case ServeRedirect(:final Uri target):
        return shelf.Response.found(target.toString());
      case ServeChunkedSlowly(:final List<Uint8List> segments, :final Duration interval):
        return _serveChunkedSlowly(segments, interval);
    }
  }

  shelf.Response _serveChunkedSlowly(List<Uint8List> segments, Duration interval) {
    // Feed the response body one segment at a time with [interval] gaps
    // between segments. Content-Length is still the full payload so the
    // client reads until EOF without suspecting truncation. Used by the
    // throttled-progress tests to prove the pipeline emits mid-chunk
    // DownloadInProgress events — not just at chunk boundaries.
    final int totalLength = segments.fold<int>(0, (sum, s) => sum + s.length);
    final StreamController<List<int>> ctrl = StreamController<List<int>>();
    Future<void>.microtask(() async {
      for (int i = 0; i < segments.length; i++) {
        if (i > 0) await Future<void>.delayed(interval);
        ctrl.add(segments[i]);
      }
      await ctrl.close();
    });
    return shelf.Response.ok(ctrl.stream, headers: <String, Object>{'content-length': '$totalLength'});
  }

  shelf.Response _serveHappy(String? rangeHeader) {
    if (rangeHeader == null) {
      return shelf.Response.ok(bytes, headers: <String, Object>{'content-length': '${bytes.length}'});
    }
    // Expected shape: "bytes=N-" (open-ended). Narrower forms are not
    // produced by HttpChunkDownloader but accepted defensively.
    final RegExpMatch? match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(rangeHeader);
    if (match == null) {
      return shelf.Response(416, body: 'invalid range');
    }
    final int start = int.parse(match.group(1)!);
    final int end = (match.group(2) == null || match.group(2)!.isEmpty) ? bytes.length - 1 : int.parse(match.group(2)!);
    if (start >= bytes.length) {
      return shelf.Response(416, body: 'range beyond payload');
    }
    final Uint8List slice = Uint8List.sublistView(bytes, start, end + 1);
    return shelf.Response(
      206,
      body: slice,
      headers: <String, Object>{'content-length': '${slice.length}', 'content-range': 'bytes $start-$end/${bytes.length}', 'accept-ranges': 'bytes'},
    );
  }

  shelf.Response _serveDrop(int bytesBeforeDrop) {
    // Emit a stream that errors out after sending the prefix. Using an
    // explicit stream error (rather than just closing short of an
    // advertised Content-Length) keeps the server-side shelf_io write
    // path from raising an unhandled HttpException into the test zone.
    // The client sees the stream error as a truncation, which
    // HttpChunkDownloader wraps in DownloadInterruptedException.
    final Uint8List prefix = bytes.length >= bytesBeforeDrop ? Uint8List.sublistView(bytes, 0, bytesBeforeDrop) : bytes;
    final StreamController<List<int>> ctrl = StreamController<List<int>>();
    Future<void>.microtask(() async {
      if (prefix.isNotEmpty) ctrl.add(prefix);
      ctrl.addError(const SocketException('simulated mid-stream drop'));
      await ctrl.close();
    });
    // Do NOT advertise a content-length — let the response transfer
    // chunked so the abrupt close looks like an incomplete read
    // (HttpException or SocketException depending on timing) on the
    // client side rather than a shelf-side contentLength violation.
    return shelf.Response.ok(ctrl.stream);
  }

  Future<void> close() => _inner.close(force: true);
}

/// Immutable record of a single request seen by [FakeHttpServer].
class RecordedRequest {
  const RecordedRequest({required this.method, required this.path, required this.rangeHeader});
  final String method;
  final String path;
  final String? rangeHeader;
}

/// Behaviour strategies for [FakeHttpServer]. Sealed so tests can
/// pattern-match exhaustively.
sealed class FakeServerBehaviour {
  const FakeServerBehaviour();
}

/// Serve [FakeHttpServer.bytes] with 200 OK or 206 Partial Content
/// depending on whether a Range header is present.
class ServeHappy extends FakeServerBehaviour {
  const ServeHappy();
}

/// Serve [FakeHttpServer.bytes] with a plain 200 OK ignoring any Range
/// header the client sends.
class ServeIgnoringRange extends FakeServerBehaviour {
  const ServeIgnoringRange();
}

/// Always return 403 Forbidden.
class Serve403 extends FakeServerBehaviour {
  const Serve403();
}

/// Always return 500 Internal Server Error.
class Serve500 extends FakeServerBehaviour {
  const Serve500();
}

/// Send the first [bytesBeforeDrop] bytes of [FakeHttpServer.bytes]
/// then close the connection without delivering the rest (the
/// advertised Content-Length stays the full payload size so the client
/// perceives the drop as a truncation).
class ServeDropConnectionAfterBytes extends FakeServerBehaviour {
  const ServeDropConnectionAfterBytes({required this.bytesBeforeDrop});
  final int bytesBeforeDrop;
}

/// Return a 302 Found with Location header pointing to [target]. Used
/// to exercise HttpClient's redirect-following path.
class ServeRedirect extends FakeServerBehaviour {
  const ServeRedirect({required this.target});
  final Uri target;
}

/// Emit [segments] as a streamed response, waiting [interval] between
/// each segment. Content-Length advertises the total payload size; the
/// client sees a slow trickle that matches a real-world bandwidth-
/// limited transfer. Used by the throttled-progress tests to prove the
/// pipeline emits mid-chunk `DownloadInProgress` events at the
/// `kDownloadProgressEmitThrottleMs` cadence — not just one per chunk
/// boundary.
class ServeChunkedSlowly extends FakeServerBehaviour {
  const ServeChunkedSlowly({required this.segments, required this.interval});
  final List<Uint8List> segments;
  final Duration interval;
}

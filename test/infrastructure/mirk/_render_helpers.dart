// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Test-internal helpers for the Phase 09 plan 09-04 renderer suites.
// Underscore-prefixed filename indicates "do not import outside
// test/infrastructure/mirk/" — `flutter analyze` will not complain
// because the file lives under `test/`.
//
// BUG-010 Option B Commit 5 — fixture surface migrated from cell-bitmap
// `VisibleMirkTile` rows to continuous-geometry `RevealDisc`s. The
// `make*Bitmap` helpers were removed (no caller post-Commit-5).

import 'dart:typed_data';
import 'dart:ui';

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

/// Default canvas size for renderer tests — small enough to keep PNG
/// encode time under a few ms, large enough for the visual-distinctness
/// byte-diff assertion to discriminate.
const Size kTestCanvasSize = Size(256, 256);

/// Builds a [MirkPaintContext] for renderer tests with a single 100 m
/// reveal disc at the centre of a Marseille-area viewport. Gives every
/// renderer a non-trivial mix of revealed (inside the disc) +
/// unrevealed (everywhere else) area to draw.
///
/// The default disc id is stable across calls so two contexts in the
/// same test produce comparable wisp-emergence diff state. Pass a
/// custom [discs] list to override the default fixture.
MirkPaintContext fakeContext({int elapsedMs = 0, List<RevealDisc>? discs, Fix? currentFix, MirkViewportBbox? viewport}) {
  final bbox = viewport ?? MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  return MirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: 1.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: bbox,
    discs: discs ?? <RevealDisc>[singleCentreDisc(bbox: bbox)],
    currentFix: currentFix,
  );
}

/// Single deterministic disc centred inside [bbox] with a 100 m radius —
/// the canonical "something visible to render" fixture. The id is stable
/// (`rvd_test_centre`) so wisp-emergence tests can reason about the
/// previous-id-set diff between paints.
RevealDisc singleCentreDisc({required MirkViewportBbox bbox, double radiusMeters = 100.0}) {
  final centreLat = (bbox.south + bbox.north) * 0.5;
  final centreLon = (bbox.west + bbox.east) * 0.5;
  return RevealDisc(
    id: 'rvd_test_centre',
    sessionId: 'sess_test',
    lat: centreLat,
    lon: centreLon,
    radiusMeters: radiusMeters,
    fixedAtUtc: DateTime.utc(2026, 4, 26),
  );
}

/// Renders a renderer to a `PictureRecorder`-backed `Picture`, then
/// rasterises to a raw RGBA byte buffer for tolerance-aware diffing.
///
/// Returns the byte buffer of size width*height*4. Uses 256×256 by
/// default for the test canvas — small enough that the rasterisation
/// is sub-millisecond yet large enough that two visually-distinct
/// renderer outputs will differ by hundreds of bytes.
Future<Uint8List> renderToBytes(MirkRenderer renderer, {required MirkPaintContext context, Size size = kTestCanvasSize}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  // Establish a transparent white-background canvas so that pixels the
  // renderer doesn't touch are deterministic between runs.
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0x00000000));
  renderer.paint(canvas, size, context);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await image.toByteData();
  picture.dispose();
  image.dispose();
  if (byteData == null) {
    throw StateError('toByteData returned null — image rasterisation failed');
  }
  return byteData.buffer.asUint8List();
}

/// Renders a renderer to a `PictureRecorder` and returns the recorded
/// `Picture` for callers that want lower-level inspection than
/// `renderToBytes` provides. Caller is responsible for `picture.dispose()`.
Picture renderToPicture(MirkRenderer renderer, {required MirkPaintContext context, Size size = kTestCanvasSize}) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  renderer.paint(canvas, size, context);
  return recorder.endRecording();
}

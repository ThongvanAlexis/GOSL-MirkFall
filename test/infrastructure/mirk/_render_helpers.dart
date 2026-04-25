// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Test-internal helpers for the Phase 09 plan 09-04 renderer suites.
// Underscore-prefixed filename indicates "do not import outside
// test/infrastructure/mirk/" — `flutter analyze` will not complain
// because the file lives under `test/`.

import 'dart:typed_data';
import 'dart:ui';

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

/// Default canvas size for renderer tests — small enough to keep PNG
/// encode time under a few ms, large enough for the visual-distinctness
/// byte-diff assertion to discriminate.
const Size kTestCanvasSize = Size(256, 256);

/// Constructs a 512-byte bitmap (64×64 cells, 1 bit each) in a known
/// "half revealed" pattern: the top-left 32×32 quadrant is fully
/// revealed (bit=1), the rest is unrevealed (bit=0). Gives every
/// renderer a non-trivial mix of revealed + unrevealed cells to draw.
Uint8List makeHalfRevealedBitmap() {
  final bytes = Uint8List(512); // 64*64/8
  for (var j = 0; j < 32; j++) {
    for (var i = 0; i < 32; i++) {
      final bitIndex = j * 64 + i;
      final byteIndex = bitIndex >> 3;
      final bitOffset = bitIndex & 7;
      bytes[byteIndex] |= 1 << bitOffset;
    }
  }
  return bytes;
}

/// Constructs a 512-byte bitmap with all bits set to 0 (fully unrevealed).
Uint8List makeAllUnrevealedBitmap() => Uint8List(512);

/// Constructs a 512-byte bitmap with all bits set to 1 (fully revealed).
Uint8List makeAllRevealedBitmap() {
  final bytes = Uint8List(512);
  for (var i = 0; i < 512; i++) {
    bytes[i] = 0xFF;
  }
  return bytes;
}

/// Builds a realistic [MirkPaintContext] for renderer tests.
///
/// Defaults:
/// * Viewport bbox spans roughly Marseille (43°/44° N, 5°/6° E).
/// * Two visible tiles — one half-revealed top-left quadrant, one
///   fully unrevealed — so renderers have something non-trivial to
///   paint and the visual-distinctness suite has signal.
/// * `sessionElapsed` defaults to 0 ms (override for animation tests).
MirkPaintContext fakeContext({int elapsedMs = 0, List<VisibleMirkTile>? tiles, Fix? currentFix, MirkViewportBbox? viewport}) {
  final bbox = viewport ?? MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  return MirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: 1.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: bbox,
    visibleTiles:
        tiles ??
        <VisibleMirkTile>[
          VisibleMirkTile(
            parentX: 8456,
            parentY: 5959,
            bitmap: makeHalfRevealedBitmap(),
            tileNorthLat: 43.7,
            tileWestLon: 5.3,
            tileSouthLat: 43.5,
            tileEastLon: 5.5,
          ),
          VisibleMirkTile(
            parentX: 8457,
            parentY: 5959,
            bitmap: makeAllUnrevealedBitmap(),
            tileNorthLat: 43.7,
            tileWestLon: 5.5,
            tileSouthLat: 43.5,
            tileEastLon: 5.7,
          ),
        ],
    currentFix: currentFix,
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

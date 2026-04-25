// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 BUG-009 (TIER 2) — structural tests for RevealedSdfBuilder.
//
// Tests cover the SDF's invariants without pixel-by-pixel goldens
// (visual is tuned on real device walks):
//   - Empty input → uniform far-fog SDF.
//   - All-revealed input → mostly inside-revealed (byte < 128).
//   - Mixed input → has both inside-revealed and inside-fog pixels.
//   - SDF dimensions match `kMirkFogSdfResolution`.
//   - Boundary byte (=128 ± a few) appears around revealed-cell edges.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/revealed_sdf_builder.dart';

/// Builds a 512-byte bitmap with all bits set to 1 (every cell revealed).
Uint8List _allRevealedBitmap() {
  final bytes = Uint8List(kRevealedTileBitmapBytes);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = 0xFF;
  }
  return bytes;
}

/// Builds a 512-byte bitmap with the top-left 32×32 quadrant revealed.
/// Same shape as `makeHalfRevealedBitmap` in `_render_helpers.dart` —
/// duplicated locally so the SDF tests stay self-contained.
Uint8List _halfRevealedBitmap() {
  final bytes = Uint8List(kRevealedTileBitmapBytes);
  for (var j = 0; j < 32; j++) {
    for (var i = 0; i < 32; i++) {
      final bitIndex = j * kRevealedTileSubgridSize + i;
      final byteIndex = bitIndex >> 3;
      final bitOffset = bitIndex & 7;
      bytes[byteIndex] |= 1 << bitOffset;
    }
  }
  return bytes;
}

/// Returns the R channel of an SDF image as a flat Uint8List of length n*n.
Future<Uint8List> _readRChannel(ui.Image img) async {
  final byteData = await img.toByteData();
  if (byteData == null) {
    throw StateError('toByteData returned null');
  }
  final rgba = byteData.buffer.asUint8List();
  final n = img.width;
  final r = Uint8List(n * n);
  for (var i = 0; i < n * n; i++) {
    r[i] = rgba[i * 4];
  }
  return r;
}

/// One-tile bbox covering the test viewport exactly. Lat/lon ranges
/// chosen arbitrarily — only the relative geometry matters.
VisibleMirkTile _tileFillingViewport({required Uint8List bitmap}) {
  return VisibleMirkTile(parentX: 100, parentY: 100, bitmap: bitmap, tileNorthLat: 44.0, tileWestLon: 5.0, tileSouthLat: 43.0, tileEastLon: 6.0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RevealedSdfBuilder', () {
    test('resolution matches kMirkFogSdfResolution', () {
      expect(RevealedSdfBuilder.resolution, equals(kMirkFogSdfResolution));
    });

    test('empty visibleTiles → all-byte-255 SDF (uniform far-fog)', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final img = await builder.build(visibleTiles: const [], viewport: viewport);
      expect(img.width, equals(RevealedSdfBuilder.resolution));
      expect(img.height, equals(RevealedSdfBuilder.resolution));
      final r = await _readRChannel(img);
      // Every pixel must be saturated 255 — there is no revealed area
      // anywhere, so distance to "nearest fog" is 0 (we are fog) and
      // "distance to revealed" is unbounded → encoded as max byte.
      for (var i = 0; i < r.length; i++) {
        expect(r[i], equals(255), reason: 'pixel $i should be 255 (far fog) on empty input');
      }
      img.dispose();
    });

    test('degenerate viewport (zero span) → all-byte-255 SDF', () async {
      const builder = RevealedSdfBuilder();
      // South == north, dLat = 0.
      final degenerate = MirkViewportBbox(south: 44.0, west: 5.0, north: 44.0, east: 6.0);
      final tile = _tileFillingViewport(bitmap: _allRevealedBitmap());
      final img = await builder.build(visibleTiles: [tile], viewport: degenerate);
      final r = await _readRChannel(img);
      // Degenerate viewport — the builder shortcuts to the empty SDF.
      expect(r.first, equals(255));
      img.dispose();
    });

    test('all-revealed tile → SDF is mostly inside-revealed (bytes < 128)', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final tile = _tileFillingViewport(bitmap: _allRevealedBitmap());
      final img = await builder.build(visibleTiles: [tile], viewport: viewport);
      final r = await _readRChannel(img);
      var insideCount = 0;
      var outsideCount = 0;
      for (var i = 0; i < r.length; i++) {
        if (r[i] < 128) {
          insideCount++;
        } else if (r[i] > 128) {
          outsideCount++;
        }
      }
      expect(insideCount, greaterThan(outsideCount * 100), reason: 'all-revealed input should produce overwhelmingly inside-revealed (<128) pixels');
      img.dispose();
    });

    test('half-revealed tile (top-left quadrant) → mix of inside + outside', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final tile = _tileFillingViewport(bitmap: _halfRevealedBitmap());
      final img = await builder.build(visibleTiles: [tile], viewport: viewport);
      final r = await _readRChannel(img);
      var insideCount = 0;
      var outsideCount = 0;
      var nearBoundaryCount = 0;
      for (var i = 0; i < r.length; i++) {
        if (r[i] < 128) {
          insideCount++;
        } else if (r[i] > 128) {
          outsideCount++;
        }
        if ((r[i] - 128).abs() <= 6) {
          nearBoundaryCount++;
        }
      }
      // Half-revealed input: top-left quadrant is revealed, rest is fog.
      // We expect both sides to be present and a non-trivial number of
      // pixels near the boundary band.
      expect(insideCount, greaterThan(0), reason: 'half-revealed input must have inside-revealed pixels');
      expect(outsideCount, greaterThan(0), reason: 'half-revealed input must have inside-fog pixels');
      expect(nearBoundaryCount, greaterThan(0), reason: 'a boundary band (|byte - 128| <= 6) must exist between revealed and fog');
      img.dispose();
    });

    test('top-left revealed quadrant maps to top-left of the SDF', () async {
      // Verifies that the projection convention is correct: viewport
      // north → low Y row, viewport west → low X column. The
      // top-left 32×32 cell quadrant of the tile corresponds to the
      // top-left quarter of the SDF.
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final tile = _tileFillingViewport(bitmap: _halfRevealedBitmap());
      final img = await builder.build(visibleTiles: [tile], viewport: viewport);
      final r = await _readRChannel(img);
      final n = img.width;
      // Sample a pixel deep in the top-left quadrant — should be
      // inside-revealed (byte < 128).
      final tlIdx = (n ~/ 8) * n + (n ~/ 8);
      // Sample a pixel deep in the bottom-right quadrant — should be
      // inside-fog (byte > 128).
      final brIdx = (n - n ~/ 8) * n + (n - n ~/ 8);
      expect(r[tlIdx], lessThan(128), reason: 'top-left of SDF should be inside-revealed (the half-revealed quadrant projects there)');
      expect(r[brIdx], greaterThan(128), reason: 'bottom-right of SDF should be inside-fog');
      img.dispose();
    });
  });
}

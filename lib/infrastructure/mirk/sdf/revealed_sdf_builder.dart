// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async' show Completer;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

final Logger _log = Logger('infrastructure.mirk.sdf');

/// Builds a CPU-side signed distance field (SDF) of the revealed area
/// for a given viewport, encoded as a `ui.Image` ready to be passed to
/// the fog shader as `sampler2D`.
///
/// Phase 09 BUG-009 (TIER 2). The SDF lets the shader's two-stop
/// watercolour boundary, curl-rotated edge field, and density-modulation
/// near the boundary react to the actual revealed silhouette — without
/// the renderer having to recompute geometry on the GPU.
///
/// ## Sign convention
///
/// The SDF is stored in the R channel as an unsigned byte, but encodes
/// a SIGNED distance via a midpoint-128 convention:
///
///   - Byte value `128` → distance 0 (on the boundary).
///   - Bytes `0..127` → INSIDE the revealed area (clear), with `0`
///     being the deepest interior.
///   - Bytes `129..255` → INSIDE the fog area (unrevealed), with `255`
///     being the farthest fog.
///
/// The shader reads `texture(uSdf, uv).r * 2.0 - 1.0` to recover a
/// signed distance in [-1, 1].
///
/// ## Resolution
///
/// 256×256 (configurable via [kMirkFogSdfResolution]). The resolution
/// is independent of the viewport pixel size — the shader samples with
/// bilinear filtering, so a 256² SDF over a 1080×1920 viewport still
/// produces smooth distance gradients.
///
/// ## When to rebuild
///
/// The SDF only depends on the union of revealed cell bitmaps + the
/// viewport bbox. The renderer should rebuild it when EITHER changes:
///
///   - The user walks → new cells revealed → bitmap union changes.
///   - The user pans/zooms → viewport bbox changes → projection of the
///     same cells onto the SDF plane shifts.
///
/// Rebuilding every frame is wasted work because GPS fixes arrive at
/// most once per second, and viewport changes are throttled. The
/// renderer should hash both inputs and reuse the cached `ui.Image` if
/// the hash matches.
///
/// ## Algorithm
///
/// Naïve brute-force: for every output pixel, find the nearest cell of
/// the opposite type (revealed if pixel is fog, fog if pixel is
/// revealed). For 256² output × ~50 visible tiles × 4096 cells/tile,
/// the brute-force is ~13 G ops — too slow.
///
/// Instead: rasterise the revealed-cell bitmap into an N×N seed grid
/// (one byte per output pixel marking inside/outside), then run a
/// two-pass distance transform (Saito-Toriwaki / approximated by jump
/// flood). The jump-flood with `log2(N)` iterations is `O(N² log N)`
/// in pixel work — fast enough that even a worst-case rebuild
/// completes in well under one frame.
///
/// For Stage 3 (this commit) we use a simpler chamfer 3x3 pass which
/// is `O(N²)` and produces visually adequate distances for the
/// shader's purposes (the shader only cares about distances within the
/// boundary band, where chamfer error is below pixel resolution
/// anyway). Jump-flood is a future optimisation if profiling shows
/// chamfer overhead in the hot path.
class RevealedSdfBuilder {
  /// Constructs a builder. Stateless — exists only as a class so tests
  /// can mock it via constructor injection in the renderer (Phase 09
  /// dependency-injection convention).
  const RevealedSdfBuilder();

  /// Resolution of the produced SDF image (square). Cached as a
  /// constant so callers can size their cache keys without recomputing.
  static const int resolution = kMirkFogSdfResolution;

  /// Builds an SDF `ui.Image` from the union of revealed cells across
  /// [visibleTiles], spanning [viewport].
  ///
  /// Empty [visibleTiles] returns an all-fog SDF (every pixel = 255 =
  /// max fog distance), which produces a uniform-fog rendering when
  /// fed to the shader (no boundary effects).
  ///
  /// Returns a `ui.Image` of size [resolution]×[resolution] in RGBA8888
  /// format. The R channel encodes the signed distance per the
  /// midpoint-128 convention; G/B/A are filled with the same byte
  /// (cheap, matches the noise-texture format, helps debug viewers).
  Future<ui.Image> build({required Iterable<VisibleMirkTile> visibleTiles, required MirkViewportBbox viewport}) async {
    final tileList = visibleTiles.toList(growable: false);
    final stopwatch = Stopwatch()..start();
    _log.fine(
      'build(): start — ${tileList.length} visible tiles · viewport=[${viewport.south.toStringAsFixed(4)}, ${viewport.west.toStringAsFixed(4)} → ${viewport.north.toStringAsFixed(4)}, ${viewport.east.toStringAsFixed(4)}]',
    );
    final n = resolution;
    // Step 1: build an in/out seed grid. `seed[idx] = 1` if the
    // corresponding output pixel falls inside a revealed cell, `0`
    // otherwise. Uint8List default-init to 0.
    final seed = Uint8List(n * n);

    // Iterate every revealed cell and mark its projection on the seed
    // grid. The seed grid maps to the viewport in lat/lon: the WHOLE
    // viewport rectangle is `[0..n) × [0..n)`. Cells outside the
    // viewport are skipped.
    final dLat = viewport.north - viewport.south;
    final dLon = viewport.east - viewport.west;
    if (dLat == 0 || dLon == 0) {
      // Degenerate viewport — return all-fog SDF.
      _log.warning('build(): degenerate viewport (dLat=$dLat dLon=$dLon) → returning all-fog SDF');
      return _emptySdfImage();
    }

    for (final tile in tileList) {
      _markTileInSeed(seed, tile: tile, viewport: viewport, dLat: dLat, dLon: dLon, n: n);
    }
    var seedSetCount = 0;
    for (var i = 0; i < seed.length; i++) {
      if (seed[i] != 0) seedSetCount++;
    }
    _log.fine(
      'build(): seed grid filled — $seedSetCount / ${seed.length} pixels marked revealed (${(100.0 * seedSetCount / seed.length).toStringAsFixed(1)}%)',
    );

    // Step 2: chamfer two-pass distance transform. Output `dist[i]` =
    // signed distance (in pixels) from cell i to the nearest opposite
    // type cell.
    final signedDistPixels = _chamferSignedDistance(seed, n);

    // Step 3: encode signed distance in [-distMax, distMax] → byte
    // [0, 255] via midpoint-128. distMax = n * 0.5 (half the SDF
    // resolution — the maximum useful range; further is uniform fog).
    final distMax = n * 0.5;
    final pixels = Uint8List(n * n * 4);
    for (var i = 0; i < n * n; i++) {
      final d = signedDistPixels[i].clamp(-distMax, distMax);
      // Map [-distMax, +distMax] → [0, 255] linearly with 128 = zero.
      final byte = (128.0 + (d / distMax) * 127.0).clamp(0.0, 255.0).toInt();
      final idx = i * 4;
      pixels[idx] = byte;
      pixels[idx + 1] = byte;
      pixels[idx + 2] = byte;
      pixels[idx + 3] = 255;
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, n, n, ui.PixelFormat.rgba8888, completer.complete);
    final image = await completer.future;
    _log.fine('build(): done in ${stopwatch.elapsedMilliseconds}ms — ui.Image ${image.width}x${image.height}');
    return image;
  }

  /// Builds an SDF `ui.Image` directly from a list of [RevealDisc]s — the
  /// continuous-geometry replacement for the chamfer/bitmap path used by
  /// [build]. The returned image follows the SAME byte encoding as [build]
  /// (R-channel, midpoint-128, distance scaled to `[0..255]` via
  /// `distMaxPixels = resolution * 0.5`) so the consuming shader needs no
  /// change.
  ///
  /// Algorithm (analytic, no chamfer):
  ///
  ///   1. Empty `discs` → return all-fog SDF (`_emptySdfImage()`).
  ///   2. For each disc whose extent intersects [viewport]:
  ///       a. Project its centre to seed-grid coordinates.
  ///       b. Convert its `radiusMeters` to seed-grid pixels via the
  ///          viewport's average `metresPerPixel` (geometric mean of the
  ///          lat- and lon-direction conversion factors at viewport-mean
  ///          latitude).
  ///       c. Iterate the padded bounding box `[cx ± (rPx + distMaxPixels)]`
  ///          and update `signed[i] = min(signed[i], pixelDistance - rPx)`.
  ///   3. Encode `signed` to bytes using the same midpoint-128 mapping as
  ///      [build].
  ///
  /// Cost: per disc ≈ `(2·(rPx + distMaxPixels))²` pixel updates. For
  /// typical viewport scales (city-wide to building-scale), `rPx` is a few
  /// pixels and `distMaxPixels = 128`, so ~67 k updates per disc. A 4-hour
  /// session post-compaction holds < 1 k discs in viewport → ~67 M ops,
  /// well under 16 ms on Flutter's 2026 hardware. A spatial index would
  /// help for very large sessions; tagged in a TODO below for follow-up.
  ///
  /// [discs] iteration order does not affect the output (commutative `min`).
  // TODO(perf): for sessions with > a few thousand viewport-resident discs,
  // index discs in a uniform grid keyed by seed-grid pixel and only update
  // pixels in cells the disc actually touches. The current padded-bbox loop
  // is already cheap enough for the 4-hour-session budget but will dominate
  // once compaction is loosened or sessions span hours.
  Future<ui.Image> buildFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport}) async {
    final discList = discs.toList(growable: false);
    final stopwatch = Stopwatch()..start();
    _log.fine(
      'buildFromDiscs(): start — ${discList.length} discs · viewport=[${viewport.south.toStringAsFixed(4)}, ${viewport.west.toStringAsFixed(4)} → ${viewport.north.toStringAsFixed(4)}, ${viewport.east.toStringAsFixed(4)}]',
    );
    if (discList.isEmpty) {
      _log.fine('buildFromDiscs(): empty disc list → all-fog SDF');
      return _emptySdfImage();
    }
    final n = resolution;
    final dLat = viewport.north - viewport.south;
    final dLon = viewport.east - viewport.west;
    if (dLat == 0 || dLon == 0) {
      _log.warning('buildFromDiscs(): degenerate viewport (dLat=$dLat dLon=$dLon) → all-fog SDF');
      return _emptySdfImage();
    }

    // Metres-per-pixel along each axis at the viewport's mean latitude.
    // Using the mean latitude (not the disc's own latitude) keeps the
    // metres-to-pixel mapping consistent across all discs in this build —
    // the SDF is rendered in viewport-normalised pixel space, so the
    // pixel cost of a metre is a property of the viewport, not the disc.
    final meanLatRad = (viewport.south + viewport.north) * 0.5 * math.pi / 180.0;
    final metersPerDegreeLon = kMetersPerDegreeLat * math.cos(meanLatRad);
    final metersPerPixelY = (dLat * kMetersPerDegreeLat) / n;
    final metersPerPixelX = (dLon * metersPerDegreeLon) / n;
    // Geometric mean: preserves disc area at the cost of a small
    // aspect-ratio compromise far from the equator. At MirkFall's
    // city-scale viewports (dLat ≪ 1°) the two axes agree to within a
    // fraction of a percent at any latitude north of the polar clamp.
    final metersPerPixel = math.sqrt(metersPerPixelX * metersPerPixelY);

    final distMaxPixels = n * 0.5;
    // Far-init to 1e9 so the first disc whose padded bbox touches a pixel
    // always wins the `min`. After the loop, any pixel still at 1e9 means
    // no disc reached it → encoded as max-fog (byte = 255).
    final signed = Float32List(n * n);
    for (var i = 0; i < n * n; i++) {
      signed[i] = 1e9;
    }

    var intersectingDiscCount = 0;
    for (final disc in discList) {
      if (!disc.intersectsBbox(viewport)) continue;
      intersectingDiscCount++;

      // Project disc centre to seed-grid pixel coordinates. North → row 0.
      final cx = (disc.lon - viewport.west) / dLon * n;
      final cy = (viewport.north - disc.lat) / dLat * n;
      final rPx = disc.radiusMeters / metersPerPixel;

      final padded = rPx + distMaxPixels;
      final xMin = math.max(0, (cx - padded).floor());
      final xMax = math.min(n, (cx + padded).ceil());
      final yMin = math.max(0, (cy - padded).floor());
      final yMax = math.min(n, (cy + padded).ceil());
      if (xMin >= xMax || yMin >= yMax) continue;

      for (var y = yMin; y < yMax; y++) {
        // Pixel-centre sampling.
        final dy = (y + 0.5) - cy;
        final rowOffset = y * n;
        for (var x = xMin; x < xMax; x++) {
          final dx = (x + 0.5) - cx;
          final pixelDistance = math.sqrt(dx * dx + dy * dy);
          final candidate = pixelDistance - rPx;
          if (candidate < signed[rowOffset + x]) {
            signed[rowOffset + x] = candidate;
          }
        }
      }
    }

    // Encode to bytes: same midpoint-128 mapping as `build`.
    final pixels = Uint8List(n * n * 4);
    var insideCount = 0;
    for (var i = 0; i < n * n; i++) {
      final clamped = signed[i].clamp(-distMaxPixels, distMaxPixels);
      final byte = (128.0 + (clamped / distMaxPixels) * 127.0).clamp(0.0, 255.0).toInt();
      if (signed[i] < 0) insideCount++;
      final idx = i * 4;
      pixels[idx] = byte;
      pixels[idx + 1] = byte;
      pixels[idx + 2] = byte;
      pixels[idx + 3] = 255;
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, n, n, ui.PixelFormat.rgba8888, completer.complete);
    final image = await completer.future;
    final insidePct = (100.0 * insideCount / (n * n)).toStringAsFixed(1);
    _log.fine(
      'buildFromDiscs(): done in ${stopwatch.elapsedMilliseconds}ms — '
      '${discList.length} discs · $intersectingDiscCount intersected · '
      'inside=$insidePct% · ui.Image ${image.width}x${image.height}',
    );
    return image;
  }

  /// Returns an all-fog SDF (every byte = 255). Used for empty inputs
  /// + degenerate viewports — the shader then renders uniform fog
  /// without boundary effects.
  Future<ui.Image> _emptySdfImage() {
    final n = resolution;
    final pixels = Uint8List(n * n * 4);
    // Saturated R/G/B encodes "max fog distance"; alpha = 255 keeps the
    // texture opaque so the shader's sampler reads it cleanly.
    for (var i = 0; i < n * n; i++) {
      final idx = i * 4;
      pixels[idx] = 255;
      pixels[idx + 1] = 255;
      pixels[idx + 2] = 255;
      pixels[idx + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, n, n, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Marks every revealed cell of [tile] in the [seed] grid. The seed
  /// is in viewport-normalised space — the full viewport rect maps to
  /// `[0..n) × [0..n)`.
  void _markTileInSeed(
    Uint8List seed, {
    required VisibleMirkTile tile,
    required MirkViewportBbox viewport,
    required double dLat,
    required double dLon,
    required int n,
  }) {
    final cellLatSpan = (tile.tileNorthLat - tile.tileSouthLat) / kRevealedTileSubgridSize;
    final cellLonSpan = (tile.tileEastLon - tile.tileWestLon) / kRevealedTileSubgridSize;
    // BUG-009 follow-up diagnostic counters (2026-04-25): track how
    // many revealed cells of THIS tile actually projected within the
    // seed grid (vs were clipped because their lat/lon fell outside
    // the viewport bbox). Tells us whether the bits exist on the tile
    // but the projection geometry rejects them — separate failure mode
    // from "no bits exist".
    var revealedCellCount = 0;
    var markedCellCount = 0;
    var skippedOffGridCount = 0;
    for (var j = 0; j < kRevealedTileSubgridSize; j++) {
      final cellNorthLat = tile.tileNorthLat - j * cellLatSpan;
      final cellSouthLat = cellNorthLat - cellLatSpan;
      for (var i = 0; i < kRevealedTileSubgridSize; i++) {
        final bitIndex = j * kRevealedTileSubgridSize + i;
        final byteIndex = bitIndex >> 3;
        final bitOffset = bitIndex & 7;
        final bit = (tile.bitmap[byteIndex] >> bitOffset) & 1;
        if (bit == 0) continue; // Cell is unrevealed → stays as fog (seed=0).
        revealedCellCount++;
        final cellWestLon = tile.tileWestLon + i * cellLonSpan;
        final cellEastLon = cellWestLon + cellLonSpan;
        // Project cell rect to the seed grid. Anything outside the
        // viewport [0, n) is clipped naturally by the loop bounds.
        final px0 = ((cellWestLon - viewport.west) / dLon * n).floor();
        final px1 = ((cellEastLon - viewport.west) / dLon * n).ceil();
        // Y axis: viewport.north → row 0, viewport.south → row n.
        // Cell north (larger lat) corresponds to smaller row index.
        final py0 = ((viewport.north - cellNorthLat) / dLat * n).floor();
        final py1 = ((viewport.north - cellSouthLat) / dLat * n).ceil();
        final yMin = py0.clamp(0, n);
        final yMax = py1.clamp(0, n);
        final xMin = px0.clamp(0, n);
        final xMax = px1.clamp(0, n);
        if (xMin >= xMax || yMin >= yMax) {
          skippedOffGridCount++;
          continue;
        }
        markedCellCount++;
        for (var y = yMin; y < yMax; y++) {
          final rowOffset = y * n;
          for (var x = xMin; x < xMax; x++) {
            seed[rowOffset + x] = 1;
          }
        }
      }
    }
    if (revealedCellCount > 0) {
      _log.fine(
        '_markTileInSeed: tile ${tile.parentX}/${tile.parentY} → revealedCells=$revealedCellCount marked=$markedCellCount skippedOffGrid=$skippedOffGridCount',
      );
    }
  }

  /// Two-pass 3x3 chamfer signed distance transform.
  ///
  /// Returns a Float32List of length n*n where each value is the
  /// signed pixel distance to the nearest opposite-type pixel:
  ///   - Negative if the pixel is INSIDE revealed area (seed=1) — the
  ///     deeper inside, the more negative.
  ///   - Positive if OUTSIDE (seed=0) — distance grows with fog depth.
  ///
  /// Algorithm: standard chamfer 3-4 weights. Forward pass sweeps
  /// top-to-bottom, left-to-right; backward pass sweeps in reverse.
  /// Each pass updates `dist[i] = min(dist[i], dist[neighbour] + w)`
  /// where `w` is 3 for orthogonal, 4 for diagonal. For signed
  /// distance we run the chamfer twice — once on the seed (gives
  /// "distance to nearest seed=1") and once on the inverted seed
  /// (gives "distance to nearest seed=0"). The signed result is
  /// `outsideDist - insideDist` — positive in fog, negative in
  /// revealed.
  ///
  /// Cost: O(n²) memory + O(n²) ops × 2 passes × 2 transforms = ~4 ×
  /// 256² ≈ 260 k ops total. Well under 1 ms on any 2026 device.
  Float32List _chamferSignedDistance(Uint8List seed, int n) {
    // Distance from seed=0 cells to nearest seed=1 (i.e. "distance
    // into fog"). Initialise to 0 inside seed=1, large outside.
    final distOut = Float32List(n * n);
    // Distance from seed=1 cells to nearest seed=0 (i.e. "distance
    // into revealed").
    final distIn = Float32List(n * n);
    const farInit = 1e9;
    for (var i = 0; i < n * n; i++) {
      if (seed[i] == 1) {
        distOut[i] = 0;
        distIn[i] = farInit;
      } else {
        distOut[i] = farInit;
        distIn[i] = 0;
      }
    }
    _chamferPass(distOut, n);
    _chamferPass(distIn, n);
    // Combine: signed distance in pixels.
    final signed = Float32List(n * n);
    for (var i = 0; i < n * n; i++) {
      // Chamfer weights are 3-4; divide by 3 to recover unit pixels.
      final out = distOut[i] / 3.0;
      final inv = distIn[i] / 3.0;
      // Pixel is in fog if seed=0: signed = +out (distance to revealed).
      // Pixel is in revealed if seed=1: signed = -inv (distance to fog).
      signed[i] = (seed[i] == 0) ? out : -inv;
    }
    return signed;
  }

  /// Forward + backward 3x3 chamfer pass. In-place mutation of [dist].
  void _chamferPass(Float32List dist, int n) {
    const orth = 3.0;
    const diag = 4.0;
    // Forward pass: top-to-bottom, left-to-right.
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = y * n + x;
        var d = dist[i];
        if (y > 0) {
          if (x > 0) d = _minF(d, dist[(y - 1) * n + (x - 1)] + diag);
          d = _minF(d, dist[(y - 1) * n + x] + orth);
          if (x < n - 1) d = _minF(d, dist[(y - 1) * n + (x + 1)] + diag);
        }
        if (x > 0) d = _minF(d, dist[i - 1] + orth);
        dist[i] = d;
      }
    }
    // Backward pass: bottom-to-top, right-to-left.
    for (var y = n - 1; y >= 0; y--) {
      for (var x = n - 1; x >= 0; x--) {
        final i = y * n + x;
        var d = dist[i];
        if (y < n - 1) {
          if (x < n - 1) d = _minF(d, dist[(y + 1) * n + (x + 1)] + diag);
          d = _minF(d, dist[(y + 1) * n + x] + orth);
          if (x > 0) d = _minF(d, dist[(y + 1) * n + (x - 1)] + diag);
        }
        if (x < n - 1) d = _minF(d, dist[i + 1] + orth);
        dist[i] = d;
      }
    }
  }

  /// Inline-able min for tight loops. The standard library `math.min`
  /// adds a function call overhead that is not negligible at 65k×8 =
  /// ~520k invocations. Hand-inline.
  double _minF(double a, double b) => a < b ? a : b;
}

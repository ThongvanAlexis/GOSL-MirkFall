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
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

final Logger _log = Logger('infrastructure.mirk.sdf');

/// Result of a [RevealedSdfBuilder.buildFromDiscs] invocation: the SDF
/// image and the geographic bounding box it was built for.
///
/// BUG-014 iteration 4: the SDF is now built in DISC-BBOX coordinates
/// (the bounding box of all input discs + padding), NOT viewport
/// coordinates. The renderer uses [bbox] to compute the screen-to-SDF
/// UV mapping every frame — a trivial 4-division operation that tracks
/// the camera in real time without rebuilding the texture.
class SdfBuildResult {
  /// The SDF image (R-channel, midpoint-128 signed distance).
  final ui.Image image;

  /// The geographic bounding box the SDF was normalised to. The image's
  /// pixel (0, 0) maps to (bbox.north, bbox.west) and pixel (n-1, n-1)
  /// maps to (bbox.south, bbox.east).
  final MirkViewportBbox bbox;

  const SdfBuildResult({required this.image, required this.bbox});
}

/// Builds a CPU-side signed distance field (SDF) of the revealed area
/// in DISC-BBOX coordinates, encoded as a `ui.Image` ready to be passed
/// to the fog shader as `sampler2D`.
///
/// Phase 09 BUG-009 (TIER 2). The SDF lets the shader's two-stop
/// watercolour boundary, curl-rotated edge field, and density-modulation
/// near the boundary react to the actual revealed silhouette — without
/// the renderer having to recompute geometry on the GPU.
///
/// Phase 09 BUG-010 Option B Commit 5 collapsed the builder to the
/// continuous-geometry path. Reveals are now exclusively a list of
/// [RevealDisc]s; the cell-bitmap chamfer path (and its `_markTileInSeed` /
/// `_chamferSignedDistance` helpers) are gone.
///
/// Phase 09 BUG-014 iteration 4: the SDF is now built in a fixed
/// "disc bbox" coordinate space — the bounding box of all input discs,
/// padded by [kSdfBboxPaddingMeters]. The shader maps from screen UV to
/// SDF UV every fragment via a per-frame affine transform (the 4 sdfRect
/// uniforms). This means the SDF only rebuilds when the DISC LIST
/// changes (new GPS fix), NOT when the viewport changes (pan/zoom).
/// Camera movement changes the UV mapping, not the fog texture.
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
/// The SDF only depends on the union of revealed discs. The renderer
/// should rebuild it when the DISC LIST changes:
///
///   - The user walks → new disc fixed_at → disc list changes.
///   - The user pans/zooms → viewport bbox changes → NO REBUILD needed.
///     The renderer recomputes the screen-to-SDF UV mapping every frame.
class RevealedSdfBuilder {
  /// Constructs a builder. Stateless — exists only as a class so tests
  /// can mock it via constructor injection in the renderer (Phase 09
  /// dependency-injection convention).
  const RevealedSdfBuilder();

  /// Resolution of the produced SDF image (square). Cached as a
  /// constant so callers can size their cache keys without recomputing.
  static const int resolution = kMirkFogSdfResolution;

  /// Padding in metres added to all sides of the disc bounding box.
  /// Ensures the SDF covers the watercolour bleed band beyond the
  /// outermost disc edge. 500 m is generous — the bleed band at typical
  /// zoom levels is < 100 m in world coordinates.
  static const double kSdfBboxPaddingMeters = 500.0;

  /// Builds an SDF [SdfBuildResult] from a list of [RevealDisc]s.
  ///
  /// BUG-014 iteration 4: the SDF is normalised to the DISC BBOX
  /// (bounding box of all input discs + [kSdfBboxPaddingMeters] padding),
  /// not the viewport. The returned [SdfBuildResult.bbox] tells the
  /// renderer what geographic region the SDF covers so it can compute
  /// the screen-to-SDF UV mapping every frame.
  ///
  /// The [viewport] parameter is retained for the empty-discs / no-disc
  /// fallback (all-fog SDF needs a bbox to return).
  ///
  /// Algorithm (analytic, no chamfer):
  ///
  ///   1. Empty `discs` → return all-fog SDF with [viewport] as bbox.
  ///   2. Compute disc bbox: bounding box of all disc centres ± radius,
  ///      padded by [kSdfBboxPaddingMeters].
  ///   3. For each disc:
  ///       a. Project its centre to SDF-grid coordinates (normalised to
  ///          the disc bbox, not the viewport).
  ///       b. Compute distance in METRES and encode as before.
  ///   4. Encode `signed` to bytes using the midpoint-128 mapping.
  ///
  /// [discs] iteration order does not affect the output (commutative `min`).
  Future<SdfBuildResult> buildFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport}) async {
    final discList = discs.toList(growable: false);
    final stopwatch = Stopwatch()..start();
    _log.fine('buildFromDiscs(): start — ${discList.length} discs');
    if (discList.isEmpty) {
      _log.fine('buildFromDiscs(): empty disc list → all-fog SDF');
      final image = await _emptySdfImage();
      return SdfBuildResult(image: image, bbox: viewport);
    }

    // Compute disc bbox: geographic bounding box of all discs + padding.
    final discBbox = _computeDiscBbox(discList);
    final dLat = discBbox.north - discBbox.south;
    final dLon = discBbox.east - discBbox.west;
    if (dLat <= 0 || dLon <= 0) {
      _log.warning('buildFromDiscs(): degenerate disc bbox (dLat=$dLat dLon=$dLon) → all-fog SDF');
      final image = await _emptySdfImage();
      return SdfBuildResult(image: image, bbox: discBbox);
    }

    final n = resolution;

    // Metres-per-pixel along each axis at the disc bbox's mean latitude.
    final meanLatRad = (discBbox.south + discBbox.north) * 0.5 * math.pi / 180.0;
    final metersPerDegreeLon = kMetersPerDegreeLat * math.cos(meanLatRad);
    final metersPerPixelY = (dLat * kMetersPerDegreeLat) / n;
    final metersPerPixelX = (dLon * metersPerDegreeLon) / n;
    // Geometric mean: preserves disc area at the cost of a small
    // aspect-ratio compromise far from the equator.
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
      // All discs are within the disc bbox by construction, but skip any
      // that somehow fall outside (degenerate input).
      if (!disc.intersectsBbox(discBbox)) continue;
      intersectingDiscCount++;

      // Project disc centre to SDF-grid pixel coordinates. North → row 0.
      final cx = (disc.lon - discBbox.west) / dLon * n;
      final cy = (discBbox.north - disc.lat) / dLat * n;
      // Anisotropic padding: at non-equatorial latitudes, one pixel of
      // latitude covers more metres than one pixel of longitude (by
      // 1/cos(lat)). The padded bbox must account for this difference.
      final paddedMeters = disc.radiusMeters + distMaxPixels * metersPerPixel;
      final xPadPixels = paddedMeters / metersPerPixelX;
      final yPadPixels = paddedMeters / metersPerPixelY;
      final xMin = math.max(0, (cx - xPadPixels).floor());
      final xMax = math.min(n, (cx + xPadPixels).ceil());
      final yMin = math.max(0, (cy - yPadPixels).floor());
      final yMax = math.min(n, (cy + yPadPixels).ceil());
      if (xMin >= xMax || yMin >= yMax) continue;

      for (var y = yMin; y < yMax; y++) {
        // Pixel-centre sampling — distance computed in METRES, not pixels.
        final dy = (y + 0.5) - cy;
        final dyMeters = dy * metersPerPixelY;
        final rowOffset = y * n;
        for (var x = xMin; x < xMax; x++) {
          final dx = (x + 0.5) - cx;
          final dxMeters = dx * metersPerPixelX;
          final distMeters = math.sqrt(dxMeters * dxMeters + dyMeters * dyMeters);
          // Convert back to pixel-equivalent units (geometric-mean scale)
          // for the encoding step's distMaxPixels normalisation.
          final candidate = (distMeters - disc.radiusMeters) / metersPerPixel;
          if (candidate < signed[rowOffset + x]) {
            signed[rowOffset + x] = candidate;
          }
        }
      }
    }

    // Encode to bytes: same midpoint-128 mapping as the legacy path.
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
      'inside=$insidePct% · ui.Image ${image.width}x${image.height} · '
      'discBbox=[${discBbox.south.toStringAsFixed(4)}, ${discBbox.west.toStringAsFixed(4)} → ${discBbox.north.toStringAsFixed(4)}, ${discBbox.east.toStringAsFixed(4)}]',
    );
    return SdfBuildResult(image: image, bbox: discBbox);
  }

  /// Computes the geographic bounding box of all discs, padded by
  /// [kSdfBboxPaddingMeters] on all sides. Each disc's extent is its
  /// centre ± radius converted to degrees.
  MirkViewportBbox _computeDiscBbox(List<RevealDisc> discs) {
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLon = double.infinity;
    var maxLon = double.negativeInfinity;

    for (final disc in discs) {
      final latDegPerMeter = 1.0 / kMetersPerDegreeLat;
      final clampedLatRad = disc.lat.abs() < 85.0 ? disc.lat * math.pi / 180.0 : (disc.lat > 0 ? 85.0 : -85.0) * math.pi / 180.0;
      final lonDegPerMeter = 1.0 / (kMetersPerDegreeLat * math.cos(clampedLatRad));

      final discMinLat = disc.lat - disc.radiusMeters * latDegPerMeter;
      final discMaxLat = disc.lat + disc.radiusMeters * latDegPerMeter;
      final discMinLon = disc.lon - disc.radiusMeters * lonDegPerMeter;
      final discMaxLon = disc.lon + disc.radiusMeters * lonDegPerMeter;

      if (discMinLat < minLat) minLat = discMinLat;
      if (discMaxLat > maxLat) maxLat = discMaxLat;
      if (discMinLon < minLon) minLon = discMinLon;
      if (discMaxLon > maxLon) maxLon = discMaxLon;
    }

    // Add padding in metres, converted to degrees at the mean latitude.
    final meanLat = (minLat + maxLat) * 0.5;
    final latDegPerMeter = 1.0 / kMetersPerDegreeLat;
    final clampedMeanLatRad = meanLat.abs() < 85.0 ? meanLat * math.pi / 180.0 : (meanLat > 0 ? 85.0 : -85.0) * math.pi / 180.0;
    final lonDegPerMeter = 1.0 / (kMetersPerDegreeLat * math.cos(clampedMeanLatRad));
    final latPaddingDeg = kSdfBboxPaddingMeters * latDegPerMeter;
    final lonPaddingDeg = kSdfBboxPaddingMeters * lonDegPerMeter;

    final south = (minLat - latPaddingDeg).clamp(-90.0, 90.0);
    final north = (maxLat + latPaddingDeg).clamp(-90.0, 90.0);
    final west = minLon - lonPaddingDeg;
    final east = maxLon + lonPaddingDeg;

    return MirkViewportBbox(south: south, west: west, north: north, east: east);
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
}

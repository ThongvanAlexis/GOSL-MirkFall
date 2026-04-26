// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 BUG-009 (TIER 2) + BUG-010 Option B Commit 5 — structural
// tests for [RevealedSdfBuilder]. Pre-Commit-5 the builder also exposed
// a `build(visibleTiles:)` chamfer path; that path was deleted in
// Commit 5, leaving `buildFromDiscs(...)` as the single SDF surface.
//
// Tests cover the SDF's invariants without pixel-by-pixel goldens
// (visual is tuned on real device walks):
//   - Empty input → uniform far-fog SDF.
//   - Degenerate viewport → all-fog SDF.
//   - Single disc → centre revealed, corners fog.
//   - Disc fully outside viewport → all-fog SDF.
//   - Circular silhouette: 8 octagon samples agree within tolerance
//     (the defining BUG-010 regression — analytic disc agreement).
//   - Two adjacent discs: midpoint inside both.
//   - Permutation invariance: byte-identical output across disc orderings.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/revealed_sdf_builder.dart';

/// Returns the R channel of an SDF image as a flat Uint8List of length n*n.
Future<List<int>> _readRChannel(ui.Image img) async {
  final byteData = await img.toByteData();
  if (byteData == null) {
    throw StateError('toByteData returned null');
  }
  final rgba = byteData.buffer.asUint8List();
  final n = img.width;
  final r = List<int>.filled(n * n, 0);
  for (var i = 0; i < n * n; i++) {
    r[i] = rgba[i * 4];
  }
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RevealedSdfBuilder', () {
    test('resolution matches kMirkFogSdfResolution', () {
      expect(RevealedSdfBuilder.resolution, equals(kMirkFogSdfResolution));
    });
  });

  group('buildFromDiscs', () {
    test('empty discs → all-byte-255 SDF (uniform far-fog)', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final img = await builder.buildFromDiscs(discs: const [], viewport: viewport);
      expect(img.width, equals(RevealedSdfBuilder.resolution));
      expect(img.height, equals(RevealedSdfBuilder.resolution));
      final r = await _readRChannel(img);
      // Sample the four corners + the centre — empty input must produce
      // saturated max-fog everywhere.
      final n = img.width;
      final samples = <int>[r[0], r[n - 1], r[(n - 1) * n], r[n * n - 1], r[(n ~/ 2) * n + (n ~/ 2)]];
      for (final s in samples) {
        expect(s, equals(255), reason: 'empty discs → every sampled pixel must be 255 (far fog)');
      }
      img.dispose();
    });

    test('degenerate viewport (zero span) → all-byte-255 SDF', () async {
      const builder = RevealedSdfBuilder();
      final degenerate = MirkViewportBbox(south: 44.0, west: 5.0, north: 44.0, east: 6.0);
      final disc = _disc(id: 'rvd_a', lat: 44.0, lon: 5.5, radiusMeters: 100.0);
      final img = await builder.buildFromDiscs(discs: [disc], viewport: degenerate);
      final r = await _readRChannel(img);
      expect(r.first, equals(255));
      img.dispose();
    });

    test('single disc fully inside viewport → centre revealed, corners fog', () async {
      const builder = RevealedSdfBuilder();
      // Tight 0.01° × 0.01° viewport (~1.1 km on each side). 100 m disc
      // at the centre is well within view but does not reach the corners.
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      final disc = _disc(id: 'rvd_centre', lat: 0.005, lon: 0.005, radiusMeters: 100.0);
      final img = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final r = await _readRChannel(img);
      final n = img.width;
      final centreIdx = (n ~/ 2) * n + (n ~/ 2);
      expect(r[centreIdx], lessThan(128), reason: 'disc centre must encode as inside-revealed (byte < 128)');
      // Corners must remain fog. Sample one pixel inset from each
      // corner to avoid any off-by-one boundary noise.
      const inset = 2;
      final tl = inset * n + inset;
      final tr = inset * n + (n - 1 - inset);
      final bl = (n - 1 - inset) * n + inset;
      final br = (n - 1 - inset) * n + (n - 1 - inset);
      for (final c in <int>[r[tl], r[tr], r[bl], r[br]]) {
        expect(c, greaterThanOrEqualTo(128), reason: 'corner must remain inside-fog (byte >= 128)');
      }
      img.dispose();
    });

    test('disc fully outside viewport → all-fog SDF', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      // Disc centred ~22 km away (10° = ~1100 km, but use a small offset
      // that's far past the viewport extent yet trivially small radius).
      final disc = _disc(id: 'rvd_far', lat: 1.0, lon: 1.0, radiusMeters: 50.0);
      final img = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final r = await _readRChannel(img);
      final n = img.width;
      // Sample several scattered pixels — expect saturated max-fog.
      final samples = <int>[r[0], r[(n ~/ 2) * n + (n ~/ 2)], r[n * n - 1]];
      for (final s in samples) {
        expect(s, equals(255), reason: 'disc outside viewport → all sampled pixels must be 255');
      }
      img.dispose();
    });

    test('circular silhouette: 8 equidistant samples agree within tolerance (BUG-010 regression)', () async {
      // The defining test for BUG-010 Option B: an analytic disc must
      // produce a CIRCULAR silhouette in the SDF. The pre-Option-B path
      // rasterised cells then ran a chamfer transform — corner samples
      // ended up measurably farther from the boundary than axis samples
      // because the chamfer's diagonal weight (4) is only an integer
      // approximation of √2 (≈ 5.66 in the 3-4 weight scheme). With
      // continuous geometry, all eight samples on a centred ring read
      // the same signed distance.
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      final disc = _disc(id: 'rvd_silhouette', lat: 0.005, lon: 0.005, radiusMeters: 200.0);
      final img = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final r = await _readRChannel(img);
      final n = img.width;
      final cx = n / 2.0;
      final cy = n / 2.0;

      // Sample 8 points on an INSIDE ring (well within the disc): all
      // should read as inside-revealed and agree to within ±2 bytes.
      final insideRing = _sampleOctagon(r, cx: cx, cy: cy, radiusPx: 10.0, n: n);
      final insideMin = insideRing.reduce(math.min);
      final insideMax = insideRing.reduce(math.max);
      expect(insideMax - insideMin, lessThanOrEqualTo(2), reason: 'inside-ring 8 samples must agree within ±2 bytes (circular silhouette)');
      for (final s in insideRing) {
        expect(s, lessThan(128), reason: 'inside-ring sample must encode as revealed (byte < 128)');
      }

      // Sample 8 points on an OUTSIDE ring (well past the disc edge):
      // all should read as inside-fog and agree to within ±2 bytes.
      final outsideRing = _sampleOctagon(r, cx: cx, cy: cy, radiusPx: 50.0, n: n);
      final outsideMin = outsideRing.reduce(math.min);
      final outsideMax = outsideRing.reduce(math.max);
      expect(outsideMax - outsideMin, lessThanOrEqualTo(2), reason: 'outside-ring 8 samples must agree within ±2 bytes (symmetric outside band)');
      for (final s in outsideRing) {
        expect(s, greaterThan(128), reason: 'outside-ring sample must encode as fog (byte > 128)');
      }

      img.dispose();
    });

    test('two adjacent discs: midpoint inside, union spans both centres', () async {
      const builder = RevealedSdfBuilder();
      // Two 100 m discs, centres ~50 m apart along longitude. At the
      // viewport's mean latitude (≈ 0°), 1 m ≈ 1/111320° ≈ 8.98e-6°.
      const meterDeg = 1.0 / kMetersPerDegreeLat;
      final lonOffset = 25.0 * meterDeg; // 25 m east/west of midpoint
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      final discA = _disc(id: 'rvd_a', lat: 0.005, lon: 0.005 - lonOffset, radiusMeters: 100.0);
      final discB = _disc(id: 'rvd_b', lat: 0.005, lon: 0.005 + lonOffset, radiusMeters: 100.0);
      final img = await builder.buildFromDiscs(discs: [discA, discB], viewport: viewport);
      final r = await _readRChannel(img);
      final n = img.width;

      // Midpoint must be inside both discs simultaneously.
      final midIdx = (n ~/ 2) * n + (n ~/ 2);
      expect(r[midIdx], lessThan(128), reason: 'midpoint between two overlapping discs must be revealed');

      // Both centres must be inside (project lat/lon to pixel and sample).
      final dLon = viewport.east - viewport.west;
      final dLat = viewport.north - viewport.south;
      int pixelOf(double lat, double lon) {
        final px = ((lon - viewport.west) / dLon * n).floor().clamp(0, n - 1);
        final py = ((viewport.north - lat) / dLat * n).floor().clamp(0, n - 1);
        return py * n + px;
      }

      expect(r[pixelOf(discA.lat, discA.lon)], lessThan(128), reason: 'disc A centre must be revealed');
      expect(r[pixelOf(discB.lat, discB.lon)], lessThan(128), reason: 'disc B centre must be revealed');
      img.dispose();
    });

    test('disc-list permutation invariance: order does not affect bytes', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.02, east: 0.02);
      final discA = _disc(id: 'rvd_a', lat: 0.005, lon: 0.005, radiusMeters: 80.0);
      final discB = _disc(id: 'rvd_b', lat: 0.010, lon: 0.012, radiusMeters: 120.0);
      final discC = _disc(id: 'rvd_c', lat: 0.015, lon: 0.008, radiusMeters: 60.0);

      final img1 = await builder.buildFromDiscs(discs: [discA, discB, discC], viewport: viewport);
      final img2 = await builder.buildFromDiscs(discs: [discC, discA, discB], viewport: viewport);
      final r1 = await _readRChannel(img1);
      final r2 = await _readRChannel(img2);

      // Byte-identical: the algorithm is `min` over discs, which is
      // commutative AND associative, so the encoded output cannot depend
      // on the input ordering.
      expect(r1.length, equals(r2.length));
      for (var i = 0; i < r1.length; i++) {
        if (r1[i] != r2[i]) {
          fail('byte mismatch at index $i: r1=${r1[i]} r2=${r2[i]} (permutation invariance broken)');
        }
      }
      img1.dispose();
      img2.dispose();
    });

    test('metric circle: N-S and E-W boundary at same distance — Paris lat 48° (BUG-011 regression)', () async {
      // At Paris (lat ~48.85°), metersPerPixelY / metersPerPixelX ≈ 1.52.
      // Before BUG-011 fix the reveal was a north-south oval because the
      // inner loop used pixel-space distance. After the fix the boundary
      // must be equidistant in all cardinal directions.
      const builder = RevealedSdfBuilder();
      const parisLat = 48.85;
      const parisLon = 2.35;
      // ~200 m viewport span → disc comfortably inside.
      const halfSpanLat = 0.001; // ~111 m north-south
      const halfSpanLon = 0.0015; // ~99 m east-west at lat 48°
      final viewport = MirkViewportBbox(
        south: parisLat - halfSpanLat,
        west: parisLon - halfSpanLon,
        north: parisLat + halfSpanLat,
        east: parisLon + halfSpanLon,
      );
      final disc = _disc(id: 'rvd_paris', lat: parisLat, lon: parisLon, radiusMeters: 30.0);
      final img = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final r = await _readRChannel(img);
      final n = img.width;

      // Disc centre in pixel coordinates.
      final cx = n / 2.0;
      final cy = n / 2.0;

      // Find the boundary pixel (byte closest to 128) in each cardinal
      // direction by scanning outward from the centre.
      int boundaryDistance(int dxStep, int dyStep) {
        for (var step = 0; step < n ~/ 2; step++) {
          final px = (cx + step * dxStep).round().clamp(0, n - 1);
          final py = (cy + step * dyStep).round().clamp(0, n - 1);
          final byte = r[py * n + px];
          // Byte >= 128 means we crossed from inside to outside.
          if (byte >= 128) return step;
        }
        return n ~/ 2;
      }

      final eastDist = boundaryDistance(1, 0);
      final westDist = boundaryDistance(-1, 0);
      final northDist = boundaryDistance(0, -1); // row 0 = north
      final southDist = boundaryDistance(0, 1);

      // East-West average vs North-South average should agree within
      // ±1 pixel — proving the reveal is circular, not oval.
      final ewAvg = (eastDist + westDist) / 2.0;
      final nsAvg = (northDist + southDist) / 2.0;
      final diff = (ewAvg - nsAvg).abs();
      expect(diff, lessThanOrEqualTo(1.0), reason: 'BUG-011: N-S boundary distance ($nsAvg px) must match E-W ($ewAvg px) within ±1 pixel at Paris lat 48°');

      img.dispose();
    });

    test('metric circle: N-S ≈ E-W at extreme latitude 70° (BUG-011 stress)', () async {
      // At lat 70°, cos(70°) ≈ 0.342 → metersPerPixelY / metersPerPixelX ≈ 2.92.
      // This is the most extreme anisotropy the app will encounter. The
      // old pixel-space distance would produce a 3:1 aspect ratio oval.
      const builder = RevealedSdfBuilder();
      const lat70 = 70.0;
      const lon70 = 25.0;
      const halfSpanLat = 0.001;
      const halfSpanLon = 0.003; // wider to keep viewport non-degenerate at high lat
      final viewport = MirkViewportBbox(south: lat70 - halfSpanLat, west: lon70 - halfSpanLon, north: lat70 + halfSpanLat, east: lon70 + halfSpanLon);
      final disc = _disc(id: 'rvd_arctic', lat: lat70, lon: lon70, radiusMeters: 25.0);
      final img = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final r = await _readRChannel(img);
      final n = img.width;

      final cx = n / 2.0;
      final cy = n / 2.0;

      int boundaryDistance(int dxStep, int dyStep) {
        for (var step = 0; step < n ~/ 2; step++) {
          final px = (cx + step * dxStep).round().clamp(0, n - 1);
          final py = (cy + step * dyStep).round().clamp(0, n - 1);
          final byte = r[py * n + px];
          if (byte >= 128) return step;
        }
        return n ~/ 2;
      }

      final eastDist = boundaryDistance(1, 0);
      final westDist = boundaryDistance(-1, 0);
      final northDist = boundaryDistance(0, -1);
      final southDist = boundaryDistance(0, 1);

      final ewAvg = (eastDist + westDist) / 2.0;
      final nsAvg = (northDist + southDist) / 2.0;
      final diff = (ewAvg - nsAvg).abs();
      expect(diff, lessThanOrEqualTo(1.0), reason: 'BUG-011: N-S boundary distance ($nsAvg px) must match E-W ($ewAvg px) within ±1 pixel at extreme lat 70°');

      img.dispose();
    });
  });
}

/// Builds a disc fixture with default sessionId / fixedAtUtc.
RevealDisc _disc({required String id, required double lat, required double lon, required double radiusMeters}) {
  return RevealDisc(id: id, sessionId: 'ses_test', lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: DateTime.utc(2026, 4, 26));
}

/// Samples 8 points on a circle of [radiusPx] around `(cx, cy)` (in
/// seed-grid pixel coordinates) and returns their R-channel bytes.
/// The 8 points are at 0°, 45°, 90°, …, 315° — covering both axis and
/// diagonal directions, which is what BUG-010 needed to disagree on
/// before the rewrite.
List<int> _sampleOctagon(List<int> r, {required double cx, required double cy, required double radiusPx, required int n}) {
  final samples = <int>[];
  for (var k = 0; k < 8; k++) {
    final theta = k * math.pi / 4.0;
    final x = (cx + radiusPx * math.cos(theta)).round().clamp(0, n - 1);
    final y = (cy + radiusPx * math.sin(theta)).round().clamp(0, n - 1);
    samples.add(r[y * n + x]);
  }
  return samples;
}

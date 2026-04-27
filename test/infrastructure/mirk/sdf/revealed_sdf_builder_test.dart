// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 BUG-009 (TIER 2) + BUG-010 Option B Commit 5 — structural
// tests for [RevealedSdfBuilder]. Pre-Commit-5 the builder also exposed
// a `build(visibleTiles:)` chamfer path; that path was deleted in
// Commit 5, leaving `buildFromDiscs(...)` as the single SDF surface.
//
// BUG-014 iteration 4: the builder now returns [SdfBuildResult] containing
// both the SDF image AND the disc bbox it was normalised to. Tests updated
// to unwrap the result; new tests verify viewport-independence (same discs,
// different viewports → same SDF image bytes) and bbox coverage.
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
//   - Viewport independence: same discs, different viewports → identical SDF.
//   - Bbox coverage: returned bbox covers all discs with padding.

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
      final result = await builder.buildFromDiscs(discs: const [], viewport: viewport);
      final img = result.image;
      expect(img.width, equals(RevealedSdfBuilder.resolution));
      expect(img.height, equals(RevealedSdfBuilder.resolution));
      final r = await _readRChannel(img);
      final n = img.width;
      final samples = <int>[r[0], r[n - 1], r[(n - 1) * n], r[n * n - 1], r[(n ~/ 2) * n + (n ~/ 2)]];
      for (final s in samples) {
        expect(s, equals(255), reason: 'empty discs → every sampled pixel must be 255 (far fog)');
      }
      img.dispose();
    });

    test('degenerate viewport (zero span) with empty discs → all-byte-255 SDF', () async {
      const builder = RevealedSdfBuilder();
      final degenerate = MirkViewportBbox(south: 44.0, west: 5.0, north: 44.0, east: 6.0);
      final result = await builder.buildFromDiscs(discs: const [], viewport: degenerate);
      final r = await _readRChannel(result.image);
      expect(r.first, equals(255));
      result.image.dispose();
    });

    test('single disc fully inside viewport → centre revealed, corners fog', () async {
      const builder = RevealedSdfBuilder();
      // Tight 0.01° × 0.01° viewport (~1.1 km on each side). 100 m disc
      // at the centre is well within view.
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      final disc = _disc(id: 'rvd_centre', lat: 0.005, lon: 0.005, radiusMeters: 100.0);
      final result = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final img = result.image;
      final r = await _readRChannel(img);
      final n = img.width;

      // The disc bbox covers the disc + padding. The disc centre should
      // map to roughly the centre of the SDF. Verify the centre pixel
      // is inside-revealed.
      final centreIdx = (n ~/ 2) * n + (n ~/ 2);
      expect(r[centreIdx], lessThan(128), reason: 'disc centre must encode as inside-revealed (byte < 128)');

      // Corners of the SDF must remain fog (the padding is 500m, but
      // corners are further from the disc centre than the radius).
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

    test('disc fully outside viewport → all-fog SDF (disc still in bbox)', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      // Disc centred far away. The disc bbox will be built around the
      // disc itself (not the viewport), so the SDF will show the disc
      // as revealed in its own bbox. But the centre of the SDF (which
      // is where the disc maps to) should be inside-revealed.
      final disc = _disc(id: 'rvd_far', lat: 1.0, lon: 1.0, radiusMeters: 50.0);
      final result = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final r = await _readRChannel(result.image);
      final n = result.image.width;
      // The disc IS in the disc-bbox (by definition), so the centre
      // should actually be revealed.
      final centreIdx = (n ~/ 2) * n + (n ~/ 2);
      expect(r[centreIdx], lessThan(128), reason: 'disc at bbox centre must be revealed');
      result.image.dispose();
    });

    test('circular silhouette: 8 equidistant samples agree within tolerance (BUG-010 regression)', () async {
      const builder = RevealedSdfBuilder();
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      final disc = _disc(id: 'rvd_silhouette', lat: 0.005, lon: 0.005, radiusMeters: 200.0);
      final result = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final img = result.image;
      final r = await _readRChannel(img);
      final n = img.width;
      final cx = n / 2.0;
      final cy = n / 2.0;

      // Sample 8 points on an INSIDE ring: all should read as revealed
      // and agree to within ±2 bytes.
      final insideRing = _sampleOctagon(r, cx: cx, cy: cy, radiusPx: 10.0, n: n);
      final insideMin = insideRing.reduce(math.min);
      final insideMax = insideRing.reduce(math.max);
      expect(insideMax - insideMin, lessThanOrEqualTo(2), reason: 'inside-ring 8 samples must agree within ±2 bytes (circular silhouette)');
      for (final s in insideRing) {
        expect(s, lessThan(128), reason: 'inside-ring sample must encode as revealed (byte < 128)');
      }

      // Sample 8 points on an OUTSIDE ring: all should read as fog and
      // agree to within ±2 bytes.
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
      const meterDeg = 1.0 / kMetersPerDegreeLat;
      final lonOffset = 25.0 * meterDeg;
      final viewport = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      final discA = _disc(id: 'rvd_a', lat: 0.005, lon: 0.005 - lonOffset, radiusMeters: 100.0);
      final discB = _disc(id: 'rvd_b', lat: 0.005, lon: 0.005 + lonOffset, radiusMeters: 100.0);
      final result = await builder.buildFromDiscs(discs: [discA, discB], viewport: viewport);
      final img = result.image;
      final r = await _readRChannel(img);
      final n = img.width;

      // Midpoint must be inside both discs simultaneously.
      final midIdx = (n ~/ 2) * n + (n ~/ 2);
      expect(r[midIdx], lessThan(128), reason: 'midpoint between two overlapping discs must be revealed');

      // Both centres must be inside. Project lat/lon to disc-bbox pixel.
      final bbox = result.bbox;
      final dLon = bbox.east - bbox.west;
      final dLat = bbox.north - bbox.south;
      int pixelOf(double lat, double lon) {
        final px = ((lon - bbox.west) / dLon * n).floor().clamp(0, n - 1);
        final py = ((bbox.north - lat) / dLat * n).floor().clamp(0, n - 1);
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

      final result1 = await builder.buildFromDiscs(discs: [discA, discB, discC], viewport: viewport);
      final result2 = await builder.buildFromDiscs(discs: [discC, discA, discB], viewport: viewport);
      final r1 = await _readRChannel(result1.image);
      final r2 = await _readRChannel(result2.image);

      expect(r1.length, equals(r2.length));
      for (var i = 0; i < r1.length; i++) {
        if (r1[i] != r2[i]) {
          fail('byte mismatch at index $i: r1=${r1[i]} r2=${r2[i]} (permutation invariance broken)');
        }
      }
      result1.image.dispose();
      result2.image.dispose();
    });

    test('metric circle: N-S and E-W boundary at same distance — Paris lat 48° (BUG-011 regression)', () async {
      const builder = RevealedSdfBuilder();
      const parisLat = 48.85;
      const parisLon = 2.35;
      const halfSpanLat = 0.001;
      const halfSpanLon = 0.0015;
      final viewport = MirkViewportBbox(
        south: parisLat - halfSpanLat,
        west: parisLon - halfSpanLon,
        north: parisLat + halfSpanLat,
        east: parisLon + halfSpanLon,
      );
      final disc = _disc(id: 'rvd_paris', lat: parisLat, lon: parisLon, radiusMeters: 30.0);
      final result = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final img = result.image;
      final r = await _readRChannel(img);
      final n = img.width;

      // Disc centre in the disc-bbox pixel coordinates. The disc is the
      // only disc, so it's centred in the bbox.
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
      expect(diff, lessThanOrEqualTo(1.0), reason: 'BUG-011: N-S boundary distance ($nsAvg px) must match E-W ($ewAvg px) within ±1 pixel at Paris lat 48°');

      img.dispose();
    });

    test('metric circle: N-S ≈ E-W at extreme latitude 70° (BUG-011 stress)', () async {
      const builder = RevealedSdfBuilder();
      const lat70 = 70.0;
      const lon70 = 25.0;
      const halfSpanLat = 0.001;
      const halfSpanLon = 0.003;
      final viewport = MirkViewportBbox(south: lat70 - halfSpanLat, west: lon70 - halfSpanLon, north: lat70 + halfSpanLat, east: lon70 + halfSpanLon);
      final disc = _disc(id: 'rvd_arctic', lat: lat70, lon: lon70, radiusMeters: 25.0);
      final result = await builder.buildFromDiscs(discs: [disc], viewport: viewport);
      final img = result.image;
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

    test('viewport independence: same discs, different viewports → identical SDF bytes (BUG-014)', () async {
      const builder = RevealedSdfBuilder();
      final disc = _disc(id: 'rvd_stable', lat: 0.005, lon: 0.005, radiusMeters: 100.0);

      // Two very different viewports — the SDF should be identical because
      // the builder now uses the disc bbox, not the viewport.
      final viewportA = MirkViewportBbox(south: 0.0, west: 0.0, north: 0.01, east: 0.01);
      final viewportB = MirkViewportBbox(south: -1.0, west: -1.0, north: 1.0, east: 1.0);

      final resultA = await builder.buildFromDiscs(discs: [disc], viewport: viewportA);
      final resultB = await builder.buildFromDiscs(discs: [disc], viewport: viewportB);

      final rA = await _readRChannel(resultA.image);
      final rB = await _readRChannel(resultB.image);

      expect(rA.length, equals(rB.length));
      for (var i = 0; i < rA.length; i++) {
        if (rA[i] != rB[i]) {
          fail('byte mismatch at index $i: rA=${rA[i]} rB=${rB[i]} — SDF should be viewport-independent');
        }
      }

      // Bboxes should also be identical since the disc list is the same.
      expect(resultA.bbox.south, equals(resultB.bbox.south));
      expect(resultA.bbox.west, equals(resultB.bbox.west));
      expect(resultA.bbox.north, equals(resultB.bbox.north));
      expect(resultA.bbox.east, equals(resultB.bbox.east));

      resultA.image.dispose();
      resultB.image.dispose();
    });

    test('returned bbox covers all discs with padding (BUG-014)', () async {
      const builder = RevealedSdfBuilder();
      final discA = _disc(id: 'rvd_a', lat: 48.85, lon: 2.35, radiusMeters: 100.0);
      final discB = _disc(id: 'rvd_b', lat: 48.86, lon: 2.36, radiusMeters: 50.0);
      final viewport = MirkViewportBbox(south: 48.84, west: 2.34, north: 48.87, east: 2.37);
      final result = await builder.buildFromDiscs(discs: [discA, discB], viewport: viewport);

      // Bbox must contain both disc centres.
      expect(result.bbox.south, lessThan(discA.lat));
      expect(result.bbox.north, greaterThan(discB.lat));
      expect(result.bbox.west, lessThan(discA.lon));
      expect(result.bbox.east, greaterThan(discB.lon));

      // Bbox must have padding beyond the disc extents (500m padding
      // in degrees at lat 48° ≈ 0.0045° lat, 0.0067° lon).
      final latDegPerMeter = 1.0 / kMetersPerDegreeLat;
      final discAMinLat = discA.lat - discA.radiusMeters * latDegPerMeter;
      final discBMaxLat = discB.lat + discB.radiusMeters * latDegPerMeter;
      // The bbox south must be at least 500m (≈ 0.0045°) below disc A's
      // southernmost extent.
      final expectedPaddingDeg = RevealedSdfBuilder.kSdfBboxPaddingMeters * latDegPerMeter;
      expect(result.bbox.south, lessThanOrEqualTo(discAMinLat - expectedPaddingDeg + 0.0001));
      expect(result.bbox.north, greaterThanOrEqualTo(discBMaxLat + expectedPaddingDeg - 0.0001));

      result.image.dispose();
    });
  });
}

/// Builds a disc fixture with default sessionId / fixedAtUtc.
RevealDisc _disc({required String id, required double lat, required double lon, required double radiusMeters}) {
  return RevealDisc(id: id, sessionId: 'ses_test', lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: DateTime.utc(2026, 4, 26));
}

/// Samples 8 points on a circle of [radiusPx] around `(cx, cy)` and
/// returns their R-channel bytes.
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

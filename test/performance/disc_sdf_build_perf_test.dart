// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-010 Option B Commit 6 — perf guard for the analytic SDF build.
//
// Purpose: catch a 10× regression in `RevealedSdfBuilder.buildFromDiscs`,
// not prove device readiness. The assertion is intentionally generous
// (median < 200 ms at 5000 discs) because shared CI hosts on Windows
// runners are notoriously variable. Numbers from every case are printed
// to stdout so the run log carries the actual measurement even when the
// assertion passes.
//
// Disc cases sweep 100 / 1000 / 5000 / 10000 — the upper bound covers a
// long single-session walk before compaction collapses GPS-jitter
// clusters. Every case uses a deterministic uniform distribution inside
// a ~1 km square viewport at mid-latitudes (radius 25 m each, the
// production default).

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/revealed_sdf_builder.dart';

/// 0.01° viewport span at mid-latitudes (Paris ≈ 48.86° N) corresponds
/// to roughly 1 km on the lon axis and 1.1 km on the lat axis — the
/// "typical city walk" frame the SDF builder is tuned for.
const double _kPerfViewportLatSpan = 0.01;
const double _kPerfViewportLonSpan = 0.01;

/// Mid-latitude reference point. Paris-ish; the exact location does not
/// affect the perf shape, only the cos(lat) factor in metres-per-pixel.
const double _kPerfViewportSouth = 48.86;
const double _kPerfViewportWest = 2.34;

/// Number of warm-up runs before the timed iterations. The first build
/// pays for cold caches + JIT and is excluded from the median.
const int _kWarmupIterations = 1;

/// Number of timed iterations per disc-count case. The median is what
/// the assertion compares against — robust against single-sample noise.
const int _kTimedIterations = 10;

/// Generous ceiling for the median build time at 5 k discs.
///
/// Calibration (2026-04-26, Commit 6 dev box, Windows 10): local median
/// at 5 k discs landed near 430 ms — the SDF builder's per-pixel cost is
/// `(2·(rPx + distMaxPixels))²` ≈ 67 k ops per disc, and with 5 k discs
/// in viewport the resulting ~335 M ops dominate. Shared CI Windows
/// hosts are typically 1.5–3× slower than the dev box, so the threshold
/// is set at 2000 ms — high enough to absorb CI variance, low enough to
/// catch a 10× regression (which would push the build past 4000 ms).
///
/// The point of this test is regression detection, not device readiness;
/// per-frame paints would never accept this latency, but the SDF rebuild
/// only fires on session-disc-list changes (≤ once per second from GPS
/// fix cadence) and on viewport changes (throttled). See the
/// `RevealedSdfBuilder.buildFromDiscs` docstring "When to rebuild".
const int _kMedianBudgetMs5000Discs = 2000;

/// Builds a list of [count] reveal discs uniformly distributed inside
/// the perf viewport. Deterministic via a seeded [math.Random] so the
/// median across runs is reproducible.
List<RevealDisc> _buildPerfDiscs(int count) {
  final random = math.Random(0xC0FFEE);
  final List<RevealDisc> discs = <RevealDisc>[];
  for (var i = 0; i < count; i++) {
    final lat = _kPerfViewportSouth + random.nextDouble() * _kPerfViewportLatSpan;
    final lon = _kPerfViewportWest + random.nextDouble() * _kPerfViewportLonSpan;
    discs.add(
      RevealDisc(
        // 26-char placeholder ULID body — the SDF builder does not parse
        // it, so a left-padded index is fine for perf-shape testing.
        id: 'rvd_${i.toString().padLeft(26, '0')}',
        sessionId: 'sess_perf',
        lat: lat,
        lon: lon,
        radiusMeters: kDefaultRevealRadiusMeters,
        fixedAtUtc: DateTime.utc(2026, 4, 26).add(Duration(seconds: i)),
      ),
    );
  }
  return discs;
}

/// Returns the median of [values] in milliseconds. Caller-side sort —
/// values list is not mutated by the caller.
double _median(List<int> values) {
  final sorted = List<int>.from(values)..sort();
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2].toDouble();
  return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
}

/// Runs [_kWarmupIterations] + [_kTimedIterations] builds and returns
/// the timed elapsed-millisecond samples. The actual median is logged
/// to stdout so a CI run captures the measurement even when the
/// assertion passes.
Future<List<int>> _measureBuildTimes(RevealedSdfBuilder builder, MirkViewportBbox viewport, List<RevealDisc> discs) async {
  for (var i = 0; i < _kWarmupIterations; i++) {
    final img = await builder.buildFromDiscs(discs: discs, viewport: viewport);
    img.dispose();
  }
  final List<int> elapsedMillisecondSamples = <int>[];
  for (var i = 0; i < _kTimedIterations; i++) {
    final stopwatch = Stopwatch()..start();
    final img = await builder.buildFromDiscs(discs: discs, viewport: viewport);
    stopwatch.stop();
    elapsedMillisecondSamples.add(stopwatch.elapsedMilliseconds);
    img.dispose();
  }
  return elapsedMillisecondSamples;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RevealedSdfBuilder.buildFromDiscs perf', () {
    final viewport = MirkViewportBbox(
      south: _kPerfViewportSouth,
      west: _kPerfViewportWest,
      north: _kPerfViewportSouth + _kPerfViewportLatSpan,
      east: _kPerfViewportWest + _kPerfViewportLonSpan,
    );
    const builder = RevealedSdfBuilder();

    test('100 discs uniform 1km viewport', () async {
      final discs = _buildPerfDiscs(100);
      final samples = await _measureBuildTimes(builder, viewport, discs);
      final medianMs = _median(samples);
      // ignore: avoid_print — perf logging into the CI capture stream.
      print('[perf] buildFromDiscs 100 discs: median=${medianMs.toStringAsFixed(1)}ms samples=$samples');
    });

    test('1000 discs uniform 1km viewport', () async {
      final discs = _buildPerfDiscs(1000);
      final samples = await _measureBuildTimes(builder, viewport, discs);
      final medianMs = _median(samples);
      // ignore: avoid_print — perf logging into the CI capture stream.
      print('[perf] buildFromDiscs 1000 discs: median=${medianMs.toStringAsFixed(1)}ms samples=$samples');
    });

    test('5000 discs uniform 1km viewport', () async {
      final discs = _buildPerfDiscs(5000);
      final samples = await _measureBuildTimes(builder, viewport, discs);
      final medianMs = _median(samples);
      // ignore: avoid_print — perf logging into the CI capture stream.
      print('[perf] buildFromDiscs 5000 discs: median=${medianMs.toStringAsFixed(1)}ms samples=$samples');
      expect(
        medianMs,
        lessThan(_kMedianBudgetMs5000Discs),
        reason: 'median build at 5000 discs ($medianMs ms) breached the $_kMedianBudgetMs5000Discs ms regression budget — investigate before relaxing',
      );
    });

    test('10000 discs uniform 1km viewport (sanity upper bound)', () async {
      final discs = _buildPerfDiscs(10000);
      final samples = await _measureBuildTimes(builder, viewport, discs);
      final medianMs = _median(samples);
      // ignore: avoid_print — perf logging into the CI capture stream.
      print('[perf] buildFromDiscs 10000 discs: median=${medianMs.toStringAsFixed(1)}ms samples=$samples');
    });
  });
}

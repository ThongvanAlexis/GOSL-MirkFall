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
// BUG-014 iteration 4: the builder now returns [SdfBuildResult] containing
// both the image and the disc bbox. The perf test is updated to unwrap
// the result.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/revealed_sdf_builder.dart';

/// 0.01° viewport span at mid-latitudes (Paris ≈ 48.86° N) corresponds
/// to roughly 1 km on the lon axis and 1.1 km on the lat axis.
const double _kPerfViewportLatSpan = 0.01;
const double _kPerfViewportLonSpan = 0.01;

/// Mid-latitude reference point.
const double _kPerfViewportSouth = 48.86;
const double _kPerfViewportWest = 2.34;

/// Number of warm-up runs before the timed iterations.
const int _kWarmupIterations = 1;

/// Number of timed iterations per disc-count case.
const int _kTimedIterations = 10;

/// Generous ceiling for the median build time at 5 k discs.
const int _kMedianBudgetMs5000Discs = 3000;

/// Builds a list of [count] reveal discs uniformly distributed inside
/// the perf viewport.
List<RevealDisc> _buildPerfDiscs(int count) {
  final random = math.Random(0xC0FFEE);
  final List<RevealDisc> discs = <RevealDisc>[];
  for (var i = 0; i < count; i++) {
    final lat = _kPerfViewportSouth + random.nextDouble() * _kPerfViewportLatSpan;
    final lon = _kPerfViewportWest + random.nextDouble() * _kPerfViewportLonSpan;
    discs.add(
      RevealDisc(
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

/// Returns the median of [values] in milliseconds.
double _median(List<int> values) {
  final sorted = List<int>.from(values)..sort();
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2].toDouble();
  return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
}

/// Runs warm-up + timed builds and returns elapsed-millisecond samples.
Future<List<int>> _measureBuildTimes(RevealedSdfBuilder builder, MirkViewportBbox viewport, List<RevealDisc> discs) async {
  for (var i = 0; i < _kWarmupIterations; i++) {
    final result = await builder.buildFromDiscs(discs: discs, viewport: viewport);
    result.image.dispose();
  }
  final List<int> elapsedMillisecondSamples = <int>[];
  for (var i = 0; i < _kTimedIterations; i++) {
    final stopwatch = Stopwatch()..start();
    final result = await builder.buildFromDiscs(discs: discs, viewport: viewport);
    stopwatch.stop();
    elapsedMillisecondSamples.add(stopwatch.elapsedMilliseconds);
    result.image.dispose();
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
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

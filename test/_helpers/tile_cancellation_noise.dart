// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-07 — shared shape of the vector_map_tiles teardown-noise
// handling first written inline in `test/infrastructure/map/flutter_map_map_view_test.dart`
// (09.1-02). Every test that mounts the REAL engine (`FlutterMapMapViewWidget` on a
// PMTiles archive) needs it at unmount / archive swap: `vector_map_tiles 8.0.0`
// cancels in-flight tile jobs and some `CancellationException`s (owned by its
// transitive `executor_lib`, deliberately not imported — deferred-items #3) escape
// as silent image-service reports or as a single uncaught zone error.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real time given to in-flight tile jobs before an unmount / swap.
const Duration kTileSettleTime = Duration(milliseconds: 600);

/// Frame cadence of the settle / ready loops.
const Duration kTilePumpStep = Duration(milliseconds: 50);

/// Real delay between two settle frames.
const Duration _settleRealDelay = Duration(milliseconds: 25);

/// Small viewport: a handful of tiles instead of the 800×600 default's dozens.
const Size kSmallTileViewport = Size(320, 320);

/// True for the `CancellationException` vector_map_tiles raises on cancelled
/// tile jobs (matched by type name — same rule as `isBenignTileCancellation`
/// in `lib/main.dart`).
bool isTileCancellation(Object? error) => error.runtimeType.toString() == 'CancellationException';

/// Swallows the cancelled raster tile jobs that vector_map_tiles reports
/// through the image resource service (`FlutterError.reportError(...,
/// silent: true)`) when tiles are pruned after a move or a layer unmounts.
/// Production ignores those; `flutter_test` would fail the test on each.
/// Everything else is forwarded to the binding's handler. Must be called at
/// the top of the test BODY (the binding overwrites `onError` after `setUp`).
void installTileCancellationFilterForBody() {
  final void Function(FlutterErrorDetails details)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.silent && isTileCancellation(details.exception)) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Fallback for a cancellation that still escaped as a single uncaught zone
/// error (a render job running when the layer's executor was disposed).
/// Anything else pending — or several exceptions, which the binding coalesces
/// into a synthetic "Multiple exceptions" message — still fails the test.
void drainTileCancellationNoise(WidgetTester tester) {
  final Object? pending = tester.takeException();
  if (pending == null) return;
  expect(isTileCancellation(pending), isTrue, reason: 'only a single tile-job cancellation is tolerated at teardown, got: $pending');
}

/// Shrinks the test viewport to [kSmallTileViewport] (dpr 1) with a reset teardown.
void useSmallViewport(WidgetTester tester) {
  tester.view.physicalSize = kSmallTileViewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Lets in-flight tile jobs finish (real time + frames) so that a following
/// unmount / archive swap disposes an idle layer. Call inside `tester.runAsync`.
Future<void> settleTiles(WidgetTester tester) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < kTileSettleTime) {
    await tester.pump(kTilePumpStep);
    await Future<void>.delayed(_settleRealDelay);
  }
}

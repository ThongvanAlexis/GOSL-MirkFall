// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-05 Task 1 — `SdfCache` hit / miss semantics (POC FOG-03 + PERF-08 port).
//
// The cache key is `hash(quantised discs) ⊕ quantised bbox (1e-4°)`. Sub-quantisation
// viewport drift MUST hit; super-quantisation drift MUST miss; a new disc list MUST miss;
// `dispose()` releases the cached image and the next `getOrBuild` rebuilds. Rebuilds are
// observed through a counting `SdfRebuildLogger` subclass instead of the JSONL stream the
// POC test parsed — no timers, no `Logger.root` level juggling.

import 'dart:async' show Completer;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/sdf/sdf_cache.dart';
import 'package:mirkfall/infrastructure/mirk/sdf_rebuild_logger.dart';

import '../_render_helpers.dart';

/// Counts `recordRebuild` calls regardless of the verbose gate (the override runs before the
/// base class gating) and keeps the last disc counts for assertions.
class _CountingRebuildLogger extends SdfRebuildLogger {
  int rebuildCount = 0;
  int? lastDiscCount;
  int? lastIntersectingDiscCount;

  @override
  void recordRebuild({required double elapsedMs, required int discCount, required int intersectingDiscCount}) {
    rebuildCount++;
    lastDiscCount = discCount;
    lastIntersectingDiscCount = intersectingDiscCount;
  }
}

RevealDisc _disc({required String id, double lat = 48.54, double lon = 2.66}) =>
    RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: 25.0, fixedAtUtc: DateTime.utc(2026, 5));

MirkViewportBbox _viewport({double south = 48.50, double west = 2.60, double north = 48.57, double east = 2.72}) =>
    MirkViewportBbox(south: south, west: west, north: north, east: east);

void main() {
  group('09.1-05 — SdfCache (FOG-03 / PERF-08)', () {
    late _CountingRebuildLogger logger;
    late SdfCache cache;

    setUp(() {
      logger = _CountingRebuildLogger();
      cache = SdfCache(rebuildLogger: logger, builder: const ImmediateStubSdfBuilder());
    });

    tearDown(() => cache.dispose());

    test('same discs + same viewport → identical ui.Image, zero extra rebuild (cache hit)', () async {
      final discs = <RevealDisc>[_disc(id: 'rvd_a')];
      final ui.Image first = await cache.getOrBuild(discs: discs, viewport: _viewport());
      final ui.Image second = await cache.getOrBuild(discs: discs, viewport: _viewport());
      expect(identical(first, second), isTrue, reason: 'cache hit must return the same ui.Image instance');
      expect(logger.rebuildCount, 1, reason: 'only the first call builds');
    });

    test('a new disc list → rebuild (cache miss)', () async {
      final ui.Image first = await cache.getOrBuild(
        discs: <RevealDisc>[_disc(id: 'rvd_a')],
        viewport: _viewport(),
      );
      final ui.Image second = await cache.getOrBuild(
        discs: <RevealDisc>[
          _disc(id: 'rvd_a'),
          _disc(id: 'rvd_b', lat: 48.55),
        ],
        viewport: _viewport(),
      );
      expect(identical(first, second), isFalse);
      expect(logger.rebuildCount, 2);
    });

    test('PERF-08 — viewport shifted by 1e-5° (sub-quantisation) → cache HIT', () async {
      final discs = <RevealDisc>[_disc(id: 'rvd_a')];
      final ui.Image first = await cache.getOrBuild(discs: discs, viewport: _viewport());
      const double drift = 1e-5;
      final ui.Image second = await cache.getOrBuild(
        discs: discs,
        viewport: _viewport(south: 48.50 + drift, west: 2.60 + drift, north: 48.57 + drift, east: 2.72 + drift),
      );
      expect(identical(first, second), isTrue, reason: 'sub-quantisation pan drift must not invalidate the key');
      expect(logger.rebuildCount, 1);
    });

    test('PERF-08 — viewport shifted by 2e-4° (super-quantisation) → cache MISS, recordRebuild once with correct disc counts', () async {
      // Two discs in the list, only one intersecting the viewport (the second sits ~900 km south).
      final discs = <RevealDisc>[_disc(id: 'rvd_a'), _disc(id: 'rvd_far', lat: 40.0)];
      final ui.Image first = await cache.getOrBuild(discs: discs, viewport: _viewport());
      expect(logger.rebuildCount, 1);
      const double drift = 2e-4;
      final ui.Image second = await cache.getOrBuild(
        discs: discs,
        viewport: _viewport(south: 48.50 + drift, west: 2.60 + drift, north: 48.57 + drift, east: 2.72 + drift),
      );
      expect(identical(first, second), isFalse, reason: 'super-quantisation drift must miss');
      expect(logger.rebuildCount, 2, reason: 'exactly one additional rebuild');
      expect(logger.lastDiscCount, 2);
      expect(logger.lastIntersectingDiscCount, 1);
    });

    test('dispose() releases the cached image; the next getOrBuild rebuilds', () async {
      final discs = <RevealDisc>[_disc(id: 'rvd_a')];
      final ui.Image first = await cache.getOrBuild(discs: discs, viewport: _viewport());
      cache.dispose();
      expect(first.debugDisposed, isTrue, reason: 'dispose() must release the cached image (GPU memory)');
      final ui.Image rebuilt = await cache.getOrBuild(discs: discs, viewport: _viewport());
      expect(identical(first, rebuilt), isFalse);
      expect(rebuilt.debugDisposed, isFalse);
      expect(logger.rebuildCount, 2);
    });

    test('a miss disposes the previously cached image (no GPU leak under sustained pan)', () async {
      final discs = <RevealDisc>[_disc(id: 'rvd_a')];
      final ui.Image first = await cache.getOrBuild(discs: discs, viewport: _viewport());
      await cache.getOrBuild(discs: discs, viewport: _viewport(south: 48.51));
      expect(first.debugDisposed, isTrue);
    });

    test('dispose() during an in-flight build disposes the late image and the caller sees a StateError', () async {
      final _GateSdfBuilder gate = _GateSdfBuilder();
      final SdfCache gated = SdfCache(rebuildLogger: logger, builder: gate);
      final Future<ui.Image> pending = gated.getOrBuild(
        discs: <RevealDisc>[_disc(id: 'rvd_a')],
        viewport: _viewport(),
      );
      gated.dispose();
      final ui.Image lateImage = await stubSdfImage();
      gate.release(lateImage);
      await expectLater(pending, throwsStateError);
      expect(lateImage.debugDisposed, isTrue, reason: 'an image built after dispose() must not leak');
      expect(logger.rebuildCount, 0, reason: 'a discarded build is not a rebuild');
    });
  });
}

/// Builder whose future completes only when the test calls [release] — models a build that is
/// still in flight when the owner disposes the cache.
class _GateSdfBuilder extends ImmediateStubSdfBuilder {
  _GateSdfBuilder();

  final List<Completer<ui.Image>> _pending = <Completer<ui.Image>>[];

  /// Completes every pending build with [image].
  void release(ui.Image image) {
    final List<Completer<ui.Image>> toRelease = List<Completer<ui.Image>>.of(_pending);
    _pending.clear();
    for (final Completer<ui.Image> completer in toRelease) {
      completer.complete(image);
    }
  }

  @override
  Future<ui.Image> buildFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport}) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    _pending.add(completer);
    return completer.future;
  }
}

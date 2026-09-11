// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' as ui;

import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import '../sdf_rebuild_logger.dart';
import 'revealed_sdf_builder.dart';

/// Quantised-key cache in front of [RevealedSdfBuilder] (POC FOG-03 / PERF-08, ported by Phase
/// 09.1 plan 09.1-05).
///
/// Key = `hash(disc list) ⊕ quantised viewport bbox`:
///
///   * disc list — length + per-disc `(lat, lon, radiusMeters)` quantised to 1e-6° / 1 mm
///     (tames floating-point drift between frames at the same fix);
///   * viewport bbox — each edge rounded to 1e-4° (~11 m at the equator). Above per-paint
///     micro-drift, below any GPS-fix-driven jump.
///
/// The renderers call [getOrBuild] on EVERY camera change (one build in flight, later requests
/// coalesced) — the POC policy. The quantised key is the only rate limiter: at zoom 15 the bbox
/// key still changes every ~2-3 px of pan, so with MirkFall's persisted disc volumes (far above
/// the POC's 5-50 discs) the rebuild cost during a pan is bounded by build time, not by a timer
/// (RESEARCH §7, Pitfall 5 stays open for Phase 10: spatial index / isolate build). A
/// gesture-level debounce is NOT an option here: the shader samples the texture through the
/// platform-static `sdfRect`, so a stale SDF is pinned to the screen (Phase 09.1 UAT drift).
///
/// The cache OWNS every `ui.Image` it returns: a miss disposes the previous image before
/// replacing it (GPU memory under sustained pan), [dispose] releases the current one, and an
/// image produced by a build still in flight when [dispose] ran is disposed on arrival — the
/// awaiting caller then receives a [StateError] instead of a dead handle. Callers never dispose
/// what they receive.
class SdfCache {
  /// [builder] is a test seam — production wires the const [RevealedSdfBuilder]; tests inject a
  /// fake that resolves a precomputed `ui.Image` to keep suite runtime predictable.
  ///
  /// [rebuildLogger] becomes owned by the cache: [dispose] stops it (a renderer that constructs
  /// its default cache has no other handle on the logger). `stop()` is idempotent, so a test that
  /// also stops the logger it injected is fine.
  SdfCache({required SdfRebuildLogger rebuildLogger, RevealedSdfBuilder? builder})
    : _rebuildLogger = rebuildLogger,
      _builder = builder ?? const RevealedSdfBuilder();

  final SdfRebuildLogger _rebuildLogger;
  final RevealedSdfBuilder _builder;

  ui.Image? _cachedImage;
  int? _cachedHash;

  /// Incremented by [dispose] so a build that started before the call recognises it must not
  /// publish its result.
  int _generation = 0;

  /// Returns the cached `ui.Image` (key hit) or rebuilds through the builder (key miss) — the
  /// caller awaits. Throws [StateError] if [dispose] ran while this build was in flight.
  Future<ui.Image> getOrBuild({required List<RevealDisc> discs, required MirkViewportBbox viewport}) async {
    final int key = _hash(discs, viewport);
    final ui.Image? cached = _cachedImage;
    if (cached != null && key == _cachedHash) return cached;

    final int generationAtStart = _generation;
    final Stopwatch stopwatch = Stopwatch()..start();
    final ui.Image image = await _builder.buildFromDiscs(discs: discs, viewport: viewport);
    stopwatch.stop();

    if (generationAtStart != _generation) {
      image.dispose();
      throw StateError('SdfCache.dispose() was called while a build was in flight — result discarded');
    }

    _cachedImage?.dispose();
    _cachedImage = image;
    _cachedHash = key;

    final int intersecting = discs.where((RevealDisc d) => d.intersectsBbox(viewport)).length;
    _rebuildLogger.recordRebuild(
      elapsedMs: stopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond,
      discCount: discs.length,
      intersectingDiscCount: intersecting,
    );
    return image;
  }

  /// Releases the cached `ui.Image`, invalidates any in-flight build and stops the rebuild
  /// logger. Call from the owner's dispose path. The cache stays usable: a later [getOrBuild]
  /// rebuilds from scratch.
  void dispose() {
    _generation++;
    _cachedImage?.dispose();
    _cachedImage = null;
    _cachedHash = null;
    _rebuildLogger.stop();
  }

  int _hash(List<RevealDisc> discs, MirkViewportBbox viewport) {
    final List<int> discHashes = discs
        .map((RevealDisc d) {
          final int qlat = (d.lat * _spatialQuantisationFactor).round();
          final int qlon = (d.lon * _spatialQuantisationFactor).round();
          final int qrad = (d.radiusMeters * _radiusQuantisationFactor).round();
          return Object.hash(qlat, qlon, qrad);
        })
        .toList(growable: false);
    return Object.hash(_quantiseBbox(viewport), Object.hashAll(discHashes), discs.length);
  }

  /// Hashes the bbox edges rounded to the nearest `1 / _bboxQuantisationFactor` degree.
  int _quantiseBbox(MirkViewportBbox v) {
    final int qs = (v.south * _bboxQuantisationFactor).round();
    final int qw = (v.west * _bboxQuantisationFactor).round();
    final int qn = (v.north * _bboxQuantisationFactor).round();
    final int qe = (v.east * _bboxQuantisationFactor).round();
    return Object.hash(qs, qw, qn, qe);
  }
}

/// 1e6 → lat/lon quantised to 6 decimals (~10 cm at the equator). Well below GPS accuracy and
/// the 25 m disc radius — guards against floating-point drift between frames at the same fix.
const double _spatialQuantisationFactor = 1e6;

/// 1e3 → radius quantised to 1 mm.
const double _radiusQuantisationFactor = 1e3;

/// 1e4 → bbox edges quantised to 4 decimals (~11 m at the equator) — the PERF-08 rebuild
/// threshold. Above per-paint micro-drift (~1e-7° during pan), below a real GPS-fix-driven jump
/// (1 m ≈ 9e-6°).
const double _bboxQuantisationFactor = 1e4;

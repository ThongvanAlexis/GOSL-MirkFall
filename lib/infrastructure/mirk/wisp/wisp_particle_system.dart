// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui' show BlendMode, Canvas, Color, Offset, Paint, PaintingStyle;

import 'package:mirkfall/config/constants.dart';

import 'wisp_particle.dart';

/// CPU-side wisp particle system — Phase 09 BUG-009 (TIER 2).
///
/// Spawns short-lived particles at the SDF boundary when the user
/// reveals new cells, integrates them via curl-noise advection on
/// the Dart side, and renders them via additive blending.
///
/// Reference 1 (earth.nullschool flow physics) + Reference 9 (Foundry
/// VTT animated mist) inspiration. ~200 wisps cap is invisible cost
/// on any 2026 mobile GPU and dense enough that the eye latches onto
/// motion as the user walks.
///
/// ## Thread safety
///
/// NOT thread-safe. Owned by a single MirkRenderer; called from the
/// CustomPainter.paint() pump on the platform UI isolate. No mutexes
/// or concurrent access.
///
/// ## Lifecycle
///
/// 1. `spawnAtCellCenter` is called by the renderer when its
///    `MirkPaintContext.visibleTiles` reveals new cells (the renderer
///    diffs the new bitmap against the cached previous bitmap).
/// 2. `advance(dt)` integrates every active wisp and decrements life.
///    Dead wisps are removed in-place.
/// 3. `render(canvas, paint)` draws each active wisp as an
///    additive-blended soft circle.
///
/// All three operations are O(N) over the active count; the cap
/// (`kMirkFogWispMaxCount` = 200) makes worst-case ~50 µs per frame
/// — negligible at 60 fps.
class WispParticleSystem {
  /// Constructs an empty system with the [maxCount] cap (default
  /// [kMirkFogWispMaxCount]). Tests can override via the parameter
  /// when stress-testing the LRU eviction.
  WispParticleSystem({int maxCount = kMirkFogWispMaxCount, int rngSeed = 1337}) : _maxCount = maxCount, _rng = math.Random(rngSeed);

  final int _maxCount;
  final math.Random _rng;

  /// Currently alive wisps. `final` because we mutate in place; size
  /// fluctuates as wisps spawn and die.
  final List<WispParticle> _wisps = <WispParticle>[];

  /// Read-only view for tests / debug.
  Iterable<WispParticle> get wisps => _wisps;

  /// Number of currently active wisps.
  int get activeCount => _wisps.length;

  /// Spawns up to [kMirkFogWispSpawnPerCell] new wisps at the cell
  /// centre [position], with initial velocity along [direction] (length
  /// usually 1 — a unit gradient). The renderer computes [direction]
  /// from the SDF gradient at [position] so wisps stream OUT of the
  /// revealed area into the fog.
  ///
  /// If the active count would exceed [_maxCount], the OLDEST wisps
  /// are LRU-evicted (oldest = lowest remaining life). The cap is a
  /// hard ceiling, not a soft suggestion.
  void spawnAtCellCenter({required Offset position, required Offset direction}) {
    for (var i = 0; i < kMirkFogWispSpawnPerCell; i++) {
      // Tiny random jitter on the spawn position so multi-particle
      // bursts don't perfectly overlap.
      final jitterX = (_rng.nextDouble() - 0.5) * 4.0;
      final jitterY = (_rng.nextDouble() - 0.5) * 4.0;
      // Velocity is the unit direction × initial speed × a small
      // random factor to break visual lockstep.
      final speedFactor = 0.8 + _rng.nextDouble() * 0.4; // [0.8, 1.2)
      final velocity = Offset(direction.dx * kMirkFogWispInitialSpeedPx * speedFactor, direction.dy * kMirkFogWispInitialSpeedPx * speedFactor);
      _wisps.add(
        WispParticle(position: position + Offset(jitterX, jitterY), velocity: velocity, life: kMirkFogWispLifeSeconds, maxLife: kMirkFogWispLifeSeconds),
      );
    }
    _enforceCap();
  }

  /// Removes the OLDEST wisps (lowest remaining life) until the
  /// active count is <= [_maxCount]. LRU semantics — newer particles
  /// always win the budget.
  void _enforceCap() {
    if (_wisps.length <= _maxCount) return;
    // Sort by life descending; keep the first `_maxCount`.
    _wisps.sort((a, b) => b.life.compareTo(a.life));
    _wisps.removeRange(_maxCount, _wisps.length);
  }

  /// Integrates the system forward by [dt] seconds.
  ///
  /// Each wisp:
  ///   - applies a per-particle curl-noise force (computed on the CPU
  ///     using the same hash-based 2D noise the shader uses, so the
  ///     two systems share visual character without coupling).
  ///   - integrates velocity and position via Euler step.
  ///   - decrements life.
  ///
  /// Dead wisps are removed in place. After this call,
  /// [activeCount] reflects the post-step count.
  void advance(double dt) {
    // Iterate in reverse so we can `removeAt` without index shift.
    for (var i = _wisps.length - 1; i >= 0; i--) {
      final w = _wisps[i];
      // Curl-noise force at the wisp's current position. Magnitude
      // tuned conservatively — the wisp's PRIMARY motion is its
      // initial velocity from the SDF gradient; curl is a perturbation
      // that adds organic drift.
      final curl = _curlNoise(w.position * 0.005);
      const curlMagnitude = 8.0;
      final fx = curl.dx * curlMagnitude;
      final fy = curl.dy * curlMagnitude;
      // Slight drag (0.95 per second) so wisps don't accelerate
      // unboundedly when the curl force happens to align with
      // velocity. dt-scaled drag = exp(-decayRate * dt); we use the
      // linear approximation (1 - decayRate * dt) for tiny dt.
      const dragPerSecond = 0.30;
      final dragFactor = 1.0 - dragPerSecond * dt;
      w.velocity = Offset(w.velocity.dx * dragFactor + fx * dt, w.velocity.dy * dragFactor + fy * dt);
      w.position = w.position + w.velocity * dt;
      w.life -= dt;
      if (w.isDead) {
        _wisps.removeAt(i);
      }
    }
  }

  /// Renders every active wisp as an additive-blended soft circle.
  /// Each wisp's radius interpolates from [kMirkFogWispBirthRadiusPx]
  /// at age 0 to [kMirkFogWispDeathRadiusPx] at age 1; alpha follows
  /// a 1 - age² curve (slow start, sharp fade-out at end of life).
  void render(Canvas canvas, Color tint) {
    if (_wisps.isEmpty) return;
    for (final w in _wisps) {
      final age = w.age;
      final radius = kMirkFogWispBirthRadiusPx + (kMirkFogWispDeathRadiusPx - kMirkFogWispBirthRadiusPx) * age;
      // Alpha curve: 1 - age² → starts near 1, drops sharply at end.
      // Multiplied by the configured peak alpha and the tint's alpha.
      final alphaFactor = (1.0 - age * age).clamp(0.0, 1.0);
      // Use the wide-gamut Color.r/g/b/a (Flutter 3.41+) to avoid the
      // deprecation warnings that the legacy `red`/`green`/`blue` ints
      // carry. The wisp tint is provided by the renderer as a low-bit
      // RGBA constant; converting through .r * 255 stays bit-exact for
      // any 8-bit input.
      final tintR = (tint.r * 255.0).round().clamp(0, 255);
      final tintG = (tint.g * 255.0).round().clamp(0, 255);
      final tintB = (tint.b * 255.0).round().clamp(0, 255);
      final tintA = (tint.a * 255.0).round().clamp(0, 255);
      final wispAlpha = alphaFactor * kMirkFogWispPeakAlpha * (tintA / 255.0);
      final paint = Paint()
        ..color = Color.fromARGB((wispAlpha * 255).round(), tintR, tintG, tintB)
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus; // Additive — wisps brighten the fog where they overlap.
      canvas.drawCircle(w.position, radius, paint);
    }
  }

  /// Removes all active wisps. Useful when the session ends or the
  /// renderer is disposed.
  void clear() {
    _wisps.clear();
  }

  /// Cheap deterministic 2D curl-noise vector field (hash + central
  /// differences). Same algorithm as the .frag's curl2() — visually
  /// consistent with the shader's curl advection.
  Offset _curlNoise(Offset p) {
    const e = 0.05;
    final n1 = _scalarNoise(p + const Offset(0, e));
    final n2 = _scalarNoise(p + const Offset(0, -e));
    final n3 = _scalarNoise(p + const Offset(e, 0));
    final n4 = _scalarNoise(p + const Offset(-e, 0));
    return Offset(n1 - n2, -(n3 - n4)) / (2.0 * e);
  }

  /// Cheap hash-based scalar noise. Not strictly simplex — uses a
  /// trilinear-blended hash3 in the same style as the shader's
  /// noise2(). Performance > realism: this drives wisp drift, the
  /// user perceives the motion not the noise function.
  double _scalarNoise(Offset p) {
    final ix = p.dx.floor();
    final iy = p.dy.floor();
    final fx = p.dx - ix;
    final fy = p.dy - iy;
    final ux = fx * fx * (3.0 - 2.0 * fx);
    final uy = fy * fy * (3.0 - 2.0 * fy);
    final h00 = _hash2(ix, iy);
    final h10 = _hash2(ix + 1, iy);
    final h01 = _hash2(ix, iy + 1);
    final h11 = _hash2(ix + 1, iy + 1);
    final n0 = h00 * (1.0 - ux) + h10 * ux;
    final n1 = h01 * (1.0 - ux) + h11 * ux;
    return n0 * (1.0 - uy) + n1 * uy;
  }

  /// Cheap 2D-int hash → [0, 1).
  double _hash2(int x, int y) {
    var h = x * 374761393 + y * 668265263; // Two large primes.
    h = (h ^ (h >> 13)) * 1274126177;
    h = h & 0x7FFFFFFF;
    return (h % 10000) / 10000.0;
  }
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import 'wisp_particle.dart';

/// CPU-side wisp particle system — Phase 09 BUG-009 (TIER 2), rewritten in WORLD coordinates by
/// Phase 09.1 plan 09.1-05 (POC WISP-01..05 port).
///
/// Spawns short-lived particles along the perimeter of each newly revealed disc, integrates them
/// with curl-noise advection in metres, and hands the live list to the renderer, which projects
/// every wisp through `MirkPaintContext.projectToScreen` and draws it after the shader rect.
///
/// Reference 1 (earth.nullschool flow physics) + Reference 9 (Foundry VTT animated mist)
/// inspiration. ~200 wisps cap is invisible cost on any 2026 mobile GPU and dense enough that
/// the eye latches onto motion as the user walks.
///
/// ## Contract
///
///   1. **WISP-01 — world position.** `WispParticle.position` is a [GeoPoint]; velocity is m/s.
///      This class never sees a screen pixel, a camera or a map engine: it does NOT import
///      `flutter_map` / `latlong2`, and — **Pitfall 4 firewall** — it NEVER imports the SDF
///      cache, the SDF builder or the SDF rebuild logger. The wisp system and the SDF pipeline
///      are independent consumers of the same disc list;
///      `test/infrastructure/mirk/wisp/wisp_sdf_firewall_test.dart` enforces it structurally.
///   2. **WISP-02 — perimeter spawn, idempotent.** [spawnAtNewDisc] emits
///      `round(2π · radiusMeters / kMirkFogMetersPerWisp)` wisps (≈ 20 for a 25 m disc at 8 m
///      spacing) streaming OUTWARD from the disc; a second call with the same `discId` is a
///      no-op, so the renderer can forward every disc it sees without bookkeeping.
///   3. **WISP-03 — 5 s warm-up (BUG-015).** During the first [kMirkFogWispWarmUpSeconds] of the
///      system's wall-clock lifetime [spawnAtNewDisc] is inert, but the `discId` IS recorded, so
///      the discs of a resumed session (and those that scroll in during the map-open camera
///      animation) never burst — neither now nor after the gate opens. The clock starts at
///      construction; a session start / resume or a style change creates a new renderer, hence
///      a new system (see `activeMirkRendererProvider`). There is no reset hook.
///   4. **WISP-05 — spawn rate.** [spawnRatePerSecondAndReset] is a side-effecting accessor read
///      once per `WispTransformLogger` rollup — single source of truth for the rate.
///
/// ## Curl-noise anchor
///
/// The curl field is sampled in a local degree-space basis `(lon − anchor.lon, lat − anchor.lat)
/// · kMirkWispCurlInputScale`. The POC anchored on a hard-coded Melun centre; MirkFall anchors on
/// the centre of the FIRST disc the system spawned (fixed once). The field is translation-
/// invariant in character, so any fixed anchor gives the same organic drift — anchoring near the
/// wisps just keeps the hash inputs small (float precision) without a product-specific constant.
///
/// ## Thread safety / lifecycle
///
/// NOT thread-safe. Owned by a single `MirkRenderer`, driven from `paint()` on the UI isolate:
/// `spawnAtNewDisc` per newly seen disc → `advanceFromElapsed(context.sessionElapsed)` once per
/// paint → the renderer draws [wisps]. Every operation is O(N) over the active count.
class WispParticleSystem {
  /// Constructs an empty system.
  ///
  /// [maxCount] caps the active particle count (LRU eviction beyond it, default
  /// [kMirkFogWispMaxCount]); [rngSeed] seeds the deterministic jitter / speed-factor RNG.
  /// [wallClock] is a TEST SEAM for the warm-up gate — production omits it and the system
  /// starts its own `Stopwatch` here, at construction.
  WispParticleSystem({int maxCount = kMirkFogWispMaxCount, int rngSeed = 1337, Stopwatch? wallClock})
    : _maxCount = maxCount,
      _rng = math.Random(rngSeed),
      _wallClock = wallClock ?? (Stopwatch()..start());

  final int _maxCount;
  final math.Random _rng;
  final Stopwatch _wallClock;

  /// Currently alive wisps. `final` because we mutate in place; size fluctuates as wisps spawn
  /// and die.
  final List<WispParticle> _wisps = <WispParticle>[];

  /// Disc ids already processed by [spawnAtNewDisc] — recorded BEFORE the warm-up gate so a
  /// post-warm-up re-call with the same id is a no-op (WISP-03).
  final Set<String> _alreadySpawnedDiscIdSet = <String>{};

  /// Counter for [spawnRatePerSecondAndReset]. Reset on each call.
  int _spawnCounterSinceLastRollup = 0;

  /// `sessionElapsed` of the previous [advanceFromElapsed]; `null` until the first call.
  Duration? _lastAdvanceElapsed;

  /// Curl-noise anchor — centre of the first disc spawned, fixed once (see class docstring).
  GeoPoint? _curlAnchor;

  /// Read-only view for the renderer / tests. Do not interleave with [advance].
  Iterable<WispParticle> get wisps => _wisps;

  /// Number of currently active wisps.
  int get activeCount => _wisps.length;

  /// Spawns wisps along [disc]'s perimeter (WISP-02). Idempotent on [discId]; inert (but
  /// id-recording) during the warm-up (WISP-03) — see the class docstring.
  void spawnAtNewDisc({required String discId, required RevealDisc disc}) {
    if (!_alreadySpawnedDiscIdSet.add(discId)) return;
    if (_isWarmingUp) return;
    _spawnAlongPerimeter(disc);
  }

  bool get _isWarmingUp => _wallClock.elapsedMilliseconds < (kMirkFogWispWarmUpSeconds * Duration.millisecondsPerSecond).round();

  /// One wisp per perimeter sample point — `round(circumference / kMirkFogMetersPerWisp)`, at
  /// least one so a tiny disc still puffs.
  void _spawnAlongPerimeter(RevealDisc disc) {
    _curlAnchor ??= (latitude: disc.lat, longitude: disc.lon);
    final double radiusMeters = disc.radiusMeters;
    final double circumferenceMeters = _twoPi * radiusMeters;
    final int sampleCount = math.max(1, (circumferenceMeters / kMirkFogMetersPerWisp).round());
    final double metersPerDegreeLon = _metersPerDegreeLonAt(disc.lat);

    for (int i = 0; i < sampleCount; i++) {
      final double theta = (i / sampleCount) * _twoPi;
      final double dLatDeg = radiusMeters * math.sin(theta) / kMetersPerDegreeLat;
      final double dLonDeg = radiusMeters * math.cos(theta) / metersPerDegreeLon;
      final GeoPoint spawnPoint = (latitude: disc.lat + dLatDeg, longitude: disc.lon + dLonDeg);
      // Outward unit normal at this perimeter point (dx east, dy north) — wisps stream OUT of
      // the revealed area into the fog.
      final Offset unitDirection = Offset(math.cos(theta), math.sin(theta));
      _spawnOneWisp(position: spawnPoint, direction: unitDirection, metersPerDegreeLon: metersPerDegreeLon);
      _spawnCounterSinceLastRollup += 1;
    }
  }

  /// Spawns one wisp at [position] with initial velocity along [direction] (unit vector), plus
  /// ±0.5 m position jitter and ±20 % speed jitter so a burst does not move in lockstep.
  /// [metersPerDegreeLon] is the disc-centre longitude scale, shared by every point of one
  /// burst so the perimeter stays a metric circle.
  void _spawnOneWisp({required GeoPoint position, required Offset direction, required double metersPerDegreeLon}) {
    final double jitterMetersEast = (_rng.nextDouble() - _jitterCentre) * _jitterSpanMeters;
    final double jitterMetersNorth = (_rng.nextDouble() - _jitterCentre) * _jitterSpanMeters;
    final GeoPoint jittered = (
      latitude: position.latitude + jitterMetersNorth / kMetersPerDegreeLat,
      longitude: position.longitude + jitterMetersEast / metersPerDegreeLon,
    );
    final double speedFactor = _speedJitterMin + _rng.nextDouble() * _speedJitterSpan;
    final Offset velocity = Offset(direction.dx * kMirkWispDriftMetersPerSecond * speedFactor, direction.dy * kMirkWispDriftMetersPerSecond * speedFactor);
    _wisps.add(WispParticle(position: jittered, velocityMetersPerSecond: velocity, life: kMirkFogWispLifeSeconds, maxLife: kMirkFogWispLifeSeconds));
    _enforceCap();
  }

  /// Removes the OLDEST wisps (lowest remaining life) until the active count is <= [_maxCount].
  /// LRU semantics — newer particles always win the budget.
  void _enforceCap() {
    if (_wisps.length <= _maxCount) return;
    _wisps.sort((WispParticle a, WispParticle b) => b.life.compareTo(a.life));
    _wisps.removeRange(_maxCount, _wisps.length);
  }

  /// Production entry point, once per paint: integrates by the delta of [sessionElapsed] since
  /// the previous call, clamped to `[0, kMirkWispMaxDtSeconds]` so a paused-then-resumed painter
  /// never snap-integrates over seconds. The first call only records the baseline (no dt yet).
  void advanceFromElapsed(Duration sessionElapsed) {
    final Duration? previous = _lastAdvanceElapsed;
    _lastAdvanceElapsed = sessionElapsed;
    if (previous == null) return;
    final double dtSeconds = ((sessionElapsed - previous).inMicroseconds / Duration.microsecondsPerSecond).clamp(0.0, kMirkWispMaxDtSeconds);
    if (dtSeconds <= 0.0) return;
    advance(dtSeconds);
  }

  /// Pure integration step by [dt] seconds (WISP-02): curl-noise acceleration (m/s²) in the
  /// anchored degree basis, linear drag, Euler position update `m/s · dt → degrees`
  /// (`dLat = dy / kMetersPerDegreeLat`, `dLon = dx / (kMetersPerDegreeLat · cos lat)`), life
  /// decrement, then removal of the dead. [dt] is NOT clamped here — callers clamp upstream.
  void advance(double dt) {
    if (_wisps.isEmpty) return;
    final GeoPoint? anchor = _curlAnchor;
    assert(anchor != null, 'wisps exist only after a spawn, which fixes the curl anchor');
    if (anchor == null) return;
    final double dragFactor = 1.0 - kMirkWispDragPerSecond * dt;
    for (final WispParticle w in _wisps) {
      final Offset curlInput = Offset(
        (w.position.longitude - anchor.longitude) * kMirkWispCurlInputScale,
        (w.position.latitude - anchor.latitude) * kMirkWispCurlInputScale,
      );
      final Offset curl = _curlNoise(curlInput);
      final double newVx = w.velocityMetersPerSecond.dx * dragFactor + curl.dx * kMirkWispCurlAccelMetersPerSecondSquared * dt;
      final double newVy = w.velocityMetersPerSecond.dy * dragFactor + curl.dy * kMirkWispCurlAccelMetersPerSecondSquared * dt;
      w.velocityMetersPerSecond = Offset(newVx, newVy);
      final double dLatDeg = (newVy * dt) / kMetersPerDegreeLat;
      final double dLonDeg = (newVx * dt) / _metersPerDegreeLonAt(w.position.latitude);
      w.position = (latitude: w.position.latitude + dLatDeg, longitude: w.position.longitude + dLonDeg);
      w.life -= dt;
    }
    // Removal AFTER the loop — never mutate the list while iterating it.
    _wisps.removeWhere((WispParticle w) => w.isDead);
  }

  /// Spawns since the last call divided by [sinceInterval] (default [kMirkFogDiagRollupSeconds]);
  /// resets the counter (WISP-05). Read once per `WispTransformLogger` rollup.
  double spawnRatePerSecondAndReset({Duration? sinceInterval}) {
    final Duration interval = sinceInterval ?? const Duration(seconds: kMirkFogDiagRollupSeconds);
    final double intervalSeconds = interval.inMilliseconds / Duration.millisecondsPerSecond;
    final double rate = _spawnCounterSinceLastRollup / intervalSeconds;
    _spawnCounterSinceLastRollup = 0;
    return rate;
  }

  /// Removes all active wisps and resets the idempotency set, the spawn counter, the advance
  /// baseline and the curl anchor. Called when the owning renderer is disposed.
  void clear() {
    _wisps.clear();
    _alreadySpawnedDiscIdSet.clear();
    _spawnCounterSinceLastRollup = 0;
    _lastAdvanceElapsed = null;
    _curlAnchor = null;
  }

  /// Metres per degree of longitude at [latitudeDeg], floored near the poles so the division
  /// never explodes (a metre-scale disc at ±90° is meaningless anyway).
  double _metersPerDegreeLonAt(double latitudeDeg) {
    final double cosLat = math.cos(latitudeDeg * math.pi / _degreesPerHalfTurn);
    return kMetersPerDegreeLat * math.max(cosLat.abs(), _polarCosFloor);
  }

  // ─── Curl-noise helpers — Phase 09 donor VERBATIM ────────────────────────
  // Pure-math hash-based scalar noise + central-differences curl. Visually consistent with the
  // shader's curl2() so wisps and the fog body drift on the same field character.

  /// Cheap deterministic 2D curl-noise vector field (hash + central differences).
  Offset _curlNoise(Offset p) {
    const double e = _curlNoiseEpsilon;
    final double n1 = _scalarNoise(p + const Offset(0, e));
    final double n2 = _scalarNoise(p + const Offset(0, -e));
    final double n3 = _scalarNoise(p + const Offset(e, 0));
    final double n4 = _scalarNoise(p + const Offset(-e, 0));
    return Offset(n1 - n2, -(n3 - n4)) / (2.0 * e);
  }

  /// Cheap hash-based scalar noise (smoothstep-blended `_hash2` corners). Performance > realism:
  /// the user perceives the motion, not the noise function.
  double _scalarNoise(Offset p) {
    final int ix = p.dx.floor();
    final int iy = p.dy.floor();
    final double fx = p.dx - ix;
    final double fy = p.dy - iy;
    final double ux = fx * fx * (3.0 - 2.0 * fx);
    final double uy = fy * fy * (3.0 - 2.0 * fy);
    final double h00 = _hash2(ix, iy);
    final double h10 = _hash2(ix + 1, iy);
    final double h01 = _hash2(ix, iy + 1);
    final double h11 = _hash2(ix + 1, iy + 1);
    final double n0 = h00 * (1.0 - ux) + h10 * ux;
    final double n1 = h01 * (1.0 - ux) + h11 * ux;
    return n0 * (1.0 - uy) + n1 * uy;
  }

  /// Cheap 2D-int hash → [0, 1).
  double _hash2(int x, int y) {
    int h = x * _hash2PrimeX + y * _hash2PrimeY;
    h = (h ^ (h >> _hash2ShiftBits)) * _hash2MultiplierC;
    h = h & _hash2Mask31;
    return (h % _hash2Modulo) / _hash2Modulo.toDouble();
  }
}

// ─── File-private numeric constants ────────────────────────────────────────
// Hoisted out of the kinematic / curl-noise math so no magic number appears inline.

const double _twoPi = 2.0 * math.pi;
const double _degreesPerHalfTurn = 180.0;

/// Floor on `|cos(lat)|` for the longitude scale — mirrors the polar guard of `RevealDisc`.
const double _polarCosFloor = 1e-6;

/// ±0.5 m spawn jitter — the donor's ±2 px translated to a small metre fraction of the 25 m disc
/// radius. `_jitterCentre` shifts the uniform [0, 1) random into [-0.5, 0.5).
const double _jitterCentre = 0.5;
const double _jitterSpanMeters = 1.0;

/// Speed jitter — donor's `0.8 + rand × 0.4` ∈ [0.8, 1.2).
const double _speedJitterMin = 0.8;
const double _speedJitterSpan = 0.4;

/// Curl-noise central-differences epsilon. Donor verbatim.
const double _curlNoiseEpsilon = 0.05;

/// Hash-2 primes + bit-mixing constants. Donor verbatim — the visual character of the curl
/// field depends on these specific values.
const int _hash2PrimeX = 374761393;
const int _hash2PrimeY = 668265263;
const int _hash2MultiplierC = 1274126177;
const int _hash2ShiftBits = 13;
const int _hash2Mask31 = 0x7FFFFFFF;
const int _hash2Modulo = 10000;

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Offset;

import 'package:mirkfall/domain/geo/geo_point.dart';

/// One CPU-side wisp particle in the BUG-009 TIER 2 fog system.
///
/// Wisps are discrete tendrils of fog spawned along the perimeter of a newly revealed disc.
/// Each wisp:
///   - lives for a few seconds
///   - drifts via curl-noise advection on the CPU side
///   - grows in radius as it ages (puff dispersing)
///   - fades out at the end of life
///
/// Plain mutable class — performance-critical hot path. Freezed would add allocations on every
/// advection step (copyWith returns a new instance per particle per frame). Mutable struct-style
/// is the right idiom here, hence the explicit deviation from the project's general "prefer
/// immutable models" rule.
///
/// ## WISP-01 — world position (Phase 09.1 plan 09.1-05)
///
/// [position] is a [GeoPoint] (degrees), NOT a screen-pixel `Offset`. The pre-09.1 screen-px
/// basis was the trap behind BUG-014: 18 px/s at zoom 15 is ~86 m/s of ground speed, and a
/// screen-space wisp does not follow the map under pan / zoom. Wisps now live in WORLD
/// coordinates and are projected to the screen at paint time through
/// `MirkPaintContext.projectToScreen` — the same camera snapshot the fog rect used (FOG-07).
/// `GeoPoint` is the domain record (Phase 09.1 C2 option A): no `latlong2` here.
///
/// ## WISP-02 — metric velocity
///
/// [velocityMetersPerSecond] reuses `Offset` as the project's 2-D vector type, in m/s:
/// `dx` is the EASTWARD component, `dy` the NORTHWARD component (positive `dy` increases
/// latitude). Naming the unit in the field eliminates the "px/s or m/s?" class of bug.
class WispParticle {
  /// Constructs a fresh wisp at [position] with initial [velocityMetersPerSecond] and
  /// [life] == [maxLife].
  WispParticle({required this.position, required this.velocityMetersPerSecond, required this.life, required this.maxLife});

  /// Current world-space position in degrees (WISP-01).
  GeoPoint position;

  /// Current 2-D velocity in metres per second — `dx` east, `dy` north (WISP-02).
  Offset velocityMetersPerSecond;

  /// Remaining life in seconds. The particle is evicted at <= 0.
  double life;

  /// Original lifetime — used to compute the normalised age `1 - life / maxLife` for radius
  /// interpolation and alpha falloff.
  final double maxLife;

  /// Whether the particle should be evicted from the active list.
  bool get isDead => life <= 0;

  /// Normalised age in [0, 1]. 0 = just born, 1 = about to die. The clamp makes an over-aged
  /// wisp (`life < 0` between integration and removal) report exactly `1.0`.
  double get age => 1.0 - (life / maxLife).clamp(0.0, 1.0);
}

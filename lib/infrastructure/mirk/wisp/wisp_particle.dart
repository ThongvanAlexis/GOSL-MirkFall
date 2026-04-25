// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Offset;

/// One CPU-side wisp particle in the BUG-009 TIER 2 fog system.
///
/// Wisps are discrete tendrils of fog spawned at the boundary when
/// the user reveals new cells. Each wisp:
///   - lives for a few seconds
///   - drifts via curl-noise advection on the CPU side
///   - grows in radius as it ages (puff dispersing)
///   - fades out at the end of life
///
/// Plain mutable class — performance-critical hot path. Freezed would
/// add allocations on every advection step (copyWith returns a new
/// instance per particle per frame). Mutable struct-style is the right
/// idiom here, hence the explicit deviation from the project's general
/// "prefer immutable models" rule.
class WispParticle {
  /// Constructs a fresh wisp at [position] with initial [velocity].
  WispParticle({required this.position, required this.velocity, required this.life, required this.maxLife});

  /// Current screen-space position in pixels.
  Offset position;

  /// Current velocity in pixels per second.
  Offset velocity;

  /// Remaining life in seconds. The particle is evicted at <= 0.
  double life;

  /// Original lifetime — used to compute the normalised age
  /// `1 - life / maxLife` for radius interpolation and alpha falloff.
  final double maxLife;

  /// Whether the particle should be evicted from the active list.
  bool get isDead => life <= 0;

  /// Normalised age in [0, 1]. 0 = just born, 1 = about to die.
  double get age => 1.0 - (life / maxLife).clamp(0.0, 1.0);
}

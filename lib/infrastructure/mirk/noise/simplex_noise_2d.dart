// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Deterministic 2D simplex noise generator (Ken Perlin 2001).
///
/// Phase 09 Wave 0 scaffold. Wave 2 (plan 09-02 or 09-03 — see Phase 09
/// research §Procedural Noise) supplies the body (~60 LOC of permutation
/// table + gradient lookup). Output range is [-1, 1].
///
/// Seeded for reproducibility — two `SimplexNoise2D(seed: 42)` instances
/// emit identical sequences, which the renderer tests rely on for golden
/// pixel comparisons.
class SimplexNoise2D {
  SimplexNoise2D({this.seed = 0});

  final int seed;

  /// Samples the noise field at coordinates ([x], [y]).
  ///
  /// Returns a value in [-1, 1]. Implementation lands in Wave 2.
  double noise2(double x, double y) => throw UnimplementedError('Wave 2 — plan 09-02 (or 09-03)');
}

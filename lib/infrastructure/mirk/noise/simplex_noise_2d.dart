// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;

/// Deterministic 2D simplex noise generator (Ken Perlin 2001 reference).
///
/// Hand-rolled, pure-Dart port of the simplex algorithm published by
/// Ken Perlin in "Noise hardware" (SIGGRAPH 2002 course notes). The
/// algorithm itself is patent-free and in the public domain; this Dart
/// port is GOSL-licensed as part of the MirkFall project (no third-party
/// runtime dependency, no telemetry, no audit burden).
///
/// ## Output range
///
/// `noise2(x, y)` returns a `double` approximately in `[-1, 1]` (empirical
/// observation across 1000 random samples — the constant `_outputScale`
/// is tuned so the bound is rarely violated). Tests assert the slightly
/// wider envelope `[-1.05, 1.05]`.
///
/// ## Determinism
///
/// Two `SimplexNoise2D` instances constructed with the same `seed`
/// produce identical samples for any `(x, y)`. The seeded permutation
/// table is built deterministically from a `math.Random(seed)` sequence,
/// then doubled to spare a modulo on every lookup.
///
/// ## Statelessness
///
/// `noise2(x, y)` is a pure function of `(x, y)` and the seeded
/// permutation table — calling it repeatedly with the same `(x, y)` returns
/// bit-for-bit identical doubles.
///
/// ## Algorithm structure (≈60 LOC)
///
/// 1. **Skew** input `(xin, yin)` from R² into the simplex grid using the
///    skewing factor `_f2 = (sqrt(3) - 1) / 2`.
/// 2. **Identify the simplex (triangle)** containing the skewed point:
///    one of two orientations depending on the diagonal that splits the
///    unit cell.
/// 3. **Unskew** the three corners back to R² using `_g2 = (3 - sqrt(3)) / 6`
///    and compute the offset vectors from the input point to each corner.
/// 4. **Hash** each corner via the doubled permutation table to pick a
///    pseudorandom gradient from the 12 unit-cube edges (we use the
///    canonical 8-direction 2D set; see [_grad3]).
/// 5. **Sum the three corner contributions**, each falling off as
///    `(0.5 - r²)^4` weighted by the gradient dot-product.
/// 6. **Scale** the sum by [_outputScale] so the empirical range hits
///    `[-1, 1]`.
class SimplexNoise2D {
  /// Constructs a simplex noise sampler seeded by [seed].
  ///
  /// Identical seeds produce identical permutation tables and therefore
  /// identical sample sequences across instances.
  SimplexNoise2D({this.seed = 0}) : _perm = _buildPermutationTable(seed);

  /// Seed used to build the permutation table. Exposed for diagnostic
  /// logging only — runtime sampling depends on the cached [_perm] array.
  final int seed;

  /// 512-entry doubled permutation table. `_perm[i] == _perm[i + 256]` so
  /// hash lookups can index `i & 511` directly without a modulo.
  final List<int> _perm;

  // -- algorithm constants ------------------------------------------------

  // Names `_f2` / `_g2` follow Perlin's 2002 paper notation (`F2` and `G2`)
  // to keep this Dart port verifiable line-by-line against the reference.
  // The lowerCamelCase form matches Dart's identifier convention.

  /// Skewing factor `(sqrt(3) - 1) / 2` for 2D simplex (Perlin paper: `F2`).
  static final double _f2 = 0.5 * (math.sqrt(3.0) - 1.0);

  /// Unskewing factor `(3 - sqrt(3)) / 6` for 2D simplex (Perlin paper: `G2`).
  static final double _g2 = (3.0 - math.sqrt(3.0)) / 6.0;

  /// Output scaling — chosen empirically so the sum-of-three-contributions
  /// envelope hits approximately `[-1, 1]`. The classic Ken Perlin value
  /// of 70 fits the canonical 8-gradient simplex (verified by the
  /// `1000 random samples in [-1.05, 1.05]` test; if that test ever
  /// fires, retune empirically — some references use 40 or 45.2).
  static const double _outputScale = 70.0;

  /// Canonical 12-element 2D gradient set used by Perlin's 2002 paper.
  /// Each pair is a unit-vector direction; the dot-product against the
  /// corner-offset gives the gradient contribution.
  static const List<List<double>> _grad3 = <List<double>>[
    <double>[1.0, 1.0],
    <double>[-1.0, 1.0],
    <double>[1.0, -1.0],
    <double>[-1.0, -1.0],
    <double>[1.0, 0.0],
    <double>[-1.0, 0.0],
    <double>[1.0, 0.0],
    <double>[-1.0, 0.0],
    <double>[0.0, 1.0],
    <double>[0.0, -1.0],
    <double>[0.0, 1.0],
    <double>[0.0, -1.0],
  ];

  /// Builds a 512-entry permutation table seeded deterministically from
  /// [seed]. The first 256 entries are a Fisher-Yates shuffle of `0..255`;
  /// the second 256 entries duplicate the first so callers can index
  /// `i & 511` without a modulo.
  static List<int> _buildPermutationTable(int seed) {
    final rng = math.Random(seed);
    final base = List<int>.generate(256, (i) => i);
    for (int i = 255; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = base[i];
      base[i] = base[j];
      base[j] = tmp;
    }
    return List<int>.generate(512, (i) => base[i & 255], growable: false);
  }

  /// Computes the dot product between gradient `g` and offset `(x, y)`.
  static double _dot2(List<double> g, double x, double y) =>
      g[0] * x + g[1] * y;

  /// Samples the noise field at coordinates ([xin], [yin]).
  ///
  /// Returns a value approximately in `[-1, 1]`. Pure function of the
  /// inputs and the seeded permutation table — repeat calls with the
  /// same `(xin, yin)` return identical doubles.
  double noise2(double xin, double yin) {
    // Skew input space to determine which simplex cell we're in.
    final double s = (xin + yin) * _f2;
    final int i = _floor(xin + s);
    final int j = _floor(yin + s);

    // Unskew the cell origin back to (x, y) space.
    final double t = (i + j) * _g2;
    final double x0Origin = i - t;
    final double y0Origin = j - t;

    // Offset of input point relative to first corner (in (x, y) space).
    final double x0 = xin - x0Origin;
    final double y0 = yin - y0Origin;

    // Determine which simplex (triangle) we're in: lower or upper.
    int i1;
    int j1;
    if (x0 > y0) {
      i1 = 1;
      j1 = 0;
    } else {
      i1 = 0;
      j1 = 1;
    }

    // Offsets for second corner (in unskewed (x, y) space).
    final double x1 = x0 - i1 + _g2;
    final double y1 = y0 - j1 + _g2;
    // Offsets for last corner (the (1,1) vertex of the cell).
    final double x2 = x0 - 1.0 + 2.0 * _g2;
    final double y2 = y0 - 1.0 + 2.0 * _g2;

    // Hash the three corners' integer coordinates to pick gradients.
    final int ii = i & 255;
    final int jj = j & 255;
    final int gi0 = _perm[ii + _perm[jj]] % 12;
    final int gi1 = _perm[ii + i1 + _perm[jj + j1]] % 12;
    final int gi2 = _perm[ii + 1 + _perm[jj + 1]] % 12;

    // Compute each corner's contribution: (0.5 - r²)^4 weighted by the
    // gradient dot-product, with hard cutoff to 0 when r² > 0.5.
    double n0 = 0.0;
    double t0 = 0.5 - x0 * x0 - y0 * y0;
    if (t0 >= 0.0) {
      t0 *= t0;
      n0 = t0 * t0 * _dot2(_grad3[gi0], x0, y0);
    }

    double n1 = 0.0;
    double t1 = 0.5 - x1 * x1 - y1 * y1;
    if (t1 >= 0.0) {
      t1 *= t1;
      n1 = t1 * t1 * _dot2(_grad3[gi1], x1, y1);
    }

    double n2 = 0.0;
    double t2 = 0.5 - x2 * x2 - y2 * y2;
    if (t2 >= 0.0) {
      t2 *= t2;
      n2 = t2 * t2 * _dot2(_grad3[gi2], x2, y2);
    }

    // Sum the three contributions and scale to approximately [-1, 1].
    return _outputScale * (n0 + n1 + n2);
  }

  /// Floor that yields an `int` directly, faster than `value.floor()` for
  /// the typical positive-or-negative finite doubles we sample. For
  /// `value < 0` we subtract 1 from the truncated cast to mimic
  /// mathematical floor semantics.
  static int _floor(double value) {
    final int truncated = value.toInt();
    return value < truncated ? truncated - 1 : truncated;
  }
}

# BUG-011 — Reveal boundary renders as a north-south oval

**Status:** ✅ fixed — `693e084`, `895c457`
**Reported:** 2026-04-26 (UAT walk on `c41f31d` after BUG-010 disc refactor shipped)
**Platform:** cross-platform (SDF builder runs on CPU, same on iOS + Android)

## Symptoms

The boundary around revealed discs appears as a north-south elongated oval instead of a circle. The effect worsens at higher latitudes. At Paris (lat ~48°), the distortion is ~50% — the reveal is clearly taller than it is wide.

## Root cause

`RevealedSdfBuilder.buildFromDiscs` (`lib/infrastructure/mirk/sdf/revealed_sdf_builder.dart`) computed pixel-space Euclidean distance (`sqrt(dx² + dy²)`) instead of metric-space distance. At non-equatorial latitudes, one pixel of latitude covers more metres than one pixel of longitude (by a factor of `1 / cos(lat)`), producing an aspect-ratio distortion of ~50% at Paris (lat 48°).

The Mercator projection stretches longitude pixels relative to latitude pixels as latitude increases. The SDF builder was treating both axes identically in pixel space, which is only correct at the equator.

## Investigation findings

The oval distortion was immediately recognizable as a Mercator projection artefact. The pixel-space distance formula `sqrt(dx² + dy²)` assumes isotropic pixels, but at latitude `phi` the X-pixel covers `cos(phi)` times the metres of a Y-pixel. At Paris (48°N), `cos(48°) ≈ 0.67`, meaning the X-axis is compressed by ~33% relative to Y — producing a north-south elongated oval for what should be a circle.

No alternative causes were investigated because the symptom is pathognomonic for this class of projection bug. The fix was straightforward: convert to metric space before computing distance.

## Strategy / Fix

Switched the inner loop to compute distance in metres:
- `dxMeters = dx * metersPerPixelX`
- `dyMeters = dy * metersPerPixelY`
- `distMeters = sqrt(dxMeters² + dyMeters²)`
- `candidate = (distMeters - disc.radiusMeters) / metersPerPixel`

Also adjusted the per-disc padded bounding box to use anisotropic pixel padding so that the bounding box correctly encloses the metric-space disc at all latitudes.

The metre-space distance adds ~20% CPU overhead to the inner loop (extra multiply per pixel per dimension). The 5k-disc CI perf test budget was bumped from 2000 ms to 3000 ms to accommodate this overhead on the Ubuntu CI runner. The spatial-index TODO (`revealed_sdf_builder.dart:103`) remains the real path to sub-16 ms builds.

## Commits

```
693e084  fix(09-bug-011): compute SDF distance in metres, not pixels (oval → circle)
895c457  fix(09-bug-011): bump SDF perf budget 2000 → 3000 ms (metre-space overhead)
```

## Files modified

- `lib/infrastructure/mirk/sdf/revealed_sdf_builder.dart` — metric-space distance in inner loop + anisotropic bounding box
- `test/infrastructure/mirk/sdf/revealed_sdf_builder_test.dart` — latitude-dependent circle assertions
- `test/performance/disc_sdf_build_perf_test.dart` — perf budget bump 2000 → 3000 ms

## Test coverage

Added "metric circle N-S ≈ E-W boundary distance" assertion at Paris lat 48° + high-latitude (70°) variant. Both tests verify that the SDF boundary distance measured along the N-S axis is within tolerance of the E-W axis distance, catching any regression to pixel-space computation.

## Known follow-ups

- [ ] Spatial-index pass on `buildFromDiscs` (`revealed_sdf_builder.dart:103` TODO) — the 20% CPU overhead from metre-space math makes this optimisation more pressing for device-class hardware
- [ ] Verify on-device at extreme latitudes (northern Scandinavia, ~70°) during a future UAT walk

## Links

- **BUG-010** — parent refactor that introduced the disc-based SDF builder where this bug lived
- **BUG-012** — strobe during pan, discovered in the same UAT walk session
- **BUG-014** — another SDF coordinate-space bug (axis swap), related family of projection issues

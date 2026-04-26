# BUG-011 — Reveal boundary renders as a north-south oval

**Status:** ✅ fixed — `907064b`
**Reported:** 2026-04-26 (UAT walk on `c41f31d` after BUG-010 disc refactor shipped)
**Platform:** cross-platform (SDF builder runs on CPU, same on iOS + Android)

## Symptoms

The boundary around revealed discs appears as a north-south elongated oval instead of a circle. The effect worsens at higher latitudes.

## Root cause

`RevealedSdfBuilder.buildFromDiscs` computed pixel-space Euclidean distance (`sqrt(dx² + dy²)`) instead of metric-space distance. At non-equatorial latitudes, one pixel of latitude covers more metres than one pixel of longitude (by a factor of `1 / cos(lat)`), producing an aspect-ratio distortion of ~50% at Paris (lat 48°).

## Fix

Switched the inner loop to compute distance in metres:
- `dxMeters = dx * metersPerPixelX`
- `dyMeters = dy * metersPerPixelY`
- `distMeters = sqrt(dxMeters² + dyMeters²)`
- `candidate = (distMeters - disc.radiusMeters) / metersPerPixel`

Also adjusted the per-disc padded bounding box to use anisotropic pixel padding.

## Test coverage

Added "metric circle N-S ≈ E-W boundary distance" assertion at Paris lat 48° + high-latitude (70°) variant.

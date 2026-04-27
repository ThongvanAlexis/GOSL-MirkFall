# BUG-014 — SDF rect offset rotated 90 degrees during pan at low zoom

**Status:** fixed
**Reported:** 2026-04-27 (UAT walk at zoom ~12.28 on iOS)
**Platform:** iOS (Impeller/Metal)

## Symptoms

When zoomed out to ~12.28 and panning, the revealed area (fog hole) offsets
from its correct geo-position in a direction rotated 90 degrees from the
expected one:

- Pan left  -> reveal shifts up   (expected: stays in place / shifts right)
- Pan right -> reveal shifts down
- Pan up    -> reveal shifts right
- Pan down  -> reveal shifts left

Centering with the centre button puts the reveal back to its correct place
(triggers SDF rebuild at current viewport -> identity sdfRect).

At high zoom (~15) the bug is imperceptible because the SDF debounce
window is short relative to viewport size, so the dynamic `sdfRect` never
deviates far from identity.

## Root cause

The GLSL shader `assets/shaders/atmospheric_fog.frag` declared the
`sampler2D uSdf` uniform BETWEEN the last float uniform
(`uBoundaryDensityBoost`, slot 36) and the `vec4 uSdfRect` (slots 37-40).

On certain Impeller/Metal compilation paths, the interleaved sampler caused
the SPIR-V -> MSL transpilation to misalign the float slot counter for
`uSdfRect`, producing an off-by-one or axis-swap in how the shader read
the four rect components. The Dart side wrote `(x0, y0, xSize, ySize)` to
slots 37-40, but the shader consumed them with a shifted mapping that
rotated the dynamic offset by 90 degrees.

The identity rect `(0, 0, 1, 1)` masked the issue because all four
components are either 0 or 1 — the misalignment produced the same values
under many rotation/shift patterns. The bug only surfaced when the rect
carried non-trivial fractional origin values during active panning with a
stale SDF.

## Fix

Moved `uniform vec4 uSdfRect` declaration BEFORE `uniform sampler2D uSdf`
in the shader so all float-consuming uniforms are contiguous. The Dart-side
slot indices (37-40) and sampler index (0) are unchanged — the reorder
only affects the GLSL-to-SPIRV-to-MSL compilation path.

Added diagnostic logging in `_computeSdfRect` (both atmospheric and
heavenly renderers) at INFO level, throttled to ~1 Hz, so non-identity
sdfRect values are visible in the device log for future debugging.

## Files modified

- `assets/shaders/atmospheric_fog.frag` — reorder uSdfRect before sampler
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — diagnostic log
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — diagnostic log

## Verification

Rebuild and test on iOS at zoom ~12.28: pan in all 4 cardinal directions
and verify the reveal stays geo-pinned (no offset, no rotation).

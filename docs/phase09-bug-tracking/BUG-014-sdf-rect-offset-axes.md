# BUG-014 — SDF rect offset rotated 90 degrees during pan at low zoom

**Status:** ✅ fixed — `d05dbb2`
**Reported:** 2026-04-27 (UAT walk at zoom ~12.28 on iOS, testing BUG-012 sdfRect fix)
**Platform:** iOS (Impeller/Metal) — Android (Skia/OpenGL) was not affected

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

## Investigation findings

The 90-degree rotation symptom was the key diagnostic clue. The sdfRect has 4 components: `(x0, y0, xSize, ySize)`. A 90-degree rotation of the offset direction means X and Y components were being swapped or shifted by one slot.

The Dart-side code was verified to write the correct values to the correct slot indices (37-40) via the diagnostic logging added in BUG-012 iteration 2. The mismatch had to be on the shader consumption side.

Inspection of the GLSL source revealed the `sampler2D uSdf` declaration sitting between float uniforms. On Skia/OpenGL (Android/desktop), the GLSL compiler handles this correctly — samplers are in a separate binding namespace. On Impeller/Metal, the SPIR-V -> MSL transpilation path counts float slots sequentially, and the interleaved sampler caused the slot counter to drift by one, swapping the X and Y components of `uSdfRect`.

This was confirmed by the observation that Android never exhibited the bug, and that the identity rect `(0, 0, 1, 1)` masked the issue — the swapped identity is still identity.

## Strategy / Fix

Moved `uniform vec4 uSdfRect` declaration BEFORE `uniform sampler2D uSdf`
in the shader so all float-consuming uniforms are contiguous. The Dart-side
slot indices (37-40) and sampler index (0) are unchanged — the reorder
only affects the GLSL-to-SPIRV-to-MSL compilation path.

This approach was chosen over alternatives (e.g. swapping the Dart-side slot assignments) because keeping all float uniforms contiguous before any sampler declarations is the documented best practice for cross-backend shader compatibility. It prevents the issue from recurring if more float uniforms are added later.

Added diagnostic logging in `_computeSdfRect` (both atmospheric and
heavenly renderers) at INFO level, throttled to ~1 Hz, so non-identity
sdfRect values are visible in the device log for future debugging.

## Commits

```
d05dbb2  fix(09-bug-014): correct sdfRect axis mapping (X↔Y swap during pan)
```

## Files modified

- `assets/shaders/atmospheric_fog.frag` — reorder uSdfRect before sampler
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — diagnostic log in `_computeSdfRect`
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — parallel diagnostic log

## Test coverage

No automated regression test was added because the bug is Impeller/Metal-specific and requires GPU shader compilation to reproduce. The diagnostic logging (throttled to ~1 Hz) serves as a runtime assertion — non-identity sdfRect values are now visible in device logs, making future axis-mapping regressions immediately diagnosable.

Verification was done manually: rebuild and test on iOS at zoom ~12.28, pan in all 4 cardinal directions, confirm the reveal stays geo-pinned (no offset, no rotation).

## Known follow-ups

- [ ] Consider adding a CI shader compilation smoke test for Impeller/Metal to catch uniform slot misalignment at build time rather than runtime
- [ ] Document the "float uniforms before samplers" rule in a shader authoring guide if more shaders are added

## Links

- **BUG-012** — the sdfRect mechanism that exposed this bug was introduced in BUG-012 iteration 2 (`c0c14a6`)
- **BUG-011** — another coordinate-space issue in the SDF pipeline (oval distortion from pixel-vs-metre space)

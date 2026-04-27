# BUG-013 — Fog disappears when blue dot is off-screen

**Status:** fixed -- `743750d`
**Reported:** 2026-04-27 (UAT walk on `c0c14a6` after BUG-010 Option B disc refactor shipped)
**Platform:** cross-platform (all 4 renderers affected: atmospheric, heavenly_clouds, candlelight, solid_fill)

## Symptoms

When the user pans the map so the GPS blue dot (and all revealed area) is no longer visible, the fog disappears entirely — the whole map shows as clear/revealed. Moving back to have the blue dot in view restores the fog.

## Root cause

Post-BUG-010 regression. All 4 renderers had an early-return guard:

```dart
if (context.discs.isEmpty) {
  return; // ← skip rendering entirely
}
```

When the user pans away from the walk path, ALL revealed discs fall outside the viewport bbox. `discsInBbox` returns an empty list. The renderers early-returned without painting anything — no fog at all. The map showed through completely clear.

The SDF builder (`buildFromDiscs`) and the clip-path builder (`buildViewportFogClipPathFromDiscs`) both correctly handle empty discs: they produce all-fog output (byte 255 SDF / full viewport rect). The bug was exclusively in the renderers skipping the call entirely.

## Fix

Removed the `discs.isEmpty` early-return from all 4 renderers. With empty discs, `buildViewportFogClipPathFromDiscs` returns the full viewport rect (= everything is fog, nothing revealed). The fallback/shader paint paths then cover the entire viewport with fog — the correct behaviour.

No performance regression: painting a full-fog viewport (no disc holes to subtract) is actually cheaper than the normal disc-subtracted path. The SDF builder's empty-list fast path (`_emptySdfImage()`) runs in sub-millisecond time.

Updated 4 renderer tests to assert `greaterThan(500)` bytes (fog was painted) instead of `lessThan(500)` (no-op).

## Files modified

- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart`
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart`
- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart`
- `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart`
- `test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart`
- `test/infrastructure/mirk/candlelight_mirk_renderer_test.dart`
- `test/infrastructure/mirk/heavenly_clouds_mirk_renderer_test.dart`
- `test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart`
- `test/infrastructure/mirk/noise_overlay_test.dart` (comment update)
- `test/presentation/widgets/mirk_overlay_pointer_passthrough_test.dart` (comment update)

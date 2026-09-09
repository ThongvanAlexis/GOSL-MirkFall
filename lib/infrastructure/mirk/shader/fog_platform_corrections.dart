// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';

/// Result of [applyPlatformShaderCorrections]: the `uPixelOrigin` pair and
/// the four `uSdfRect*` scalars to forward to the shader on this platform.
typedef PlatformShaderCorrections = ({({double x, double y}) pixelOrigin, (double, double, double, double) sdfRect});

/// `uSdfRect*` on iOS / Impeller-Metal — identity (canonical V-down sampling).
const (double, double, double, double) kFogSdfRectIdentity = (0.0, 0.0, 1.0, 1.0);

/// `uSdfRect*` on Android / Impeller-Vulkan — pre-flips `sdfUv.y` so the
/// shader's `(fragUv - origin) / size` collapses to `1 - fragUv.y` (FOG-21).
const (double, double, double, double) kFogSdfRectAndroidVFlip = (0.0, 1.0, 1.0, -1.0);

/// Applies the two Android-only shader corrections (FOG-23 + FOG-21) as a
/// pure function of the raw `camera.pixelOrigin` and the platform flag.
///
/// Call it ONCE per paint on the raw `camera.pixelOrigin`: applying it twice
/// with `isAndroid: true` re-flips the sign (it is deliberately NOT
/// idempotent — see the test).
///
/// ## Why (POC commit `a73a0cc`, Pixel 4a / Adreno 618 / Android 13)
///
/// Both corrections share one root cause: Impeller-Vulkan and Impeller-Metal
/// disagree on Y handling, in two manifestations.
///
/// * **FOG-23 — `pixelOrigin.y` sign flip.** Every Dart-side input was proven
///   platform-identical (canvas scale 1 / shear 0, `pixelOrigin` evolving
///   consistently with the centre latitude, positive `uResolution`, matching
///   zoom, `FlutterFragCoord` Y-down on both — red-top / blue-bottom probe).
///   Yet the FOG-22 horizontal-stripe probe (same `worldPx` the noise samples)
///   drifted OPPOSITE the basemap during pan on Android only. The only place
///   left is the impellerc → Vulkan/SPIR-V codegen of
///   `worldPx.y = fragCoord.y + uPixelOrigin.y`, which behaves as
///   `fragCoord.y - uPixelOrigin.y` on Adreno-Vulkan and not on Apple-Metal.
///   Passing `-y` to slot 4 double-inverts the codegen defect back to correct
///   on Android; iOS keeps the canonical positive value (render path
///   byte-identical to the validated build).
///
/// * **FOG-21 — `uSdfRect` V-flip.** Android Impeller-Vulkan samples
///   `ui.Image` textures V-up (`uv.y = 0` → bottom data row); iOS
///   Impeller-Metal samples V-down (canonical). The SDF builder writes row 0
///   = north, so on Android the disc at the north of the screen landed at the
///   south — a static vertical mirror of the boundary halo. `(0, 1, 1, -1)`
///   makes the shader's existing `sdfUv = (fragUv - origin) / size` collapse
///   to `sdfUv.y = 1 - fragUv.y`. Changing the VALUES of the four independent
///   scalar slots cannot re-introduce BUG-014 (which was about vec4 component
///   reordering next to a sampler); adding a new `uSdfVFlip` uniform instead
///   DID break Metal (POC `ab9670d`, reverted `0cd9994`) — the ABI stays at
///   exactly 42 floats + 1 sampler.
///
/// Both are PERMANENT corrections of a codegen / sampling discrepancy, not
/// temporary workarounds — never remove them "to clean up".
///
/// Invariant 9 (reformulated Phase 09.1): `sdfRect` is identity on iOS and
/// `(0, 1, 1, -1)` on Android, decided by the platform alone — there is never
/// a dynamic viewport → SDF remapping.
PlatformShaderCorrections applyPlatformShaderCorrections({required ({double x, double y}) pixelOrigin, required bool isAndroid}) {
  if (!isAndroid) {
    return (pixelOrigin: pixelOrigin, sdfRect: kFogSdfRectIdentity);
  }
  return (pixelOrigin: (x: pixelOrigin.x, y: -pixelOrigin.y), sdfRect: kFogSdfRectAndroidVFlip);
}

/// Raw `camera.pixelOrigin` reconstructed from a corrected [context] (Phase 09.1-06 stub — RED).
({double x, double y}) rawPixelOriginOf(MirkPaintContext context) => throw UnimplementedError('09.1-06 Task 2');

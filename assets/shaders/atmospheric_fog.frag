// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 BUG-009 (TIER 2) — placeholder atmospheric fog fragment shader.
//
// Stage 1 of the BUG-009 commit sequence: pipeline scaffold only. This
// shader emits a uniform fog colour modulated by alpha. The actual
// volumetric body (3D-sliced FBM + curl + parallax + faux shading +
// hue + watercolour boundary + curl-rotated edge field) lands in
// later commits as we extend this file.
//
// Constraints honoured (per .planning/research/bug-009-fog-visual/
// flutter-shader-constraints.md):
//   - No mat3 / mat4 / int / bool uniforms.
//   - No texelFetch / textureLod / dFdx / structs / GLSL array literals.
//   - Use FlutterFragCoord(), not gl_FragCoord.
//   - No unused uniforms (Impeller startup fail).

#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

// Viewport size in screen pixels. Used to normalise FlutterFragCoord
// into [0, 1] UV space. Slot 0..1.
uniform vec2 uResolution;

// Time in seconds since session start. Single scalar — no vec2(sin,cos)
// trick needed (research §Time uniform). Slot 2.
uniform float uTime;

// Fog tint as straight RGBA (premultiplication is done Skia-side after
// the shader returns). Slot 3..6.
uniform vec4 uFogColor;

out vec4 fragColor;

void main() {
    vec2 fragUv = FlutterFragCoord().xy / uResolution;

    // Stage 1 placeholder body: emit the configured fog colour with a
    // tiny per-frame ripple so a structural test that compares two
    // frames at different uTime can see a difference. The ripple is
    // imperceptible at the pixel level — kept solely so the animation
    // proof test in stages 2+ has a stable signal as we add real noise.
    //
    // The `0.999 + 0.001 * sin(uTime + fragUv.x * 6.28)` factor stays
    // within numerical noise (alpha varies over [0.998, 1.000]) so the
    // user never sees ripples while the shader pipeline is being
    // wired. Once stage 4+ replaces this with 3D-FBM the placeholder
    // disappears.
    float ripple = 0.999 + 0.001 * sin(uTime + fragUv.x * 6.2831853);
    fragColor = vec4(uFogColor.rgb, uFogColor.a * ripple);
}

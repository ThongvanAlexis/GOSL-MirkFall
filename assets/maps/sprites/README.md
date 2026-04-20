# `assets/maps/sprites/` — Protomaps basemaps-assets sprites (placeholder)

Same placeholder convention as `glyphs/`. The prepare-style script
populates this directory with `sprite.json`, `sprite.png`, and
`sprite@2x.png` copied verbatim from the pinned upstream clone.

Licensing: CC0-1.0 (sprites waive all rights).
Documented in DEPENDENCIES.md "Bundled assets (non-pub)" section.

At runtime, the style.json references these via
`asset:///assets/maps/sprites/sprite` (maplibre_gl appends `.json` /
`.png` / `@2x.png` automatically).

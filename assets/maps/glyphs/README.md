# `assets/maps/glyphs/` — Protomaps basemaps-assets fonts (placeholder)

This directory is intentionally a placeholder in Phase 07-01. The first
plan that renders a live MapLibre map (Phase 07 plan 07-06) will run
`dart run tool/prepare_style.dart --source <path-to-clone>` against a
pinned clone of github.com/protomaps/basemaps-assets and populate this
tree with `<fontstack>/<range>.pbf` glyph packs.

Licensing: SIL Open Font License 1.1 (`fonts/OFL.txt` upstream).
Documented in DEPENDENCIES.md "Bundled assets (non-pub)" section.

At runtime, the style.json references these via
`asset:///assets/maps/glyphs/{fontstack}/{range}.pbf`.

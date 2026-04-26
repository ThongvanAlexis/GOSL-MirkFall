# BUG-006 — Le reveal s'affiche en grille de carrés au lieu d'un cercle smooth

**Status:** fixed (boundary smoothing seulement — les carrés à petit rayon persistent ; suivi sous BUG-010)
**Reported:** 2026-04-25 (iOS UAT walk après build `0b96197`)
**Platform:** iOS sideloaded
**Phase context:** Comportement initial Phase 09 — exposé après le fix BUG-003 qui a retiré le `MaskFilter.blur` (parce qu'il causait le damier dans le mode per-tile). Sans feather, les arêtes des cells du subgrid sont visibles.

## Comportement attendu

Comme dans les jeux (fog of war classique) : le contour entre fog et zone révélée doit être circulaire / smooth. L'utilisateur a un rayon de reveal de 20 m autour de sa position, ça doit ressembler à un disque, pas à une grille de carrés.

## Comportement observé

Le contour fog/clear suit les arêtes des cells du subgrid 64×64 — c'est une approximation "stair-step" d'un cercle, visiblement carré aux yeux du user.

## Hypothèse forte

Les cells du subgrid sont par nature carrées. Sans feather/blur sur le path, le contour est rectilinéaire. Le `MaskFilter.blur` avec `BlurStyle.inner` qu'on avait avant le fix BUG-003 produisait un feather mais aussi le damier (parce qu'il s'appliquait sur 4096 sub-rects).

**Maintenant que le path est viewport-level (un seul path, RLE-encoded holes — beaucoup moins d'arêtes), un `MaskFilter.blur(BlurStyle.normal, sigma)` devrait :**
- Smoother les coins carrés des holes en arrondis circulaires (vu que les arêtes des holes sont peu nombreuses et que le blur agit globalement sur le path)
- Ne PAS produire le damier (parce qu'il n'y a plus 4096 sub-rects par tile, juste un blob global)

À tuner : la valeur de `sigma`. Trop petite = encore carré, trop grande = fog déborde dans la zone révélée. Un sigma de l'ordre de la moitié d'une cell (~5–10 px à z=15) devrait donner un feather visuellement rond.

## Diagnostic à confirmer

- Lire `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` (post-fix BUG-003) — confirmer qu'il n'y a plus de MaskFilter.blur dans le Paint actuel.
- Vérifier que `mirk_overlay_multi_tile_seam_test.dart` reste vert quand on rajoute un MaskFilter.blur normal : le seam test asserte alpha > 150 sur les jointures de tiles, et un blur normal SHOULD pas réintroduire le damier puisque le path est unifié.
- Tester localement un sigma de 5, 8, 10 et choisir celui qui donne un visuel rond sans bouffer la zone révélée.

## Solutions

1. **Re-introduire `MaskFilter.blur(BlurStyle.normal, sigma)`** sur le Paint du fog dans atmospheric/candlelight/heavenly_clouds/solid renderers. La constante `kMirkAtmosphericFeatherSigma` (et équivalents) existe déjà dans `lib/config/constants.dart` — l'utiliser.
2. Si le seam test fail avec un blur normal, fall back sur `BlurStyle.outer` (blur extérieur seulement — fait dilater la zone fogged sans manger le revealed).

## Lien avec BUG-004 issue A (noise)

Si on rajoute le shader noise dans le clip path ET un MaskFilter.blur sur le path, on obtient simultanément :
- Texture animée à l'intérieur du fog (BUG-004)
- Edges rondes au contour du reveal (BUG-006)
- Pas de damier (parce que le path est viewport-level, pas per-tile)

Les fixes pour BUG-004 et BUG-006 touchent les MÊMES fichiers (les 4 renderers) — ils peuvent être landed ensemble dans un seul commit ou en deux commits atomiques séparés selon préférence.

## Resolution

**Resolved:** 2026-04-25

### Findings on the diagnostic hypothesis

The bug-doc hypothesis assumed `MaskFilter.blur` had been REMOVED by the BUG-003 fix. Reading the post-BUG-003 code showed it was still there — the 3 animated renderers all carried `MaskFilter.blur(BlurStyle.inner, sigma)`. So the actual problem was the BlurStyle, not the absence of the mask filter.

`BlurStyle.inner` erodes alpha INWARD from each path edge, leaving the hole side of the boundary perfectly sharp. From the user's eye, this means the fog has a soft outer edge but the cleared cells still read as a 64×64 grid of squares.

### Fix

Switched `BlurStyle.inner` → `BlurStyle.normal` in the 4 renderers. Normal blur smears alpha symmetrically across the boundary, so fog leaks slightly into the reveal cells, rounding their corners into a circle approximation (classic fog-of-war visual).

Solid renderer was added to the mask-filter cohort for visual consistency — it had no MaskFilter pre-fix because it was the minimalist "proof of seam" variant. Sigma derived per-frame from canvas height × hard-coded `_kSolidFeatherCellFraction = 0.1` (matches the animated-variant defaults).

Sigma values were NOT changed — kept at the existing `featherRadiusFraction × cellSize × pixelRatio`, conservative enough that fog leak does not visibly shrink the cleared zone. If iOS UAT reports the reveal still looks square, the next iteration is to bump `featherRadiusFraction` from 0.1 → 0.15-0.2 on atmospheric/candlelight.

### Test coverage

- `test/presentation/widgets/mirk_overlay_rounded_reveal_test.dart` (NEW) — paints a single 4-pixel revealed cell hole inside a fully-fogged tile and asserts ≥ 3 intermediate-alpha pixels along a scanline through the hole edge. Passes on all 4 renderers post-fix; would fail with `BlurStyle.inner` (transition < 2 pixels because alpha falls off only on the fog side).
- `test/presentation/widgets/mirk_overlay_multi_tile_seam_test.dart` (existing BUG-003 regression) — re-verified, still passes. `BlurStyle.normal` does not break the seam invariant because the seam pixels lie INSIDE the fog silhouette, far from any boundary that the blur erodes.

### Files changed

- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` (BlurStyle.inner → BlurStyle.normal + docstring)
- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart` (idem)
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` (idem)
- `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart` (added MaskFilter.blur with cell-derived sigma)
- `test/presentation/widgets/mirk_overlay_rounded_reveal_test.dart` (NEW regression test)

### Verification

- `flutter analyze --fatal-warnings --fatal-infos` on the 5 changed files — clean.
- `dart format --line-length 160 --set-exit-if-changed` on the 5 changed files — clean.
- Full mirk renderer + overlay test suite (83 tests) — all green.

## Followup post-walk 2026-04-25

Les UAT walks de fin de journée (pendant l'itération BUG-009) confirment que le `BlurStyle.normal` lisse bien les coins arrondis du blob global, mais à un rayon de reveal de 25 m la zone clear reste **visiblement carrée** (en réalité un "+"). Le boundary smoothing ne suffit pas — c'est un défaut structurel de la couche de stockage, pas du rendu.

**Diagnostic architectural :** la data layer stocke les reveals en grille 64×64 cellules par parent tile au zoom 14 → cellules de ~19 m. Un reveal de rayon 25 m ne couvre que ~1.5 cellule, ce qui produit intrinsèquement une forme blocky (un "plus" de 5 cells en croix) à toutes les couches de rendu en aval. SDF parfait + blur parfait ne peuvent rien y faire : 5 cellules alignées sur une grille lisent comme un carré aux yeux du user.

**Conséquence :** le fix `BlurStyle.inner → BlurStyle.normal` reste pertinent (il smoothe les blobs plus larges, et reste utile pour le fallback path quand le shader TIER 2 n'est pas dispo) mais ne résout pas le symptôme à petit rayon.

**Suivi :** voir **`BUG-010-cell-grid-resolution-blocky.md`**. Le fix retenu par l'utilisateur est une refonte de la data layer en géométrie continue (option B — liste de discs `(lat, lon, radius, timestamp)` + rendu via union-of-discs SDF). Doit lander avant Phase 10 (Review Gate Fog).

Pas de changement de code sur ce ticket — le scope BUG-006 est officiellement fermé sur le périmètre boundary smoothing. Les carrés à petit rayon sont migrés vers BUG-010.

### Update 2026-04-26 — confirmation que le bandaid post-process ne suffit pas

Une tentative de fix purement-rendu sur le SDF (Gaussian post-chamfer σ=1.0, commit `a9c7ced`) a été reverted (`118b95a`) parce qu'elle lissait les corners mais pas le caractère rectangulaire des cells, et changeait l'aspect global du mirk. **Confirme que le périmètre BUG-006 boundary-smoothing est saturé** — toute amélioration supplémentaire passe par BUG-010. Une nouvelle Option D ("circle rasterisation in SDF builder") est à l'étude dans BUG-010 comme stop-gap intermédiaire avant le rework Option B complet.

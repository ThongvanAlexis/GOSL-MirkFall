# BUG-003 — Mirk overlay s'affiche en damier (interstices entre tiles), carte impossible à manipuler, zoom initial trop bas

**Status:** fixed (issues A + B + C + D — 2026-04-25)
**Reported:** 2026-04-25 14:00 UAT walk
**Platform:** iOS (sideloaded, real device)
**Build:** depuis le run CI `24930020857` (Phase 09 + quick-1 SHA-print)
**Screenshot:** `GH_builds/latest/6488f18d-f3bb-47d2-8df9-6773769aa165.png`

## Comportement attendu

1. Au lancement, la carte est zoomée à `z=15` (assez proche pour voir les détails et le moving-noise effect du fog atmosphérique).
2. Le `MirkOverlay` recouvre TOUTE la zone non-révélée du viewport sans interstices : le brouillard est continu.
3. Les renderers atmospheric / candlelight / heavenly_clouds animent la zone de fog.
4. La carte sous-jacente reste manipulable (pan / pinch zoom / rotate) — l'overlay ne capture PAS les gestes.

## Comportement observé (4 issues distinctes liées)

### Issue A — Mirk en damier avec interstices brillants

Le screenshot montre une grille de **carrés noirs séparés par des lignes claires**. Les "lignes" entre tiles laissent voir la carte sous-jacente (route / contour à fort contraste). Le pattern est régulier à l'échelle des tiles MapLibre — donc le renderer peint UNIQUEMENT à l'intérieur du bbox de chaque `VisibleMirkTile` retourné par le provider, sans couvrir le viewport entier.

### Issue B — Le mode `solid` est correct (tout noir, pas de damier)

Confirmé par le user : "only the solid mode appear as black without squares". Donc le bug n'est PAS dans la chaîne provider/factory/active-renderer (le solid renderer reçoit le même `MirkPaintContext` et peint correctement). Le bug est dans la stratégie de paint des renderers atmospheric / candlelight / heavenly_clouds : ils itèrent par-tile au lieu de peindre full-viewport puis soustraire.

### Issue C — Carte gelée (pan + zoom impossibles)

Aucune interaction MapLibre ne fonctionne après le mount du `MirkOverlay`. Hypothèse forte : le `CustomPaint` du `MirkOverlay` (ou son `RepaintBoundary` parent dans `map_screen.dart:279`) intercepte tous les pointer events. Probablement il manque un `IgnorePointer` autour de l'overlay.

### Issue D — Zoom initial trop bas (visible noise effect invisible à ce niveau)

Le user ne voit pas le moving-noise atmospheric, mais il pense que c'est juste à cause du zoom trop bas. Demande : la carte devrait s'ouvrir à `z=15` par défaut.

## Hypothèses (par issue)

### Issue A + B : provider sparse + paint per-tile

`visibleMirkTilesProvider` retourne uniquement les tiles présentes dans `RevealedTileStore` (donc sparse — sauf le tile où l'utilisateur a fait des fixes). Les renderers atmospheric / candlelight / heavenly_clouds itèrent sur cette liste sparse pour peindre, et laissent des trous là où il n'y a pas de tile stockée.

Solution probable :
- Soit le provider retourne UN entry par tile-slot du viewport (avec `cellsRevealedBitmap = all-zero` pour les tiles non touchées)
- Soit les renderers peignent d'abord un full-viewport rect noir/fog puis soustraient les cells revealed

Le solid renderer marche parce qu'il est trivial (paint(Rect viewport, paint)) et ignore probablement la liste de tiles. À confirmer.

### Issue C : gestures interceptés par CustomPaint

Le `RepaintBoundary` n'intercepte pas les gestures (par design), mais le widget en dessous peut. Si `MirkOverlay` est un `CustomPaint` direct ou un `Container` opaque, il bouffe les events. Solution : envelopper l'overlay dans `IgnorePointer(ignoring: true, child: MirkOverlay(...))`.

### Issue D : zoom initial config

Cherchable via `grep -n "initialZoom\|initialCameraPosition\|defaultZoom" lib/`. Probablement une constante dans `lib/config/constants.dart` ou un literal dans `map_screen.dart`.

## Diagnostic à mener

1. **Lire `lib/presentation/widgets/mirk_overlay.dart`** : qu'est-ce que le `paint()` fait quand visibleTiles est sparse ? Itère-t-il par tile ? Peint-il un fond plein viewport ?
2. **Lire `lib/application/providers/visible_mirk_tiles_provider.dart`** : retourne-t-il les tiles stockées seulement, ou tous les slots du viewport ?
3. **Lire `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` + `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart`** : comparer leurs stratégies de paint pour confirmer que solid peint full-viewport et que atmospheric peint per-tile.
4. **Lire `lib/presentation/screens/map_screen.dart` autour de la ligne 279** : le RepaintBoundary / MirkInitialRevealFade / MirkOverlay sont-ils dans un IgnorePointer ?
5. **Trouver le zoom initial** : grep pour `initialZoom`, `13.0`, `cameraOptions.zoom`, etc.

## Logs pertinents

À demander au user après diagnostic — voir si les logs mentionnent :
- `mirk_overlay paint: visibleTiles=N viewport=[...]` (si on log ça)
- Le commit SHA au démarrage (pour confirmer le bon build)

## Resolutions

(à compléter par l'agent diagnostic)

## Diagnostic Findings

Investigation date: 2026-04-25. Debug session: `.planning/debug/bug-003-mirk-tile-gaps.md`.

### Hypothèses initiales invalidées

1. "Le provider retourne une liste sparse" — **FAUX**. `lib/application/providers/visible_mirk_tiles_provider.dart:65-77` itère explicitement tous les slots `(x, y)` du viewport bbox et synthétise un `Uint8List(512)` à zéro pour chaque slot non présent en store. La liste est dense.
2. "Solid utilise une stratégie full-viewport, atmospheric per-tile" — **FAUX**. `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart:54-61` itère également par tile et appelle le même `buildUnrevealedCellsPath`. La stratégie est identique.

### Issue A — Mirk en damier (atmospheric / candlelight / heavenly_clouds)

**Root cause:** `MaskFilter.blur(BlurStyle.inner, featherSigma)` appliqué à un Path composé de 4096 sous-rectangles (cells) par tile.
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart:93` (`..maskFilter = MaskFilter.blur(BlurStyle.inner, featherSigma)`)
- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart:90` (idem)
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart:83` (idem)
- `lib/infrastructure/mirk/tile_cell_iteration.dart:54` (`path.addRect(...)` 4096 fois)

`BlurStyle.inner` érode l'alpha vers l'intérieur de **chaque arête** du path, y compris les arêtes internes partagées entre cells. À l'échelle macro, l'effet le plus visible est aux frontières entre **parent tiles** : chaque tile dessine son propre Path avec son propre maskFilter, donc l'érosion se cumule des deux côtés de la frontière, produisant les bandes claires régulières de la capture (~2 cols × 4 rows = espacement de tiles parentes z=14 vues à z=13). Solid_fill ne pose pas le problème car son Paint n'a aucun maskFilter.

**Confidence:** high. Vérifiable en supprimant la ligne `..maskFilter = ...` dans l'un des renderers cassés et en confirmant que le damier disparaît.

**Recommended fix (au choix selon le visuel souhaité):**
- (option simple) Retirer `MaskFilter.blur(BlurStyle.inner, ...)`. Le feather n'apparaîtra plus mais le brouillard sera continu.
- (option correcte) Appliquer le feather **par tile** via `canvas.saveLayer` + `Paint..imageFilter = ImageFilter.blur(...)` sur l'union complète du fog (un seul path full-viewport composé en soustrayant les cells revealed), pas par cell. Ça suppose de réécrire `buildUnrevealedCellsPath` pour produire une stratégie "viewport rect minus revealed cells" plutôt qu'une union des unrevealed cells.
- (option pragmatique) Garder le mask filter mais sur un path simplifié : un seul rect par run horizontal de cells unrevealed (au lieu de cells individuelles), ce qui supprime les arêtes internes. Réécriture de `buildUnrevealedCellsPath` pour faire du run-length encoding par row.

**Risk / scope:** Touche `tile_cell_iteration.dart` (helper partagé par les 4 renderers, dont solid). Implications de tests : le test `mirk_overlay_feather_test.dart` actuel ne couvre QUE "ne throw pas" — il ne détecte pas le damier. Il faut ajouter un golden-test multi-tiles qui rend ≥ 2 tiles adjacentes et vérifie qu'il n'y a pas de pixels du basemap visibles dans la bande de 2 px autour de la frontière.

### Issue B — Solid mode correct

Pas un bug en soi : confirmation que la stratégie de path et le provider fonctionnent. Solid n'applique pas de `MaskFilter`, donc les arêtes internes du path ne sont pas érodées. Aucun fix requis pour cette issue, elle disparaît avec le fix de A.

**Confidence:** high.

### Issue C — Gestures gelés

**Root cause:** Le `CustomPaint(size: Size.infinite, painter: _MirkPainter(...))` dans `lib/presentation/widgets/mirk_overlay.dart:83-102` rend un `RenderCustomPaint` qui hit-test comme opaque par défaut quand un painter est fourni. Aucun `IgnorePointer` ni `HitTestBehavior.translucent` n'est positionné — l'overlay capte tous les pointer events. Le `RepaintBoundary` parent (`map_screen.dart:252`) ne change rien : il n'intercepte pas les pointers, mais ne les laisse pas passer non plus quand son enfant les capture.

**Confidence:** high.

**Recommended fix:** Wrapper le `CustomPaint` dans `IgnorePointer(ignoring: true, child: ...)`. Une seule ligne dans `mirk_overlay.dart` autour du `return CustomPaint(...)`.

**Risk / scope:** Local, zéro impact sur le rendu. Test à ajouter : un widget test qui pump un `MirkOverlay` au-dessus d'un `GestureDetector` et vérifie que `tester.tap` sur l'overlay déclenche bien le handler du detector en-dessous.

### Issue D — Zoom initial trop bas

**Root cause:** `lib/config/constants.dart:235` — `const int kInitialSessionMapZoom = 13;`. Utilisé en `lib/presentation/screens/map_screen.dart:211` (initialCamera) et :234 (resolveForPoint).

**Confidence:** high.

**Recommended fix:** Changer la constante de `13` à `15`. Aucun autre site d'appel à modifier.

**Risk / scope:** Trivial. Vérifier que le bundle PMTiles couvre bien z=15 (sinon le rendu sera blurry au démarrage). À tester sur device.

### Ordre de fix recommandé

1. **Issue C** (IgnorePointer) — trivial, débloque le UAT ; permet de tester les autres fixes en panant la carte.
2. **Issue D** (zoom 13 → 15) — trivial, change la perspective qu'on a pour évaluer A.
3. **Issue A** (mask filter sur cells) — le plus structurel, à faire avec attention. Choisir entre les 3 options selon le rendu visuel souhaité ; l'option "viewport rect minus revealed" est la plus correcte sémantiquement et probablement plus performante (un seul drawPath au lieu de N paths feathered).

Issue B se résout automatiquement avec le fix de A.

### Couverture par les tests existants

Les tests `test/presentation/widgets/mirk_overlay_*.dart` n'auraient PAS attrapé ces bugs :

- **mirk_overlay_composition_test.dart** + **mirk_overlay_feather_test.dart** : utilisent un seul `_tile()` dans une `SizedBox(256×256)`. Pas de scène multi-tiles → pas de frontière visible où le damier apparaîtrait. Les assertions sont `paintCallCount > 0` et "ne throw pas" — aucune inspection des pixels rendus.
- Aucun test golden ne compare l'output rendu à une image de référence.
- Aucun test n'exerce un `GestureDetector` sous le `MirkOverlay` pour valider la pass-through des pointers.

Pour combler le gap : (1) golden test multi-tiles 2×2 avec viewport bbox réelle (pas de pixel basemap visible entre tiles), (2) pointer pass-through test (overlay au-dessus d'un GestureDetector avec onTap counter).

## Resolution

**Resolved:** 2026-04-25 (same day as report)

### Issue C + D — IgnorePointer wrapper + zoom 13 → 15

**Commit:** `6298f05` — `fix(09-bug-003): IgnorePointer on mirk overlay + bump initial zoom 13 to 15`

- `lib/presentation/screens/map_screen.dart` — wrapped `RepaintBoundary > MirkInitialRevealFade > MirkOverlay` in `IgnorePointer(child: ...)`. The CustomPaint's default opaque hit-test (when a painter is supplied) no longer intercepts pointer events; pan / pinch / zoom on the MapLibre platform view below now work normally.
- `lib/config/constants.dart:235` — `kInitialSessionMapZoom` changed from `13` to `15`. Map opens close enough that the 20 m reveal radius is clearly visible AND the atmospheric fog's noise effect resolves at a usable scale.
- `test/constants_test.dart` — assertion updated to match the new value.

### Issue A + B — damier pattern at parent-tile seams

The diagnostic findings above identified `MaskFilter.blur(BlurStyle.inner, ...)` over a per-cell-rects path as the suspected root cause. The actual root cause turned out to be slightly different: Skia's inner-blur applies to the rasterised silhouette (the union of the cell rects forms ONE filled blob, internal edges between abutting rects collapse), so the cell-grid-internal erosion is a non-issue. The visible "damier" was driven by **per-tile feather cumulation at parent-tile seams** — each adjacent tile drew its own path with its own MaskFilter pass, and at the seam BOTH tiles eroded alpha inward, halving the visible alpha there.

The fix landed in two atomic commits:

1. **`01820b4`** — `fix(09-bug-003): rewrite mirk fog path to "tile rect minus revealed cells"`
   Replaced `buildUnrevealedCellsPath` (union of 4096 cell rects) with `buildFogClipPath` (single path = tile rect minus run-length-encoded revealed-cell holes). 6 new unit tests for the helper. Per-tile rendering with this helper is still flawed at parent-tile seams — see commit 2.

2. **`2811900`** — `fix(09-bug-003): switch all mirk renderers to viewport-level fog path`
   Added `buildViewportFogClipPath` which composes ONE path covering the union of every visible tile rect minus every revealed-cell hole across every visible tile. All 4 renderers now emit ONE `canvas.drawPath` per frame. The MaskFilter applies to the global silhouette only — no per-tile seam erosion. Side effect on atmospheric / heavenly_clouds: per-parent-tile alpha modulation is replaced with a single time-evolving sample (uniform fog density evolving over time). Solid renderer also adopts the viewport-level path for consistency (saves N-1 drawPath calls per frame, never showed the bug).

### Regression test coverage

**Commit `2811900`** added `test/presentation/widgets/mirk_overlay_multi_tile_seam_test.dart`. Paints each of the 3 mask-filtered renderers on a 2×2 fully-fogged tile layout (512×512 canvas, pixelRatio=4 for realistic feather scale) and asserts the minimum alpha along the seamline x=256 / y=256 stays above 150. Pre-fix per-tile rendering produces ~79 at the seam; post-fix the seam is inside the fog union → ~250.

**Commit `a66cb24`** added `test/presentation/widgets/mirk_overlay_pointer_passthrough_test.dart`. Places `MirkOverlay` (wrapped in `IgnorePointer`) over a `GestureDetector(onTap: ...)` in a Stack and asserts taps reach the detector — both single tap and a 5-tap stress sequence. Discrimination verified: removing the IgnorePointer in the test fixture causes tapCount to stay at 0.

### Files changed

- `lib/config/constants.dart` (zoom 13 → 15)
- `lib/presentation/screens/map_screen.dart` (IgnorePointer wrapper)
- `lib/infrastructure/mirk/tile_cell_iteration.dart` (rewrite + new viewport-level helper)
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` (viewport-level fog)
- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart` (viewport-level fog)
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` (viewport-level fog)
- `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart` (viewport-level fog, consistency)
- `tool/fixtures/build_50k_tiles.dart` (docstring reference update)
- `test/constants_test.dart` (zoom assertion update)
- `test/infrastructure/mirk/tile_cell_iteration_test.dart` (new — 6 unit tests for `buildFogClipPath`)
- `test/presentation/widgets/mirk_overlay_multi_tile_seam_test.dart` (new — seam regression test)
- `test/presentation/widgets/mirk_overlay_pointer_passthrough_test.dart` (new — IgnorePointer regression test)

### Verification

- `flutter analyze --fatal-warnings --fatal-infos lib/ test/` — clean
- `dart format --line-length 160 --set-exit-if-changed lib/ test/` — clean
- `flutter test` — 940 / 940 pass (1 pre-existing flake in `download_soak_test.dart` unrelated to this fix; passes on rerun)

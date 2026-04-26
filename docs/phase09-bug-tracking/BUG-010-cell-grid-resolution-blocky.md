# BUG-010 — Reveal blocky par construction (data layer en grille de cellules 19 m)

**Status:** open / planned — **décision pending (2026-04-26 post-`118b95a`)** entre attaquer Option B directement OU shipper Option D ("circle rasterisation in SDF builder") comme stop-gap pretty-mais-hack avant la refonte propre. Voir nouvelle section "Option D — circle rasterisation in SDF builder (candidate intermediate fix)" plus bas.
**Reported:** 2026-04-25 (observation utilisateur pendant les UAT walks de l'itération BUG-009)
**Platform:** cross-platform (défaut data layer, pas de rendu)
**Phase context:** Surfacé par les walks BUG-009. Le fix BUG-006 (`BlurStyle.normal`) lisse les blobs larges mais à 25 m de rayon le reveal reste un "+" structurel.

## Comportement attendu

À tout rayon de reveal (notamment les 20–25 m du début de session), la zone clear lit comme un disque circulaire — pas comme un carré, pas comme une croix.

## Comportement observé

À petit rayon (25 m typique), le reveal apparaît comme un **"+" de 5 cellules en croix** ou un carré 2×2, selon l'alignement du fix GPS sur la grille. Le blur de boundary (BUG-006) arrondit les angles externes du blob mais ne peut pas transformer une croix de cellules carrées en disque.

## Root cause

La data layer stocke les reveals comme un **bitmap en grille 64×64 cellules par parent tile** au zoom 14. Soit :

- Tile de 4096 cellules (64 × 64)
- Parent tile z=14 ≈ 1224 m de côté à la latitude médiane → cellule ≈ **19 m**
- Reveal de rayon 25 m → couvre ~1.5 cellule de rayon → forme structurelle "+" (5 cellules : centre + 4 voisines)
- 30–35 m → 2 cellules de rayon → carré de 9 cellules
- 50 m → 2.6 cellules → octogone grossier

**À aucune couche de rendu (SDF, blur, shader) on ne peut transformer 5 cellules carrées alignées en un disque smooth.** Le bug est intrinsèque à la résolution du stockage.

## Solutions évaluées (avec arbitrage utilisateur)

### ✅ Option B retenue — Géométrie continue (union de discs)

Stocker les reveals non plus comme un bitmap mais comme une **liste de discs** : `(lat, lon, radius, timestamp)`. Rendu via **union-of-discs SDF** côté GPU (le shader TIER 2 sait déjà consommer un SDF — il faut juste régénérer le SDF depuis la géométrie au lieu du bitmap).

**Avantages :**
- Géométrie vraie → reveals parfaitement circulaires à tous les rayons
- Indépendant du zoom (pas de quantification)
- SDF se régénère naturellement depuis la liste

**Trade-off : storage croît linéairement avec la durée de session.** Walk normal à 5 m de distance filter ≈ 720 fix/h. Sur une session de 4h → ~2880 discs. Mitigations à concevoir :
- Index spatial (R-tree ou grid hashing) pour query par tile
- Compaction périodique : merge des discs qui se recouvrent à >X%
- Tile-aware indexing : chaque parent tile stocke ses discs locaux, pas la liste globale
- Snapshot/checkpoint : tous les N fix, on rasterise la zone fully-revealed dans un bitmap "consolidé" et on drop les discs absorbés

### ❌ Option A rejetée — Augmenter la résolution à 256×256 cells

Cellules de ~5 m, reveal de 25 m → 5 cellules de rayon → encore un disque discret de ~80 cellules. Moins blocky qu'aujourd'hui mais reste une grille discrète. **Rejeté** : l'utilisateur veut une vraie géométrie, pas une approximation plus fine.

### ❌ Option C rejetée — Hybride bitmap + couche de "recent fixes" en géométrie

Garder le bitmap 64×64 pour les zones "anciennes" (> N minutes) et superposer une couche de discs pour les fixes récents. Permet de borner le storage. **Rejeté** : 2 sources de vérité, complexité de merge à chaque transition, gain de storage pas justifié vu que l'option B + compaction donne le même résultat avec une seule source.

### ❌ Option E rejetée (anciennement Option D pré-2026-04-26) — Plus de blur sur la grille 19 m actuelle

Augmenter le sigma du `MaskFilter.blur` ou ajouter un post-process de smoothing en bord. **Rejeté** : ne résout pas le problème fondamental, et le blur agressif fait baver le fog dans la zone révélée (BUG-006 avait déjà ce trade-off). **Note** : tentative validée par `a9c7ced` (Gaussian σ=1.0 5×5 Pascal kernel sur le `signedDistPixels` post-chamfer, AVANT encoding uint8) — reverted dans `118b95a` parce qu'à la résolution réelle des cells (20-30 px SDF chacune) un blur radius 3-5 lisse les corners mais pas le caractère rectangulaire ; et changeait subtilement l'aspect global du mirk (boundary glow band étendue).

### 🟡 Option D — Circle rasterisation in SDF builder (candidate intermediate fix, 2026-04-26)

**Status:** decision pending — proposée comme stop-gap visuel "pretty-but-hack" avant la refonte Option B.

**Concept.** Au lieu de marquer `seed[idx] = 1` en rectangle-fill dans `_markTileInSeed` (`lib/infrastructure/mirk/sdf/revealed_sdf_builder.dart`), rasteriser chaque cell révélée en **circle** : un disque de rayon `cell-diagonal / 2` centré sur la projection du centre de la cell dans le SDF target. Coverage-based pour anti-alias les bords (fraction de pixel inside the circle → uint8 `[0..255]` au lieu de hard binary).

Le chamfer SDF voit alors des shapes **inhérence-circulaires** au lieu de rectangles, produit naturellement un distance field smooth round, et le boundary final lit comme un disque smooth.

**Trade-off accepté.** Les cells ne sont plus visiblement carrées au sens où elles l'étaient (c'était déjà le but), mais aux corners où 4+ cells se rencontrent il y a une légère **under-coverage** (les inscribed circles ne remplissent pas complètement l'union rectangulaire de leurs bbox). À la plupart des reveal-radii observés (25-50 m), l'under-coverage est visuellement invisible parce que le boundary est dominé par le watercolour smoothstep, pas par la silhouette exacte des cells. Sur des reveal-shapes très étroits/longs (couloir de 1 cell d'épaisseur), des "pinch points" peuvent apparaître.

**Coût.** ~30 lignes de change dans `_markTileInSeed`. Pas de nouvelle structure de données, pas de migration DB, pas de refonte du store. La signature publique du `RevealedSdfBuilder` ne bouge pas. Tests unitaires existants restent verts (l'output reste un float SDF) — ajouter un test de "circular reveal silhouette" sur un single-cell input.

**Pourquoi c'est intéressant maintenant.** Le user veut un fog visuellement acceptable RIGHT NOW pour pouvoir continuer les UAT walks et le Review Gate Phase 10. Option B (refonte data layer continue) prend 3-5 jours et bloque tout pendant ce temps. Option D donne le visual win immédiat ; le data layer rework peut prendre son temps après — Option B reste sur le roadmap pour la résolution propre (storage indépendant de toute grille, géométrie vraie même pour des reveal-shapes complexes, no quantisation au zoom-out).

**Comparaison rapide.**

| Dimension | Option B (data layer continu) | Option D (circle in SDF) |
|-----------|-------------------------------|--------------------------|
| Effort | 3-5 jours | ~1h |
| Visuel | parfait à tous les radii | smooth à radii usuels, pinch-points possibles sur shapes étroits |
| Storage | nouvelle table `revealed_disc` + migration | inchangé (toujours bitmap 64×64) |
| Bloque Phase 10 ? | oui pendant 3-5j | non |
| Résout structurellement ? | oui | non — bandaid sur le rendu |

**Décision pending — caller-context.** L'utilisateur a demandé "ok BUG-010 next ? ou hack D first ?" en fin de session du 2026-04-26 après le revert `118b95a`. Le prochain agent doit choisir avec lui :

1. **Voie A — skip Option D, attaquer Option B directement.** Plus propre, plus de risque de pinch-point résiduel, mais bloque tout pendant 3-5j.
2. **Voie B — ship Option D first.** Visual win immédiat, BUG-010 Option B reste programmé après pour la résolution structurelle. Cohérent avec la philosophie projet "logiciel utile, ship the simplest thing that works" — le bandaid est conscient et limité dans le temps.

À discuter avec le user au prochain tour.

## Effort & scope

C'est probablement une **mini-phase dédiée** (ex. Phase 9.1 ou 9.2 "gap-closure data-layer rework") plutôt qu'un fix in-place. Périmètre :

- **DB schema migration.** Nouvelle table `revealed_disc` (id, session_id?, lat, lon, radius_m, fixed_at). Migration depuis le bitmap existant : rasteriser → discrétiser en discs équivalents OU décommissionner les sessions existantes (acceptable en pré-release).
- **Refonte de `RevealedTileStore`.** Plus de `mergeMask(tileKey, Uint8List)` ; à la place `addDisc(lat, lon, radius, ts)` + `discsInBbox(bbox)`.
- **Refonte de `computeRevealMask` / SDF builder.** Au lieu de partir d'un bitmap pour calculer la chamfer 3-4 distance transform, partir directement de la liste de discs : `sdf(p) = min over discs of (dist(p, center) - radius)` — exactement ce qu'on appelle "union-of-discs SDF". Beaucoup plus propre.
- **Index spatial.** Au minimum un grid hash par parent tile pour limiter le nombre de discs évalués par sample du SDF builder.
- **Compaction.** Strategie à arrêter (online vs offline batch). Probablement offline lors du `flush` de la session.
- **Tests.** Unit tests sur `discsInBbox`, sur le SDF, perf check sur sessions longues (10k+ discs).
- **Perf check device.** S'assurer que le SDF builder reste < 16 ms par frame avec 5k+ discs dans le viewport.

Probablement **3–5 jours de travail** (pas une journée).

## Pourquoi avant Phase 10

Phase 10 = Review Gate Fog : l'utilisateur valide la qualité visuelle du fog sur device réel. Si les reveals s'affichent comme des "+" à petit rayon, le gate échoue automatiquement. **BUG-010 est sur le chemin critique de la Phase 10.**

## Deferred jusqu'à

1. **(a) BUG-009 TIER 2 visuel acceptable on device.** ✅ Validé post-`b0c362e` (bake) + `4736342` (boundary watercolour restoration) + `3e74699`/`42cd669`/`03cf8ba` (curl scale animation breathing). Le shader path est confirmé actif (instrumentation `7b6d819`), pattern volumétrique visible, body anime correctement avec curl. Le reste = symptôme structurel data layer.
2. **(b) BUG-006 followup acknowledgé.** ✅ BUG-006 doc cross-link à BUG-010 confirmé. User a vu et validé que le boundary smoothing (BlurStyle.normal) ne suffit pas à petit rayon.
3. **(c) Les 3 fix math shader (`76dfca4`) vérifiés on device.** ✅ Validé — fog body produit le full uHighlight↔uShadow gradient, hue directional, light single-applied.

**Toutes les conditions deferred sont remplies au 2026-04-26.** BUG-010 est maintenant la prochaine priorité — la décision d'attaque (Option B directe vs Option D stop-gap puis B) reste à arrêter avec le user.

## Hypothèses & décisions à arrêter au démarrage

- **Quel rayon par défaut ?** Aujourd'hui 20 m initial + 25 m moving (ou similaire). Avec une vraie géométrie, on peut être plus généreux (50 m) sans coût visuel. À discuter.
- **Compaction online ou offline ?** Online = chaque addDisc check overlap et merge ; coût par-fix mais storage stable. Offline = on accumule, on compacte au flush ; cheaper par-fix mais peak memory plus élevé.
- **Format de stockage on disk ?** SQLite avec colonne BLOB pour batches ? Fichier append-only par session ? À aligner avec le format actuel des sessions.

## Lien vers les bugs cousins

- **BUG-006** — boundary smoothing (closed sur ce périmètre, le reste migre ici)
- **BUG-009** — TIER 2 fog visual (en cours de validation device, blocker pour démarrer BUG-010)
- **CLAUDE.md "préférer la déduction au tracking"** — la liste de discs est la vraie state, le bitmap actuel en est une déduction ; donc le rework est aligné avec la philosophie projet.

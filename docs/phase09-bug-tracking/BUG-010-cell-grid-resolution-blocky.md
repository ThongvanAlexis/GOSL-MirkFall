# BUG-010 — Reveal blocky par construction (data layer en grille de cellules 19 m)

**Status:** open / planned (doit lander avant le Review Gate de Phase 10)
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

### ❌ Option D rejetée — Plus de blur sur la grille 19 m actuelle

Augmenter le sigma du `MaskFilter.blur` ou ajouter un post-process de smoothing en bord. **Rejeté** : ne résout pas le problème fondamental, et le blur agressif fait baver le fog dans la zone révélée (BUG-006 avait déjà ce trade-off).

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

1. **(a) BUG-009 TIER 2 visuel acceptable on device.** Vérifier que `76dfca4` (les 3 fix math du shader) produit bien un pattern volumétrique visible sur walk. Sans ça, on ne sait pas si le problème "feuille grise" vient du shader ou de la data layer — il faut isoler.
2. **(b) BUG-006 followup acknowledgé.** Ce ticket-ci documente le périmètre de BUG-006 qui reste — l'utilisateur a vu et validé.
3. **(c) Les 3 fix math shader (`76dfca4`) vérifiés on device.** Idem que (a) — pas de rework data layer tant que le shader stack n'est pas connu-bon.

Une fois ces 3 conditions remplies, BUG-010 devient la prochaine priorité avant le gate Phase 10.

## Hypothèses & décisions à arrêter au démarrage

- **Quel rayon par défaut ?** Aujourd'hui 20 m initial + 25 m moving (ou similaire). Avec une vraie géométrie, on peut être plus généreux (50 m) sans coût visuel. À discuter.
- **Compaction online ou offline ?** Online = chaque addDisc check overlap et merge ; coût par-fix mais storage stable. Offline = on accumule, on compacte au flush ; cheaper par-fix mais peak memory plus élevé.
- **Format de stockage on disk ?** SQLite avec colonne BLOB pour batches ? Fichier append-only par session ? À aligner avec le format actuel des sessions.

## Lien vers les bugs cousins

- **BUG-006** — boundary smoothing (closed sur ce périmètre, le reste migre ici)
- **BUG-009** — TIER 2 fog visual (en cours de validation device, blocker pour démarrer BUG-010)
- **CLAUDE.md "préférer la déduction au tracking"** — la liste de discs est la vraie state, le bitmap actuel en est une déduction ; donc le rework est aligné avec la philosophie projet.

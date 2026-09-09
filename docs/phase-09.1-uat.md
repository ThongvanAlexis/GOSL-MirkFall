# Phase 09.1 — UAT device (iPhone primaire + Pixel 4a)

Checklist de recette sur device pour la Phase 09.1 (port-back du fog same-canvas :
`flutter_map 7.0.2` + `FogLayer` enfant du `FlutterMap`, fix bundle POC
FOG-06/07/12/13/18/19/21/23, disques Drift persistés, wisps monde, 4 variants).
Elle remplace le critère de succès SC#3 (perception du lag inter-pipeline, non
capturable en widget test), SC#4 (régressions Phase 07 sur device) et alimente
la Phase 10 (courbe rebuild SDF, budget frame PERF-07, backend GPU).

Ce fichier est **rempli pendant le checkpoint 09.1-08 Task 2** par l'utilisateur.
Aucun résultat n'est pré-rempli : chaque case `[ ]` et chaque champ `à renseigner`
reste vide tant que le test n'a pas été exécuté sur le device.

## En-tête

| Champ | Valeur |
|-------|--------|
| Date de l'UAT | à renseigner |
| Commit testé (`kGitCommitSha`, affiché dans Debug menu → Build commit) | `f347eeb56901e791a7739f4390fc5caf1359d951` (`f347eeb`, dernier commit de code 09.1-07 — `chore(09.1-07): scrub the last MapLibre / StyleRewriter prose`) |
| Run CI source des artefacts | [`34376643891`](https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/34376643891) — vert sur les 3 jobs (gates, Android APK debug, iOS no-codesign) |
| Run CI du commit de clôture docs `dce8843` | `34377885630` — encore en cours au moment de la récupération (delta docs-only, code identique à `f347eeb`) |
| IPA non signée | `GH_builds/09.1/mirkfall-unsigned.ipa` (11 275 232 octets, sha256 `db56d4dc7b024a49dd585d49d686238ea2d4466be0366036b903dfccf0db8a49`) |
| APK debug | `GH_builds/09.1/app-debug.apk` (171 751 446 octets, sha256 `9a180b93a76090373bc2ee06ae761689834b06c8a619207bd96267b3348275e9`) |
| Device iOS (primaire) | iPhone 17 Pro — version iOS : à renseigner |
| Device Android (secondaire) | Pixel 4a (Adreno 618) — Android 13 — serial `11081JEC204746` |
| Fichiers de logs récupérés | à renseigner (noms `yyyymmdd_hhmm.ss_logs.txt`, un par device) |

Récupération des artefacts (déjà faite par 09.1-08 Task 1, à refaire si besoin) :

```
gh run download 34376643891 -n mirkfall-ios-unsigned-ipa -D GH_builds/09.1/
gh run download 34376643891 -n mirkfall-android-debug-apk -D GH_builds/09.1/
```

(`python download_builds.py` récupère le **dernier** run dans `GH_builds/` — il vide le dossier et prend le run le plus récent, pas nécessairement celui-ci.)

## Installation

- **iPhone (SideStore, ou iLoader selon `DEV_COMMANDS.md`)** : sideloader `GH_builds/09.1/mirkfall-unsigned.ipa`. Si une version précédente est installée, la mise à jour conserve la base Drift (disques + sessions) — c'est voulu pour A1 / A3.
- **Pixel 4a** : `adb -s 11081JEC204746 install -r GH_builds/09.1/app-debug.apk` (USB debugging actif ; `adb devices` pour confirmer le serial).
- **Sur les deux devices** : Paramètres → Debug menu → ligne « Build commit » doit afficher `f347eeb56901e791a7739f4390fc5caf1359d951`. Si la valeur est `dev` ou un autre SHA, le build installé n'est pas celui de cette UAT : réinstaller avant de continuer.

## Pré-requis (AVANT la session de test)

1. Paramètres → Debug menu → **« Verbose logging » = ON** sur les deux devices. Les rollups `frame_delta` / `fog_transform` / `sdf` / `wisp` et les marqueurs `dev_marker` n'émettent **qu'en verbose** ; sans ce réglage les sections B3 et C sont vides. Le toggle agit immédiatement (pas besoin de relancer), mais l'activer avant d'ouvrir la carte évite de perdre les premières secondes.
2. Noter le nom du fichier actif affiché en bas du Debug menu (« Active: … ») : c'est le fichier à partager à la fin.
3. Pour corréler une observation avec les rollups : Debug menu → « Marquer une anomalie (dev marker) » écrit une ligne `dev_marker` horodatée dans le log (snackbar « Marqueur écrit dans les logs » ; si le snackbar dit « Verbose désactivé — marqueur ignoré », revenir au point 1).
4. Optionnel, avant le device : smoke desktop `flutter run -d windows` (non exécuté par 09.1-07), pan / zoom à la souris, fog verrouillé sur les tuiles. Non bloquant.

## Section A — iPhone 17 Pro (cible primaire, SideStore)

Style de départ : « Atmospheric (défaut) » sauf mention contraire. Pour chaque item : cocher OUI ou NON, décrire l'écart dans « Observations ».

### A1 — Session avec disques persistés

Ouvrir une session existante d'un walk précédent (liste des sessions → session → carte), **ou** créer une session, démarrer le suivi GPS et marcher ~2 min pour semer des disques. La carte doit montrer des trous (disques révélés) dans le fog avant de passer à A2.

- Résultat : `[ ]` OUI (disques visibles) `[ ]` NON
- Nombre approximatif de disques visibles : à renseigner
- Observations : à renseigner

### A2 — Zéro déplacement visible du fog (**critère bloquant**)

Gestes à enchaîner, en regardant le **halo des disques** (bord feather) et le **noise** du fog par rapport aux tuiles :

| Geste | Attendu | OUI | NON |
|-------|---------|-----|-----|
| Pan lent (1 doigt, ~2 s d'un bord à l'autre) | Les trous restent collés aux rues / bâtiments, le noise glisse avec la carte | `[ ]` | `[ ]` |
| Pan rapide + relâcher (inertie) | Idem pendant le fling et à l'arrêt, aucun « rattrapage » du fog après la tuile | `[ ]` | `[ ]` |
| Pinch-zoom in / out (plusieurs niveaux) | Les trous grandissent / rétrécissent avec la carte, le grain du noise reste ancré (pas de « respiration » de la texture) | `[ ]` | `[ ]` |
| Pan + zoom combinés (2 doigts, translation pendant le pinch) | Aucun décalage, même transitoire, entre le trou et la rue en dessous | `[ ]` | `[ ]` |
| Double-tap zoom | Idem, pas de saut d'une frame | `[ ]` | `[ ]` |

- Verdict A2 : `[ ]` OUI — zéro déplacement visible `[ ]` NON — déplacement observé
- Si NON : geste, style actif, niveau de zoom approximatif, capture (`docs/phase-09.1-uat-screenshots/`), marqueur dev posé au moment de l'écart : à renseigner

### A3 — Persistance après kill + relance (**critère bloquant**)

Tuer l'app (app switcher → swipe), relancer, rouvrir la même session → carte.

- Les disques réapparaissent **au même endroit** (même rues, même rayon) : `[ ]` OUI `[ ]` NON
- Délai avant apparition du fog + trous à l'ouverture de la carte (fondu initial ~600 ms attendu) : à renseigner
- Observations : à renseigner

### A4 — Changement de style ×4 (picker)

Burger menu → « Changer le style » → sélectionner successivement les 4 variants. Chacun doit peindre **dans le même Canvas** (trous alignés sur les tuiles, aucun décalage au swap, pas de flash blanc prolongé — un frame vide au swap est attendu, voir 09.1-07).

| Variant | Peint, trous alignés | Bord feather visible (arrondi) | Note |
|---------|----------------------|-------------------------------|------|
| Atmospheric (défaut) — shader + wisps | `[ ]` OUI `[ ]` NON | `[ ]` OUI `[ ]` NON | à renseigner |
| Solide — CPU, `saveLayer` par frame | `[ ]` OUI `[ ]` NON | `[ ]` OUI `[ ]` NON | à renseigner |
| Lueur de bougie — CPU, halo centré sur le fix | `[ ]` OUI `[ ]` NON | `[ ]` OUI `[ ]` NON | à renseigner |
| Nuages célestes — shader + wisps, fallback CPU ancré monde | `[ ]` OUI `[ ]` NON | `[ ]` OUI `[ ]` NON | à renseigner |

- Wisps (Atmospheric / Nuages célestes) : apparaissent sur les nouveaux disques après le warm-up de 5 s, suivent la carte au pan / zoom sans dérive : `[ ]` OUI `[ ]` NON `[ ]` non testé (pas de nouveau disque pendant l'UAT)
- Observations : à renseigner

### A5 — Tuner en direct

Bouton tuner (haut droite de la carte) → bouger un slider (ex. `opacityMid` ou `scaleMid` sur Atmospheric ; « Densité du brouillard » depuis le burger menu compte aussi).

- Le rendu change **en direct** pendant le drag du slider : `[ ]` OUI `[ ]` NON
- Slider utilisé + valeur : à renseigner
- Observations : à renseigner

### A6 — Mode avion (régression Phase 07 / MAP-01)

Activer le mode avion (OS), tuer l'app, relancer à froid, ouvrir la carte, pan / zoom sur plusieurs niveaux.

- Carte visible (tuiles vectorielles depuis `world.pmtiles` ou le pays téléchargé) : `[ ]` OUI `[ ]` NON
- Fog + trous fonctionnels en mode avion : `[ ]` OUI `[ ]` NON
- **Aucune tuile grise** / vide après le settle : `[ ]` OUI `[ ]` NON
- Observations : à renseigner

### A7 — Follow-me

FAB « Me suivre » (bas droite). En session active avec GPS.

- La caméra recentre sur le fix, l'icône passe à `gps_fixed` : `[ ]` OUI `[ ]` NON
- Un pan manuel quitte le suivi (tooltip « Quitter le suivi » → retour à « Me suivre ») : `[ ]` OUI `[ ]` NON
- Pendant le recentrage, le fog reste aligné (pas de décalage pendant `moveCameraTo`) : `[ ]` OUI `[ ]` NON
- Observations : à renseigner

### A8 — Hot-swap monde ↔ pays téléchargé

Désactiver le mode avion. Paramètres → « Télécharger une carte » → « Aruba » (~4,1 Mo, 1 part) → confirmer. Puis sur la carte, naviguer jusqu'à Aruba (12.5°N, 70.0°W) : le résolveur doit basculer sur l'archive du pays ; en ressortant du pays, retour sur le monde. Paramètres → « Gérer les cartes installées » pour supprimer Aruba à la fin.

- Téléchargement OK (chip de progression, snackbar « Aruba téléchargé ✓ ») : `[ ]` OUI `[ ]` NON
- Swap monde → Aruba : niveau de détail plus fin sans tuile grise, fog toujours aligné : `[ ]` OUI `[ ]` NON
- Swap Aruba → monde en ressortant : `[ ]` OUI `[ ]` NON
- Suppression d'Aruba depuis « Gérer les cartes installées » (la ligne monde reste non supprimable) : `[ ]` OUI `[ ]` NON
- Observations : à renseigner

## Section B — Pixel 4a (APK debug, Android 13, Adreno 618)

Mêmes pré-requis (Build commit, Verbose logging ON, style Atmospheric).

### B1 — Stripes FOG-23 et halo FOG-21 (**critère bloquant**)

Rejouer les gestes de A2 (pan lent, pan rapide, pinch, pan + zoom) sur Atmospheric puis Nuages célestes.

- **Aucune stripe horizontale** dans le noise (FOG-23, correction du signe de `pixelOrigin.y` sur Android) : `[ ]` OUI `[ ]` NON
- Halo SDF **centré sur le trou**, non miroir verticalement (FOG-21, `sdfRect` V-flip) : `[ ]` OUI `[ ]` NON
- Zéro déplacement visible du fog (même critère qu'A2) : `[ ]` OUI `[ ]` NON
- Fallback CPU de Nuages célestes visible avant l'arrivée du shader / SDF (nuages ancrés monde, pas de flash uni) : `[ ]` OUI `[ ]` NON `[ ]` non observé
- Si NON sur un item : capture + marqueur dev + geste / style / zoom : à renseigner

### B2 — Backend GPU (logcat)

Avant de lancer l'app (PowerShell, Pixel branché) :

```
adb -s 11081JEC204746 logcat -c
adb -s 11081JEC204746 logcat | Select-String -Pattern "impeller|vulkan|opengl|gles" -CaseSensitive:$false
```

Lancer l'app, ouvrir la carte, attendre ~10 s, Ctrl+C.

- Backend observé : `[ ]` Impeller-Vulkan `[ ]` Impeller-OpenGLES `[ ]` Skia-GLES `[ ]` autre : à renseigner
- Lignes logcat pertinentes (copier 2–3 lignes) : à renseigner

### B3 — Budget frame `frame_delta` sur 2 min pan + zoom (informatif)

Verbose ON, carte ouverte sur la session la plus fournie en disques, enchaîner pan / zoom pendant **2 minutes** sans pause (poser un marqueur dev au début et à la fin). Les rollups 1 Hz `infrastructure.mirk.frame_delta` contiennent `sampleCount`, `medianMs`, `p95Ms`, `maxMicros`. Après partage du fichier de log (voir « Collecte des logs »), agréger sur la fenêtre :

```
python -c "import json,statistics as s,sys;o=[json.loads(l) for l in open(sys.argv[1],encoding='utf-8',errors='replace') if 'infrastructure.mirk.frame_delta' in l];ls=[json.loads(x['msg']) for x in o if x.get('logger')=='infrastructure.mirk.frame_delta' and x['msg'].startswith('{')];print('rollups',len(ls),'p50 of medianMs',s.median(x['medianMs'] for x in ls),'p50 of p95Ms',s.median(x['p95Ms'] for x in ls),'max p95Ms',max(x['p95Ms'] for x in ls))" <chemin du log Pixel>
```

- Nombre de rollups sur la fenêtre : à renseigner
- p50 (médiane des `medianMs`) : à renseigner ms (≈ à renseigner fps) — attendu ≥ 30 fps à la médiane (référence POC : 25,63 ms ≈ 39 fps)
- p95 (médiane des `p95Ms`) : à renseigner ms — informatif, dépend du device (référence POC : outliers à 391 ms sur Adreno 618)
- Style actif pendant la mesure : à renseigner
- Observations (GC visibles, chargement de tuiles, chaleur) : à renseigner

## Section C — Mesures pour la Phase 10 (courbe rebuild SDF)

Sur le device et la session **les plus fournis en disques** (iPhone de préférence), verbose ON, 2 min de pan + zoom (la fenêtre B3 convient si c'est le Pixel). Les rollups 1 Hz `infrastructure.mirk.sdf` contiennent `discCount`, `intersectingDiscCount`, `rebuildCount`, `medianMs`, `p95Ms`, `maxMs`.

```
python -c "import json,statistics as s,sys;o=[json.loads(l) for l in open(sys.argv[1],encoding='utf-8',errors='replace') if 'infrastructure.mirk.sdf' in l];ls=[json.loads(x['msg']) for x in o if x.get('logger')=='infrastructure.mirk.sdf' and x['msg'].startswith('{')];r=[x for x in ls if x['rebuildCount']>0];print('rollups',len(ls),'with rebuilds',len(r),'discCount max',max(x['discCount'] for x in ls),'rebuilds/s p50',s.median(x['rebuildCount'] for x in ls),'medianMs p50',s.median(x['medianMs'] for x in r) if r else None,'p95Ms max',max(x['p95Ms'] for x in r) if r else None)" <chemin du log>
```

| Mesure | Valeur |
|--------|--------|
| Device / session | à renseigner |
| `discCount` max (disques de la requête paddée) | à renseigner |
| `intersectingDiscCount` max (disques dans le viewport) | à renseigner |
| Rebuilds / s (p50, max) | à renseigner |
| `medianMs` par rebuild (p50) | à renseigner |
| `p95Ms` / `maxMs` par rebuild | à renseigner |
| Rollups `infrastructure.mirk.wisp` : `activeCountMax` (plafond 200) | à renseigner |
| Rollups `infrastructure.mirk.fog_transform` : nombre de lignes, anomalies (`sampleCount` à 0 pendant un geste) | à renseigner |

Observations (jank ressenti en corrélation avec un rebuild, marqueurs dev) : à renseigner

## Collecte des logs et captures

- **Format** : le fichier est du JSONL, une ligne `{"ts","level","logger","msg"}` par record ; pour les rollups, `logger` vaut `infrastructure.mirk.frame_delta` / `.fog_transform` / `.sdf` / `.wisp` / `.dev_marker` et `msg` est lui-même une chaîne JSON (les snippets B3 / C la décodent).
- **Logs** : Debug menu → liste des fichiers → icône « partager » sur le fichier actif (Mail / AirDrop / Drive sur iPhone ; n'importe quel canal sur Android). Chemin sur le device : `<app_documents>/logs/yyyymmdd_hhmm.ss_logs.txt`. Sur le Pixel, alternative USB : `adb -s 11081JEC204746 exec-out run-as app.gosl.mirkfall tar c app_flutter/logs > pixel-logs.tar` (le dossier documents Flutter est `app_flutter/` sous `/data/user/0/app.gosl.mirkfall/`).
- Déposer les fichiers dans `docs/phase-09.1-uat-screenshots/` (les logs y sont acceptés aussi) et lister leurs noms dans l'en-tête.
- **Captures** : une par écart observé (A2, A3, B1) et une par variant sur chaque device (A4 / B1) si possible : `docs/phase-09.1-uat-screenshots/<device>-<section>-<description>.png`.
- **Crash iOS** éventuel : `idevicecrashreport -e ./ios-crash-dumps/` (voir `DEV_COMMANDS.md`) + Debug menu.

## Section D — Verdict

| Section | Critère | APPROUVÉ | REFUSÉ | Non testé |
|---------|---------|----------|--------|-----------|
| A1 | Session avec disques persistés | `[ ]` | `[ ]` | `[ ]` |
| A2 | **Bloquant** — zéro déplacement visible (pan, zoom, combinés) | `[ ]` | `[ ]` | `[ ]` |
| A3 | **Bloquant** — fog conservé après kill + relance | `[ ]` | `[ ]` | `[ ]` |
| A4 | 4 variants dans le même Canvas | `[ ]` | `[ ]` | `[ ]` |
| A5 | Tuner en direct | `[ ]` | `[ ]` | `[ ]` |
| A6 | Mode avion : carte + fog, zéro tuile grise | `[ ]` | `[ ]` | `[ ]` |
| A7 | Follow-me | `[ ]` | `[ ]` | `[ ]` |
| A8 | Hot-swap monde ↔ Aruba + téléchargement + suppression | `[ ]` | `[ ]` | `[ ]` |
| B1 | **Bloquant** — aucune stripe (FOG-23), halo non miroir (FOG-21) | `[ ]` | `[ ]` | `[ ]` |
| B2 | Backend GPU noté | `[ ]` | `[ ]` | `[ ]` |
| B3 | p50 / p95 `frame_delta` notés | `[ ]` | `[ ]` | `[ ]` |
| C | Rollup SDF noté | `[ ]` | `[ ]` | `[ ]` |

- **Verdict global** : `[ ]` APPROUVÉ (A2, A3, B1 approuvés, fichier rempli) `[ ]` REFUSÉ (→ `/gsd:plan-phase 09.1 --gaps`)
- Observations libres : à renseigner
- Captures / logs joints : à renseigner
- Signature (nom, date) : à renseigner

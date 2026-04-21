# MirkFall

## What This Is

Application mobile Flutter (iOS + Android) qui applique un **brouillard de guerre** (le *mirk*) sur une carte du monde, façon RTS Warcraft 3. Le mirk se dissipe autour de l'utilisateur au fur et à mesure de ses déplacements réels, révélant progressivement le territoire exploré. L'app est organisée autour de **sessions** indépendantes (ex : "Paris été 2026", "Mon quartier"), contenant chacune leur état de brume et leurs points d'intérêt (markers avec photos, notes, icônes RPG).

Projet-cadeau personnel de l'auteur (pour explorer sa ville et matérialiser ses déplacements), publié sur GitHub sous licence **GOSL v1.0** pour servir à d'autres.

## Core Value

**Ne jamais perdre sa progression.** Import/export durable des sessions au format JSON versionné — tu changes de téléphone, tu le perds, tu le casses, tu reprends là où tu étais sur une autre instance de l'app. C'est LA différence revendiquée vs les apps similaires existantes.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope (V1.0). Toutes ces exigences sont des hypothèses jusqu'à ce qu'elles soient livrées et validées. -->

**Sessions**
- [ ] Créer, renommer, supprimer une session
- [ ] Start/Stop d'une session avec exclusivité (une seule active à la fois)
- [ ] Persistance locale de l'état de session (mirk révélé, markers, métadonnées)
- [ ] Tracking GPS en arrière-plan (app backgroundée, écran éteint)
- [ ] Notification persistante quand une session est active
- [ ] Demande d'autorisation localisation background à la première session démarrée

**Mirk (brouillard)**
- [ ] Révélation circulaire autour de la position actuelle
- [ ] Rayon de révélation configurable dans les options globales
- [ ] Mirk effacé = effacé définitivement pour la durée de la session
- [ ] Rendu vivant/atmosphérique (nuageux, mouvant) — pas un simple aplat noir
- [ ] Architecture de rendu générique/découplée pour ajouter d'autres styles sans toucher au cœur
- [ ] Plusieurs styles de mirk prédéfinis, sélectionnables **par session** (menu in-session)
- [ ] Import d'un style de mirk depuis un fichier JSON

**Markers**
- [ ] Créer, modifier, supprimer un marker (position, titre, texte libre, 0..n photos, catégorie+icône)
- [ ] Markers visibles en transparence même sous mirk (pour usage "pré-import lieux à visiter")
- [ ] Fiche détaillée au tap (titre, texte, galerie photos)
- [ ] Gestion depuis la carte ET depuis une liste
- [ ] Catégories par défaut avec icônes style RPG
- [ ] Création de catégories custom (nom + icône)
- [ ] Système d'icônes générique (facilite l'ajout de packs ultérieurs)

**Import / Export** *(core value — priorité #1)*
- [ ] Export d'une session individuelle au format JSON
- [ ] Export de toutes les sessions en une opération
- [ ] Import d'une session JSON exportée depuis n'importe quelle instance
- [ ] Import d'un fichier JSON de markers seuls (pré-peuplement de session)
- [ ] Import d'un fichier JSON de style de mirk
- [ ] Format JSON versionné (champ `version` en tête) pour compatibilité ascendante
- [ ] Schéma lisible à la main (pas de blob binaire injustifié)

**Carte**
- [ ] Fond de plan vectoriel PMTiles (Protomaps dérivées d'OSM), **100 % offline**
- [ ] Interactivité (pan, zoom) préservée sous mirk
- [ ] World map bundlé dans les assets (day-1 UX) + téléchargement par pays depuis GitHub Release (day-N)
- [ ] Architecture carte découplée (`MapView` domain-level + `PmtilesSource` local-only)

**Options / paramètres globaux**
- [ ] Écran dédié regroupant : rayon de révélation, style de mirk par défaut pour nouvelles sessions, gestion des styles importés, gestion des catégories de markers, import/export global

*Note : le style de mirk actif **par session** se choisit dans le menu in-session (pas dans les options globales). L'option globale ne fait que fixer le défaut appliqué aux nouvelles sessions.*

**Qualité / distribution**
- [ ] Pipeline GitHub Actions (build Android ubuntu-latest + build iOS non-signé macos-latest)
- [ ] Logs locaux dans `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt`
- [ ] Mention "MirkFall is distributed under GOSL v1.0" accessible dans l'app (À propos / Legal) avec lien vers le texte complet
- [ ] Header de licence présent dans chaque fichier source

### Out of Scope

<!-- Explicit V1.0 boundaries. -->

- **Synchronisation cloud / multi-appareils** — V1.0 = local-first strict ; la synchro se fait manuellement via import/export JSON (c'est le design)
- **Partage de session entre utilisateurs / mode multijoueur** — hors cadre du projet personnel
- **Statistiques d'exploration (distance, % du monde révélé, etc.)** — peut arriver post-V1
- **Re-brumage temporel des zones révélées** — contraire au design (le territoire exploré reste exploré)
- **Achievements / gamification** — pas dans l'esprit du projet
- **Intégrations tierces (Strava, Google Photos, etc.)** — viole les principes GOSL et complique le scope
- **Analytics, crash reporting automatique, télémétrie quelconque** — interdit par la GOSL et le CLAUDE.md du projet
- **Abonnement / monétisation / pub** — interdit par la GOSL

## Context

- **Auteur** : développeur solo, utilisateur principal. Habite sa ville depuis 6 ans sans vraiment l'explorer — MirkFall est un outil pour se (re)motiver.
- **Apps similaires existantes** : plusieurs apps de "fog of war" réel existent, mais aucune ne propose un import/export propre. Perdre son téléphone = perdre toute sa progression. C'est le problème que MirkFall résout.
- **Plateforme de dev** : Windows 10 (Android emulator/device + desktop `flutter run -d windows`). Tests iOS via CI macos-latest + sideload (SideStore ou équivalent), pas de compte Apple Developer payant.
- **Licence** : GOSL v1.0 — interdit monétisation, pub, télémétrie non-consentie, abonnements dans toute redistribution. Impose une discipline stricte sur les dépendances (voir `CLAUDE.md` du projet).
- **Vision publication** : GitHub public, ouvert aux contributions, binaires construits en CI et diffusés via GitHub Releases (pas de stores officiels payants prévus).

## Constraints

- **Licence**: GOSL v1.0 — aucune dépendance GPL/AGPL/copyleft fort. Seulement MIT / BSD / Apache 2.0 / Unlicense / CC0 / ISC / zlib. Audit documenté dans `DEPENDENCIES.md` pour chaque ajout.
- **Télémétrie**: Zéro SDK d'analytics, crash reporting auto, attribution, A/B, session replay. Logs strictement locaux. Aucun appel réseau sans action utilisateur explicite.
- **Tech stack**: Flutter (iOS + Android cibles). Dart strict mode (`strict-casts`, `strict-inference`, `strict-raw-types`). Pin exact des versions dans `pubspec.yaml`. Plugins officiels Flutter privilégiés (`geolocator`, `permission_handler`, `camera`, `shared_preferences`, `path_provider`, etc.).
- **Plateforme dev principale**: Windows 10 + Android. iOS via CI + sideload par paliers.
- **Fond cartographique**: vector tiles only (PMTiles au format Protomaps dérivées d'OSM), **pas de raster**, **100 % hors ligne**. Aucun streaming, aucun bucket object-storage, aucune requête réseau pour les tuiles — jamais. Day-1 UX : un world map PMTiles low-zoom (zoom 0-5, ~20-50 MB) est bundlé dans les assets et copié vers le stockage interne au premier lancement. Day-N : l'utilisateur télécharge des cartes par pays depuis un catalogue JSON pinné qui pointe vers un GitHub Release du repo projet ; chaque pays = N ZIP parts (contrainte GitHub Release : 2 GB / asset) qui s'assemblent pour reconstituer un unique `.pmtiles` local. MapLibre consomme uniquement des URI `pmtiles:///<path>` (lint custom interdit toute URI remote). L'attribution OSM + Protomaps reste requise parce que les données dérivent d'OSM.
- **Couche map**: l'app code (controllers, screens, services) ne dépend QUE d'une interface domain-level exprimée dans le vocabulaire MirkFall — `showMap(region)`, `moveCameraTo(location)`, `markVisited(polygon)`, `getUnvisitedAreas()`, `addLocationMarker(user)`, `addPointOfInterest(poi)`, `setTheme(standard | rpgParchment)`. Les types du renderer (`MapLibreMapController`, `SymbolOptions`, `CameraUpdate`, structure du `style.json`) NE REMONTENT JAMAIS au-dessus de `lib/infrastructure/map/`. Règle d'odeur : si l'interface contient `addSymbol(SymbolOptions)` ou équivalent, elle est trop basse et n'abstrait rien — la réécrire. Cette contrainte est architecturale et durable, indépendamment du renderer choisi.
- **Rendu du mirk**: qualité visuelle secondaire mais **couplage interdit** — l'implémentation doit être remplaçable sans toucher au reste de l'app (pattern stratégie ou équivalent).
- **Persistance**: représentation du mirk révélé doit rester raisonnable en stockage (on ne veut pas 10 TB de points GPS — voir §9 de la spec).
- **Background tracking**: faisabilité à valider dès POC sur iOS ET Android, incluant l'argumentaire revue App Store / Play Store.

## Key Decisions

<!-- Decisions captured during questioning. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Import/export JSON comme **core value** (pas un bonus) | Différencie vs apps concurrentes ; résout le problème "je perds mon téléphone = je perds tout" | — Pending |
| Markers **visibles en transparence** sous mirk (plutôt que masqués) | Cohérent avec le use-case "pré-import de lieux à visiter avant un voyage" (import-export first) | — Pending |
| Tuiles offline **intégrées en V1.0** (pivot 2026-04-19) | Le modèle "PMTiles régional hébergé sur bucket object-storage" (coûts bucket + streaming + surface d'attaque) a été écarté au profit d'une cartographie 100 % offline. Remplacé par : bundle world PMTiles low-zoom dans l'APK + téléchargement par pays depuis un GitHub Release du repo projet (ZIPs multi-parts). L'ancien plan "V1.1 offline en pur ajout" n'a plus lieu d'être : la feature est partie intégrante de la Phase 07. Les anciens OFFL-01..04 v2 sont absorbés dans MAP-07..10. | — Recorded |
| Rendu du mirk **découplé/générique dès V1.0** | Qualité visuelle peut évoluer, mais architecture ne doit pas être à refaire | — Pending |
| **Vector-first 100 % offline dès V1.0** (PMTiles Protomaps bundlé + téléchargement par pays) | V2 parchemin RPG exige du vector + styles MapLibre ; partir raster = réécrire tout à V2. Distribution = assets APK (world low-zoom) + GitHub Release du repo projet (pays entiers, ZIPs multi-parts pour contourner la limite 2 GB / asset GitHub). Résultat : zero coût bucket / CDN, zero runtime network pour les tuiles, zero policy OSM applicable, airplane mode fonctionnel dès le premier lancement. | — Recorded |
| Interface map **domain-level** (vocabulaire MirkFall, pas renderer) | Abstraction "1:1 wrapper autour de MapLibreMap" est du LARP architectural — l'interface doit exprimer ce que l'app veut (`markVisited`, `setTheme`), pas ce que le renderer expose (`SymbolOptions`, `CameraUpdate`). Règle durable, indépendante du renderer. | — Recorded |
| **Renderer V1.0 = `maplibre_gl 0.25.0` (pinned)** | Recherche 2026-04-19 : maintenu par MapLibre org, BSD-3, PMTiles natif depuis v0.22, zéro télémétrie, iOS 13+ / Android API 21+. Fallback non implémenté : sera envisagé uniquement si `maplibre_gl` est abandonné ou montre un bug bloquant. Décision implémentation, revisitable ; l'abstraction (ligne du dessus) est durable. | — Recorded |
| CI = **GitHub Actions** (Android ubuntu + iOS non-signé macos) | Cohérent avec CLAUDE.md, gratuit, permet distribution via GitHub Releases | — Pending |
| Distribution **hors stores officiels** (sideload iOS, APK direct Android) | Évite les frais Apple Developer, cohérent avec GOSL (pas de monétisation) | — Pending |
| **Un seul système de state management** à choisir en début de projet | Imposé par CLAUDE.md, évite mélange `Provider`+`Riverpod`+`Bloc` | — Pending |
| **Style (carte + mirk) par session** (amendement 2026-04-20 Phase 07 CONTEXT) | L'ancien "style global à l'app" ne colle pas avec le menu in-session décidé en Phase 07 (burger → change style). Chaque session choisit son style carte + son style mirk ; l'option globale ne garde qu'un "défaut pour nouvelles sessions". MIRK-10 amendé, OPT-03 repurposé. | — Recorded |
| **Catalog map bundlé en asset** (amendement 2026-04-20 Phase 07 CONTEXT) | L'ancien plan `kMapCatalogUrl` distant a été simplifié : le catalog.json (~132 KB) est bundlé dans `assets/maps/catalog.json`, update = rebuild app. Évite un remote fetch au démarrage + élimine la dépendance à une URL externe pour le listing des pays. Les chunks binaires des `.pmtiles` restent hébergés sur GitHub Release (`ThongvanAlexis/countries-pmtiles`). | — Recorded |
| **Chunks binaires multi-parts (pas ZIP)** (amendement 2026-04-20 Phase 07 CONTEXT) | Les fichiers `.pmtiles` par pays sont découpés en chunks binaires bruts (`partNN`) de 1.5 GB max (limite GitHub Release 2 GB/asset), réassemblés par concat binaire. Le terme "ZIP" du ROADMAP initial était imprécis : aucune archive à extraire, pas besoin du package `archive`. `dart:io HttpClient` brut + concat binaire suffisent. MAP-08/09 + ROADMAP Phase 07/08 amendés. | — Recorded |

## V2 Backlog

Scope items explicitly deferred to V2.0 (post-V1.0 stabilisation). Not bound to a specific V1 phase — these get their own phases when V2 roadmap is drawn.

| Item | Origin | Scope sketch | Platform touch |
|------|--------|--------------|----------------|
| **V2 "Parchemin RPG" style** | PROJECT.md §Key Decisions (original) | Second bundled style variant (medieval / fantasy feel) alongside the neutral Phase 07 basemap. Implementation : swap `style.json` + sprite sheet, zero Dart change thanks to the Phase 07 domain-level seam. Imported-style infrastructure (OPT-03, MIRK-08) must land in Phase 13 first. | None — asset swap only. |
| **Téléchargement de cartes en arrière-plan (écran verrouillé / app backgroundée)** | Phase 07 device-smoke 2026-04-21 | Actuellement un download est suspendu quand l'utilisateur verrouille l'écran (isolate Flutter suspendu par l'OS après ~10 s, Doze Android + suspension iOS). V1.0 mitige par le resume Range-based au retour au foreground. V2 livre la vraie expérience continue : **Android** = Foreground Service dédié avec notification persistante "Téléchargement : \<pays\> \<XX\> %" + platform channel start/stop. **iOS** = ré-écriture du chemin download pour utiliser `URLSession.backgroundConfiguration` (la télécharge continue même app suspendue, voire terminée). Contrepartie iOS : on perd le pur-Dart `HttpChunkDownloader` testable pour la partie iOS et on ajoute un boundary plateforme lourd. Le resume Range + le sha256 per-chunk de la Phase 07 restent corrects. Touche : `lib/infrastructure/downloads/` + nouveau FGS Kotlin + bridge Swift URLSession + tests d'intégration device. Dépend de la Phase 07 complète (pipeline stable) + probablement de la Phase 08 Review Gate fermée. | Android FGS + service manifest entry + INTERNET permission (already granted) ; iOS URLSession delegate in Swift + completion-handler bridging. |

---
*Last updated: 2026-04-21 — added V2 Backlog section with parchment style (from Key Decisions) + background downloads (from Phase 07 device-smoke feedback)*

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
- [ ] Plusieurs styles de mirk prédéfinis, sélectionnables dans les options
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
- [ ] Fond de plan standard (OSM ou équivalent gratuit, à trancher en recherche)
- [ ] Interactivité (pan, zoom) préservée sous mirk
- [ ] Architecture carte découplée pour faciliter l'ajout de tiles offline en V1.1

**Options / paramètres globaux**
- [ ] Écran dédié regroupant : rayon de révélation, style de mirk actif, gestion des styles importés, gestion des catégories de markers, import/export global

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
- **Téléchargement de tuiles offline (V1.1)** — V1.0 code l'abstraction carte découplée, mais pas de UI de download (§6.2 de la spec marquée nice-to-have)
- **Rendu du mirk par session** — le choix de style est global à l'app en V1.0
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
- **Fond cartographique**: vector tiles only (PMTiles au format Protomaps), **pas de raster**. Hébergement sur object storage cheap (R2 / B2 / S3) avec un PMTiles régional (pas planet) pour minimiser le coût et la surface d'attaque. PMTiles permet le futur offline (V1.1) en swappant l'URL `pmtiles://https://...` pour `pmtiles:///path/local.pmtiles` sans toucher à la couche appelante. L'attribution OSM reste requise parce que les données Protomaps sont dérivées d'OSM.
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
| Tuiles offline **reportées en V1.1** | Nice-to-have dans spec ; V1.0 prépare l'abstraction pour intégration facile plus tard | — Pending |
| Rendu du mirk **découplé/générique dès V1.0** | Qualité visuelle peut évoluer, mais architecture ne doit pas être à refaire | — Pending |
| **Vector-first dès V1.0** (PMTiles Protomaps, pas de raster OSM) | V2 parchemin RPG exige du vector + styles MapLibre ; partir raster = réécrire tout à V2. Auto-hébergement PMTiles régional contourne la policy OSM tile + zero CDN cost sur petit volume. | — Recorded |
| Interface map **domain-level** (vocabulaire MirkFall, pas renderer) | Abstraction "1:1 wrapper autour de MapLibreMap" est du LARP architectural — l'interface doit exprimer ce que l'app veut (`markVisited`, `setTheme`), pas ce que le renderer expose (`SymbolOptions`, `CameraUpdate`). Règle durable, indépendante du renderer. | — Recorded |
| **Renderer V1.0 = `maplibre_gl 0.25.0` (pinned)** | Recherche 2026-04-19 : maintenu par MapLibre org, BSD-3, PMTiles natif depuis v0.22, zéro télémétrie, iOS 13+ / Android API 21+. Fallback non implémenté : sera envisagé uniquement si `maplibre_gl` est abandonné ou montre un bug bloquant. Décision implémentation, revisitable ; l'abstraction (ligne du dessus) est durable. | — Recorded |
| CI = **GitHub Actions** (Android ubuntu + iOS non-signé macos) | Cohérent avec CLAUDE.md, gratuit, permet distribution via GitHub Releases | — Pending |
| Distribution **hors stores officiels** (sideload iOS, APK direct Android) | Évite les frais Apple Developer, cohérent avec GOSL (pas de monétisation) | — Pending |
| **Un seul système de state management** à choisir en début de projet | Imposé par CLAUDE.md, évite mélange `Provider`+`Riverpod`+`Bloc` | — Pending |

---
*Last updated: 2026-04-17 after initialization*

# Phase 01: Foundation - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Day-1 garde-fous : licence (headers GOSL + scan GPL/AGPL), CI GitHub Actions (Android ubuntu + iOS unsigned macos), logger fichier configurable, bootstrap Riverpod, lint strict zéro warning, `DEPENDENCIES.md` stub. Tout le reste de MirkFall en dépend.

Hors scope (autres phases) : la moindre ligne de code métier (GPS, carte, mirk, markers, import/export). Phase 01 livre une **app vide qui démarre**, exécute son bootstrap, ouvre un placeholder, et passe les gates CI.

</domain>

<decisions>
## Implementation Decisions

### License enforcement gates (CI-only, transitives included)

- **GPL/AGPL/copyleft-fort scan : CI uniquement.** Script Dart `tool/check_licenses.dart` qui parse `pubspec.lock`, résout chaque package (direct + **toutes les transitives**) via le metadata local de pub cache (ou pub.dev si nécessaire), et fail le job sur toute licence ∈ {GPL*, AGPL*, copyleft-fort connus}. Pas de pre-commit local — la CI est la barrière qui ne peut pas être contournée.
- **Header GOSL v1.0 : CI uniquement.** Script Dart `tool/check_headers.dart` vérifie que les ~5 premières lignes de chaque `*.dart` (sauf `*.g.dart`, `*.freezed.dart`) contiennent l'exact bloc `// Copyright (c) 2026 THONGVAN Alexis\n// Licensed under the Good Old Software License v1.0\n// See LICENSE file for details` (matching exact, pas regex floue).
- **`DEPENDENCIES.md` à jour : CI uniquement.** Script Dart `tool/check_dependencies_md.dart` cross-référence chaque entrée de `pubspec.lock` (direct + transitive) et exige une entrée correspondante dans `DEPENDENCIES.md` (nom + version + licence + audit télémétrie). Fail CI si dérive.
- **Trois scripts unifiés** dans un workflow GitHub Actions step `lint-licence-headers-deps` qui lance les trois en séquence — fail-fast sur le premier échec.
- **Allow-list licences** définie en haut de `check_licenses.dart` : MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, Unlicense, CC0-1.0, ISC, Zlib. Toute autre licence → fail (force la documentation explicite).

### Logger scope at Phase 01 (full kit, no defer)

- **Package : `logging` 1.3.0** (BSD-3-Clause, dart.dev). Loggers hiérarchiques par couche (ex : `Logger('infrastructure.location')`).
- **Format : JSON Lines** — une ligne JSON par log : `{ts, level, logger, msg, fields}`. Tooling-friendly, aligné avec un futur viewer si besoin. Le UX support « partage fichier » suffira pour la première personne qui ouvre.
- **Sink fichier** : `<app_documents_dir>/logs/yyyymmdd_hhmm.ss_logs.txt` (un fichier par lancement d'app, conforme à FOUND-06).
- **Toggle DEBUG** :
  - `--dart-define=DEBUG=true` au build → `Logger.root.level = Level.ALL`.
  - Sans le define → niveau lu d'un flag `SharedPreferences` (`debug_logging_enabled`, défaut `false` → `Level.INFO`).
- **Bootstrap top-level handler** : `runZonedGuarded` + `FlutterError.onError` armés en `main()` pour rediriger toutes les exceptions vers le logger (niveau `SHOUT`).
- **Rotation bornée dès maintenant** : au démarrage, après création du fichier du jour, prune le plus ancien fichier de `logs/` jusqu'à ce que la taille totale du dossier soit < `kMaxLogsDirBytes` (constante dans `lib/config/constants.dart`, valeur initiale **10 MB**). Phase 15 ajoutera rotation par âge si besoin.
- **Debug menu in-app : full UI dès Phase 01.** Écran dédié `/debug` accessible via 7-tap sur le placeholder « À propos » (easter egg style Android). Contient :
  - Switch « Verbose logging » (toggle SharedPreferences ↔ Logger.root.level).
  - Liste des fichiers `logs/*.txt` triés par date desc + taille.
  - Bouton « Share log file » par fichier (via `share_plus`).
  - Bouton « Clear all logs » (avec confirmation).
  - Affichage de la valeur `--dart-define=DEBUG` au build et du flag SharedPreferences.
- **Pas de `print()`** nulle part dans `lib/`. Vérifié par règle lint `avoid_print` de `package:flutter_lints`.

### App bootstrap surface area (skeleton complet day-1)

- **Layout `lib/`** créé en intégralité avec READMEs de couche :
  ```
  lib/
    main.dart              ← bootstrap only (runZonedGuarded + FlutterError.onError + runApp)
    app.dart               ← MaterialApp.router config, theme, ProviderScope wrapper assumed external
    config/
      constants.dart       ← kAppName, kBundleId, kMaxLogsDirBytes, etc.
      README.md            ← « Constantes partagées only. Pas de logique. »
    domain/
      README.md            ← « Pas d'import flutter, drift, geolocator. Pure Dart. »
    application/
      README.md            ← « Use cases / controllers. Riverpod providers. »
    infrastructure/
      README.md            ← « Implementations (Drift, geolocator, fs). »
    presentation/
      README.md            ← « Widgets + screens. »
      screens/
        placeholder_home_screen.dart
        debug_menu_screen.dart
        about_placeholder_screen.dart
  ```
- **Pas de `custom_lint`** pour l'enforcement des règles d'import en Phase 01 — les READMEs documentent la règle, Phase 04 (review gate persistance) revérifiera. Si dérive observée, custom_lint ajouté plus tard.
- **Routing : `go_router 16.x`** (BSD-3-Clause) installé dès maintenant. Routes initiales :
  - `/` → `PlaceholderHomeScreen` (texte « MirkFall — bootstrap OK » + version)
  - `/about` → `AboutPlaceholderScreen` (texte minimal + 7-tap detector vers `/debug`)
  - `/debug` → `DebugMenuScreen` (full UI ci-dessus)
- **Code generation pipeline wirée day-1** : `build_runner` 2.4.x + `freezed` 3.2.5 + `json_serializable` 6.x + `riverpod_generator` 4.0.3 + `drift_dev` 2.32.x dans `dev_dependencies`. `build.yaml` pré-créé. Phase 03 génère son premier modèle sans toucher à `pubspec.yaml`.
- **Theme : Material 3 dark, seed `Colors.indigo`** :
  ```dart
  ThemeData.from(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  )
  ```
  Pas de mode light. Pas de `themeMode: system`. Phase 09 (fog) et Phase 15 (polish) peuvent retoucher.
- **Riverpod `ProviderScope`** wrappe `MaterialApp.router` dans `main.dart`. Pas d'override par défaut. Tests futurs pourront override via `ProviderScope(overrides: [...])`.

### Platform identity & native stubs

- **Bundle ID Android & iOS : `app.gosl.mirkfall`** (même chaîne sur les deux plateformes). Aligne avec l'umbrella GOSL et reste correct si l'auteur publie d'autres projets GOSL.
- **App display name : `MirkFall`** (verbatim, single word, capitalisé). Configuré dans `AndroidManifest.xml` `android:label` et `Info.plist` `CFBundleDisplayName`.
- **iOS Info.plist UsageDescription : pré-seed les 4 strings dès maintenant** avec placeholder text + marqueur TODO :
  - `NSLocationWhenInUseUsageDescription` = « TODO Phase 05: rationale GPS WhenInUse »
  - `NSLocationAlwaysAndWhenInUseUsageDescription` = « TODO Phase 05: rationale background location, store-grade copy en Phase 15 »
  - `NSCameraUsageDescription` = « TODO Phase 11: rationale photos markers »
  - `NSPhotoLibraryUsageDescription` = « TODO Phase 11: rationale import photo galerie »
  - Final copy locked en Phase 15 (QUAL-04, store-policy review).
- **Android `minSdkVersion = 24`** (Android 7.0, 2016) — défaut Flutter 3.41, couverture >97 %, foreground service + background location semantics propres. `targetSdkVersion` = défaut Flutter 3.41 (34 ou supérieur selon SDK installé).
- **Android `applicationId`** dans `android/app/build.gradle` = `app.gosl.mirkfall`.
- **iOS `PRODUCT_BUNDLE_IDENTIFIER`** dans `ios/Runner.xcodeproj/project.pbxproj` = `app.gosl.mirkfall`.

### Claude's Discretion

- Choix de l'action GitHub Actions exacte pour Flutter (recommandation : `subosito/flutter-action@v2`, mais audit licence à documenter dans `DEPENDENCIES.md` au même titre qu'une dep).
- Stratégie de cache CI (pub deps, Gradle, CocoaPods) — optimisation, pas blocante.
- Mécanique exacte du 7-tap detector (compteur dans state local + reset après timeout).
- Format exact du fichier `report.txt` éventuel produit par les scripts CI.
- Choix de `flutter_lints` vs `lints` package + règles ajoutées au-dessus du défaut (l'important : strict-casts/inference/raw-types activés via `analysis_options.yaml`).
- Layout exact de `DEPENDENCIES.md` (colonnes du tableau, ordre des sections) tant qu'il liste : nom, version, licence, source pub.dev/repo, résultat audit télémétrie, date.
- Texte exact du placeholder « MirkFall — bootstrap OK » et de l'écran À propos placeholder.

</decisions>

<specifics>
## Specific Ideas

- **Header GOSL v1.0 exact (3 lignes, copié textuellement de CLAUDE.md)** :
  ```
  // Copyright (c) 2026 THONGVAN Alexis
  // Licensed under the Good Old Software License v1.0
  // See LICENSE file for details
  ```
  Le matching CI doit être **exact** (pas de regex souple) pour éviter les variantes silencieuses.
- **`LICESNSE.md` à la racine est mal orthographié** — Phase 01 doit le renommer en `LICENSE.md` (et mettre à jour les références dans tout fichier qui pointe vers).
- **Discipline « solo dev » assumée** : la CI est l'autorité, pas de débat humain sur un PR. Si la CI fail, on fix. Les pre-commit hooks ajouteraient un second moteur à maintenir pour zéro bénéfice (un solo dev qui bypasse son propre hook ne va pas s'auto-discipliner mieux avec deux).
- **Aucune dépendance « marketing-friendly » au boot** (pas de splash screen lib, pas de loader anim) — l'app démarre, route vers `/`, fin.
- **Le debug menu est délibérément peu découvrable** (7-tap) : c'est un outil dev, pas une feature utilisateur. Phase 15 décidera s'il devient accessible « normalement » ou reste caché.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Aucun** — repo vide à l'exception de `CLAUDE.md` (règles projet) et `LICESNSE.md` (texte GOSL v1.0, à renommer).
- `.gitignore` existant : à étendre Phase 01 pour ignorer les artifacts Flutter (`build/`, `.dart_tool/`, `.flutter-plugins*`, `*.g.dart` non, on commit le générer en CI à voir, etc.).

### Established Patterns

- **CLAUDE.md règles** sont la convention authoritative — strictement appliquées par Phase 01 (pinned deps, header sur tout fichier, no print, no GPL, no télémétrie, naming `xxxFilename` / `xxxBasename`, etc.).
- **Recherche STACK.md** documente les versions exactes : Flutter 3.41.5, Dart 3.11, Riverpod 3.3.1, go_router 16.x, etc. — Phase 01 pin ces versions.

### Integration Points

- **`pubspec.yaml`** : créé à la racine, pin exact, sections `dependencies` / `dev_dependencies` avec audit licence dans `DEPENDENCIES.md`.
- **`analysis_options.yaml`** : activera strict-casts/inference/raw-types + règles `flutter_lints` + `avoid_print: error`.
- **`.github/workflows/ci.yml`** : un seul workflow, deux jobs parallèles `android` (ubuntu-latest) + `ios` (macos-latest), step partagé `lint-licence-headers-deps` exécuté en amont (job `gates`) qui doit passer pour que les deux builds démarrent.
- **`tool/`** : nouveau dossier pour les scripts Dart de gates (`check_licenses.dart`, `check_headers.dart`, `check_dependencies_md.dart`).
- **`DEPENDENCIES.md`** : créé à la racine, format tableau (nom | version | licence | source | audit telemetry | date).
- **`SCHEMA.md`** : pas créé en Phase 01 (créé Phase 13 import/export).

</code_context>

<deferred>
## Deferred Ideas

- **Pre-commit hook (lefthook ou autre)** — Discuté mais rejeté pour Phase 01 (CI suffit, solo dev). Re-évaluer si plusieurs contributeurs rejoignent le projet (probablement Phase post-V1.0).
- **Custom_lint pour enforcer les règles d'import inter-couches** — Si dérive observée Phase 03+ (review gate persistance), ajouter un lint custom à ce moment. Pas day-1.
- **Log rotation par âge (14 jours, etc.)** — Phase 15 (QUAL/polish). Phase 01 fait juste la borne par taille (10 MB).
- **Polished About screen avec lien GOSL + licences tierces** — Phase 15 (ABOUT-01..05). Phase 01 livre un placeholder.
- **Final copy iOS UsageDescription store-grade** — Phase 15 (QUAL-04). Phase 01 met TODO.
- **Splash screen / icône d'app finale** — Pas dans Phase 01. À traiter en Phase 15 si pertinent (ou jamais : un projet hobby GitHub n'a pas besoin de splash branded).
- **CI release artifact upload (GitHub Releases)** — Phase 15 (release). Phase 01 ne fait que builder, pas publier.
- **FVM (Flutter Version Management)** — Pas requis. Pin de version se fait dans `.tool-versions` ou la config CI.
- **Routing typé (auto_route)** — Rejeté au profit de `go_router`. Pas de re-discussion prévue.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-17*

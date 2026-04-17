# Phase 01: Foundation - Research

**Researched:** 2026-04-17
**Domain:** Flutter app bootstrap, CI gates (license/header/deps scanning), strict-mode tooling, file-sink logger, Riverpod 3 + go_router 16 skeleton
**Confidence:** HIGH (CONTEXT.md locked most decisions; verification focused on current API shapes and CI plumbing)

## Summary

Phase 01 ships an empty-but-running Flutter app skeleton that proves the Day-1 garde-fous work end-to-end: a pinned `pubspec.yaml` with a fully audited dependency set, a strict `analysis_options.yaml` with zero warnings, a CI pipeline (Android `ubuntu-latest` + iOS `macos-latest --no-codesign`) that fails on (a) any non-allowlisted license — direct or transitive, (b) any `.dart` file missing the exact GOSL v1.0 header, (c) any drift between `pubspec.lock` and `DEPENDENCIES.md`. A file-sink logger in JSON-Lines format with a debug menu is wired in `main.dart`, and the full layered `lib/` skeleton (`config/domain/application/infrastructure/presentation`) is created with READMEs documenting the dependency rule.

CONTEXT.md decisions are extremely prescriptive; this research focused on (1) verifying the current API shapes (Riverpod 3.x, go_router 16, share_plus 13, geolocator 14 — not used here but installed), (2) flagging one significant tension between CONTEXT.md and current best practice (see "Important Discrepancy" below), (3) supplying concrete CI YAML and Dart-script skeletons the planner can lift directly, and (4) confirming SDK constraint syntax for "exact pinning" given Flutter/Dart quirks.

**Important discrepancy to flag with user:** CONTEXT.md mandates `runZonedGuarded` + `FlutterError.onError` for the top-level error handler. **Current Flutter best practice (3.10+) treats `runZonedGuarded` as an anti-pattern** because it produces "Zone mismatch" errors with `WidgetsFlutterBinding.ensureInitialized()` and other framework hooks. The recommended modern pattern is `FlutterError.onError` + `PlatformDispatcher.onError` + `Isolate.current.addErrorListener` (no zone wrapping). This research surfaces both options; planner/user should make the call. This is a *quality* concern, not a blocker — `runZonedGuarded` still works.

**Primary recommendation:** Implement Phase 01 in this Wave order: (Wave 0) project init + LICENSE rename + .gitignore overhaul, (Wave 1) `pubspec.yaml` + `analysis_options.yaml` + `lib/` skeleton + bootstrap, (Wave 2) logger + debug menu + about placeholder + go_router, (Wave 3) `tool/` CI scripts + `DEPENDENCIES.md` stub, (Wave 4) `.github/workflows/ci.yml`. Test infra (`test/` + `flutter_test`) is wired in Wave 1 alongside the analyzer. Native platform identity (`AndroidManifest.xml`, `Info.plist`) is touched only in Wave 1 — minimal edits.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### License enforcement gates (CI-only, transitives included)

- **GPL/AGPL/copyleft-fort scan : CI uniquement.** Script Dart `tool/check_licenses.dart` qui parse `pubspec.lock`, résout chaque package (direct + **toutes les transitives**) via le metadata local de pub cache (ou pub.dev si nécessaire), et fail le job sur toute licence ∈ {GPL*, AGPL*, copyleft-fort connus}. Pas de pre-commit local — la CI est la barrière qui ne peut pas être contournée.
- **Header GOSL v1.0 : CI uniquement.** Script Dart `tool/check_headers.dart` vérifie que les ~5 premières lignes de chaque `*.dart` (sauf `*.g.dart`, `*.freezed.dart`) contiennent l'exact bloc `// Copyright (c) 2026 THONGVAN Alexis\n// Licensed under the Good Old Software License v1.0\n// See LICENSE file for details` (matching exact, pas regex floue).
- **`DEPENDENCIES.md` à jour : CI uniquement.** Script Dart `tool/check_dependencies_md.dart` cross-référence chaque entrée de `pubspec.lock` (direct + transitive) et exige une entrée correspondante dans `DEPENDENCIES.md` (nom + version + licence + audit télémétrie). Fail CI si dérive.
- **Trois scripts unifiés** dans un workflow GitHub Actions step `lint-licence-headers-deps` qui lance les trois en séquence — fail-fast sur le premier échec.
- **Allow-list licences** définie en haut de `check_licenses.dart` : MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, Unlicense, CC0-1.0, ISC, Zlib. Toute autre licence → fail (force la documentation explicite).

#### Logger scope at Phase 01 (full kit, no defer)

- **Package : `logging` 1.3.0** (BSD-3-Clause, dart.dev). Loggers hiérarchiques par couche (ex : `Logger('infrastructure.location')`).
- **Format : JSON Lines** — une ligne JSON par log : `{ts, level, logger, msg, fields}`. Tooling-friendly, aligné avec un futur viewer si besoin.
- **Sink fichier** : `<app_documents_dir>/logs/yyyymmdd_hhmm.ss_logs.txt` (un fichier par lancement d'app, conforme à FOUND-06).
- **Toggle DEBUG** :
  - `--dart-define=DEBUG=true` au build → `Logger.root.level = Level.ALL`.
  - Sans le define → niveau lu d'un flag `SharedPreferences` (`debug_logging_enabled`, défaut `false` → `Level.INFO`).
- **Bootstrap top-level handler** : `runZonedGuarded` + `FlutterError.onError` armés en `main()` pour rediriger toutes les exceptions vers le logger (niveau `SHOUT`).
- **Rotation bornée dès maintenant** : au démarrage, après création du fichier du jour, prune le plus ancien fichier de `logs/` jusqu'à ce que la taille totale du dossier soit < `kMaxLogsDirBytes` (constante dans `lib/config/constants.dart`, valeur initiale **10 MB**).
- **Debug menu in-app : full UI dès Phase 01.** Écran dédié `/debug` accessible via 7-tap sur le placeholder « À propos » (easter egg style Android). Contient :
  - Switch « Verbose logging » (toggle SharedPreferences ↔ Logger.root.level).
  - Liste des fichiers `logs/*.txt` triés par date desc + taille.
  - Bouton « Share log file » par fichier (via `share_plus`).
  - Bouton « Clear all logs » (avec confirmation).
  - Affichage de la valeur `--dart-define=DEBUG` au build et du flag SharedPreferences.
- **Pas de `print()`** nulle part dans `lib/`. Vérifié par règle lint `avoid_print` de `package:flutter_lints`.

#### App bootstrap surface area (skeleton complet day-1)

- **Layout `lib/`** créé en intégralité avec READMEs de couche (voir `<code_examples>` pour structure exacte).
- **Pas de `custom_lint`** pour l'enforcement des règles d'import en Phase 01 — les READMEs documentent la règle.
- **Routing : `go_router 16.x`** (BSD-3-Clause). Routes initiales :
  - `/` → `PlaceholderHomeScreen`
  - `/about` → `AboutPlaceholderScreen` (7-tap detector vers `/debug`)
  - `/debug` → `DebugMenuScreen`
- **Code generation pipeline wirée day-1** : `build_runner` 2.x + `freezed` 3.2.5 + `json_serializable` 6.x + `riverpod_generator` 4.0.3 + `drift_dev` (NOTE : drift_dev pas mentionné dans STACK.md mais cohérent avec Phase 03 — voir Open Questions).
- **Theme : Material 3 dark, seed `Colors.indigo`**, pas de mode light.
- **Riverpod `ProviderScope`** wrappe `MaterialApp.router` dans `main.dart`.

#### Platform identity & native stubs

- **Bundle ID Android & iOS : `app.gosl.mirkfall`**.
- **App display name : `MirkFall`** (verbatim, capitalisé).
- **iOS Info.plist UsageDescription : pré-seed les 4 strings dès maintenant** avec placeholder TODO (NSLocationWhenInUse, NSLocationAlwaysAndWhenInUse, NSCameraUsage, NSPhotoLibraryUsage).
- **Android `minSdkVersion = 24`** (Android 7.0).
- **Android `applicationId`** = `app.gosl.mirkfall`.
- **iOS `PRODUCT_BUNDLE_IDENTIFIER`** = `app.gosl.mirkfall`.

### Claude's Discretion

- Choix de l'action GitHub Actions exacte pour Flutter (recommandation : `subosito/flutter-action@v2`, mais audit licence à documenter dans `DEPENDENCIES.md`).
- Stratégie de cache CI (pub deps, Gradle, CocoaPods) — optimisation, pas blocante.
- Mécanique exacte du 7-tap detector (compteur dans state local + reset après timeout).
- Format exact du fichier `report.txt` éventuel produit par les scripts CI.
- Choix de `flutter_lints` vs `lints` package + règles ajoutées au-dessus du défaut.
- Layout exact de `DEPENDENCIES.md` (colonnes du tableau, ordre des sections).
- Texte exact du placeholder « MirkFall — bootstrap OK » et de l'écran À propos placeholder.

### Deferred Ideas (OUT OF SCOPE)

- **Pre-commit hook (lefthook ou autre)** — Re-évaluer si plusieurs contributeurs rejoignent le projet (probablement Phase post-V1.0).
- **Custom_lint pour enforcer les règles d'import inter-couches** — Si dérive observée Phase 03+ (review gate persistance), ajouter à ce moment. Pas day-1.
- **Log rotation par âge (14 jours, etc.)** — Phase 15 (QUAL/polish). Phase 01 fait juste la borne par taille (10 MB).
- **Polished About screen avec lien GOSL + licences tierces** — Phase 15 (ABOUT-01..05). Phase 01 livre un placeholder.
- **Final copy iOS UsageDescription store-grade** — Phase 15 (QUAL-04). Phase 01 met TODO.
- **Splash screen / icône d'app finale** — Pas dans Phase 01.
- **CI release artifact upload (GitHub Releases)** — Phase 15 (release). Phase 01 ne fait que builder, pas publier.
- **FVM (Flutter Version Management)** — Pas requis. Pin de version dans `.tool-versions` ou config CI.
- **Routing typé (auto_route)** — Rejeté au profit de `go_router`. Pas de re-discussion prévue.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUND-01 | Repo Flutter initialisé avec `analysis_options.yaml` strict (`strict-casts`, `strict-inference`, `strict-raw-types`) | Code example "analysis_options.yaml strict mode" + `flutter_lints 6.0.0` baseline + per Pitfall #21 set `use_build_context_synchronously: error` |
| FOUND-02 | Chaque fichier source contient le header GOSL v1.0 obligatoire | Header text verbatim from CLAUDE.md; `tool/check_headers.dart` enforces in CI; exact-match policy (no regex) per CONTEXT.md |
| FOUND-03 | `DEPENDENCIES.md` à la racine, tenu à jour | Stub layout in code example; `tool/check_dependencies_md.dart` cross-references `pubspec.lock` |
| FOUND-04 | Pipeline GitHub Actions CI construit APK Android + iOS unsigned | `subosito/flutter-action@v2` with `cache: true`; Android job on `ubuntu-latest` runs `flutter build apk`; iOS job on `macos-latest` runs `pod install` then `flutter build ipa --no-codesign`; gates job runs first |
| FOUND-05 | Versions des dépendances `pubspec.yaml` strictement pinnées | Use exact `package: 1.2.3` (no `^`); `pubspec.lock` committed; SDK constraint exception documented (see Pitfall #1) |
| FOUND-06 | Logger configurable + logs dans `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` | `logging 1.3.0` + custom file sink; JSON Lines; debug menu UI in `/debug`; `--dart-define=DEBUG=true` toggles `Logger.root.level` |
| FOUND-07 | Constantes partagées centralisées dans `lib/config/constants.dart` | Initial constants: `kAppName`, `kBundleId`, `kMaxLogsDirBytes` (10 MB), `kAppDisplayName`, plus stubs for future phases |
| FOUND-08 | `flutter analyze` zéro warning + `dart format` appliqué partout | CI step `flutter analyze --fatal-infos --fatal-warnings`; `dart format --set-exit-if-changed .` as a separate CI step |
</phase_requirements>

## Standard Stack

### Core (Day-1 hard runtime dependencies for Phase 01)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | 3.41.5 | App framework | Stable Feb 2026; pinned via CI matrix and `.tool-versions`. BSD-3-Clause. |
| Dart SDK | 3.11.x (bundled) | Language | Pattern matching, sealed classes, records. |
| `flutter_riverpod` | `3.3.1` | State management + DI | Sole project-wide system per CLAUDE.md. Riverpod 3.x: legacy `StateNotifierProvider` deprecated, `Notifier` API standard. MIT. |
| `riverpod_annotation` | `3.0.3` | Codegen annotations | Aligned with `flutter_riverpod 3.3.x`. MIT. |
| `go_router` | `16.0.0` (or current 16.x patch) | Navigation | BSD-3-Clause. Configured via `MaterialApp.router(routerConfig:)`. |
| `logging` | `1.3.0` | Structured logger | dart.dev publisher, BSD-3-Clause. Hierarchical loggers. |
| `path_provider` | `2.1.5` | App docs dir for logs | flutter.dev publisher, BSD-3-Clause. |
| `path` | `1.9.1` | `p.join()` cross-platform path manipulation | dart.dev, BSD-3-Clause. **Mandatory per CLAUDE.md** (no `/` or `\` concat). |
| `shared_preferences` | `2.5.5` | Persists `debug_logging_enabled` flag | flutter.dev, BSD-3-Clause. |
| `share_plus` | `13.0.0` | Debug menu "share log file" button | fluttercommunity.dev, BSD-3-Clause. Uses `ShareParams(files: [XFile(path)])`. |

### Supporting (already in pubspec from STACK.md, declared in Phase 01 to lock pin)

The full STACK.md set is declared in `pubspec.yaml` in Phase 01 even though most are unused until later phases. This pins them, audits them in `DEPENDENCIES.md`, and proves the CI gates work against the real dep graph.

| Library | Version | Used in phase | Reason to declare day-1 |
|---------|---------|---------------|------------------------|
| `flutter_map` | `8.3.0` | Phase 07 | Lock pin, audit in DEPENDENCIES.md |
| `latlong2` | `0.9.1` | Phase 07 | Same |
| `geolocator` | `14.0.2` | Phase 05 | Same; influences Android `minSdkVersion`/`compileSdkVersion` |
| `permission_handler` | `12.0.1` | Phase 05 | Same |
| `flutter_local_notifications` | `21.0.0` | Phase 05 | Same |
| `drift` | `2.32.1` | Phase 03 | Same |
| `drift_flutter` | `0.3.0` | Phase 03 | Same |
| `sqlite3_flutter_libs` | `0.5.29` | Phase 03 | Same |
| `image_picker` | `1.2.1` | Phase 11 | Same |
| `freezed_annotation` | `3.1.0` | Phase 03+ | Same |
| `json_annotation` | `4.9.0` | Phase 03+ | Same |
| `file_picker` | `11.0.2` | Phase 13 | Same |
| `collection` | `1.19.1` | All | Same |

### Dev Dependencies

| Library | Version | License | Purpose |
|---------|---------|---------|---------|
| `flutter_test` | SDK | BSD-3-Clause | Unit + widget tests |
| `flutter_lints` | `6.0.0` | BSD-3-Clause | Baseline lint rules — recommended single source vs `very_good_analysis` |
| `build_runner` | `2.13.1` | BSD-3-Clause | Drives all codegen |
| `freezed` | `3.2.5` | MIT | Immutable models codegen |
| `json_serializable` | `6.13.1` | BSD-3-Clause | JSON codegen |
| `riverpod_generator` | `4.0.3` | MIT | Riverpod provider codegen |
| `custom_lint` | `0.7.5` | MIT | Riverpod lint runtime |
| `riverpod_lint` | `3.3.1` | MIT | Riverpod-specific analyzer rules |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `flutter_lints` 6.0.0 (recommended) | `very_good_analysis` 10.2.0 | VGA is stricter (e.g. `prefer_const_constructors` as error, `avoid_redundant_argument_values`) but doesn't change the strict-mode behaviour — that's set under `analyzer.language` regardless. Recommend `flutter_lints` (smaller surface, single official baseline) and add a custom rule list for what we want stricter. CONTEXT.md left this as Claude's discretion. |
| `runZonedGuarded` (per CONTEXT.md) | `PlatformDispatcher.onError` (current Flutter best practice) | See "Important Discrepancy" in summary. Recommend asking the user before deviating from CONTEXT.md. |
| `lints` package (raw Dart) | `flutter_lints` | `lints` is for pure-Dart packages; `flutter_lints` extends it with Flutter-aware rules. Use `flutter_lints`. |

**Installation:** see "Code Examples → pubspec.yaml" below.

## Architecture Patterns

### Recommended Project Structure (full skeleton, day-1)

Per CONTEXT.md decision, create the **full layered structure** with READMEs documenting the dependency rule, even though `domain/`, `application/`, `infrastructure/` are mostly empty in Phase 01.

```
GOSL-MirkFall/
├── .github/
│   └── workflows/
│       └── ci.yml                  # gates job + android job + ios job
├── android/                        # generated by `flutter create`, then minSdk=24, applicationId set
├── ios/                            # generated by `flutter create`, then bundle ID + Info.plist seeded
├── lib/
│   ├── main.dart                   # bootstrap only (error handlers + ProviderScope + runApp)
│   ├── app.dart                    # MaterialApp.router + theme
│   ├── config/
│   │   ├── constants.dart          # kAppName, kBundleId, kMaxLogsDirBytes, ...
│   │   └── README.md               # "Constantes partagées only. Pas de logique."
│   ├── domain/
│   │   └── README.md               # "Pas d'import flutter, drift, geolocator. Pure Dart."
│   ├── application/
│   │   └── README.md               # "Use cases / controllers. Riverpod providers."
│   ├── infrastructure/
│   │   ├── logging/
│   │   │   └── file_logger.dart    # the JSON-Lines file sink + bootstrap
│   │   └── README.md               # "Implementations (Drift, geolocator, fs)."
│   └── presentation/
│       ├── README.md               # "Widgets + screens."
│       ├── router.dart             # GoRouter config exposed as a Riverpod provider
│       └── screens/
│           ├── placeholder_home_screen.dart
│           ├── about_placeholder_screen.dart
│           └── debug_menu_screen.dart
├── test/
│   └── smoke_test.dart             # widget test that the app boots without throwing
├── tool/
│   ├── check_licenses.dart         # parses pubspec.lock, scans pub-cache for LICENSE files
│   ├── check_headers.dart          # ensures every lib/**/*.dart starts with the GOSL header
│   └── check_dependencies_md.dart  # cross-refs pubspec.lock with DEPENDENCIES.md
├── analysis_options.yaml           # strict-casts/inference/raw-types + flutter_lints
├── build.yaml                      # build_runner config (placeholder for codegen pipeline)
├── pubspec.yaml                    # pinned dependencies (no caret)
├── pubspec.lock                    # committed
├── DEPENDENCIES.md                 # one row per direct + transitive dep
├── LICENSE.md                      # renamed from LICESNSE.md (typo fix)
├── README.md                       # minimal "MirkFall: see PROJECT.md"
└── CLAUDE.md                       # already exists, untouched
```

### Pattern 1: Top-Level Error Handler (recommendation: hybrid)

**What:** Catch every exception that escapes the framework or async tasks; route to the file logger.

**When to use:** In `main.dart` only.

**CONTEXT.md spec:** `runZonedGuarded` + `FlutterError.onError`.
**Current Flutter best practice (3.10+):** `FlutterError.onError` + `PlatformDispatcher.onError` + `Isolate.current.addErrorListener` (no `runZonedGuarded`).

**Recommendation:** Implement BOTH — let `FlutterError.onError` and `PlatformDispatcher.onError` handle the common path (recommended), and keep `runZonedGuarded` as the outer wrapper per CONTEXT.md (it still works, just slightly redundant). If the planner wants to drop `runZonedGuarded` to align with current Flutter idioms, **flag it for user confirmation** since CONTEXT.md is explicit. See Code Examples for both variants.

### Pattern 2: Riverpod 3 + go_router 16 wiring

**What:** `ProviderScope` wraps `MaterialApp.router`. `GoRouter` is exposed as a Riverpod provider so it can be referenced from any consumer (e.g., a future deep-link redirect provider).

**When to use:** App root, exactly once.

```dart
// lib/presentation/router.dart
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PlaceholderHomeScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutPlaceholderScreen()),
      GoRoute(path: '/debug', builder: (_, __) => const DebugMenuScreen()),
    ],
  );
}

// lib/app.dart
class MirkFallApp extends ConsumerWidget {
  const MirkFallApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: kAppName,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

### Pattern 3: File Logger (JSON Lines)

**What:** Custom `Level` → `LogRecord` handler that writes one JSON object per line to today's log file, with a periodic flush + a startup prune to enforce `kMaxLogsDirBytes`.

**Key choices:**
- One file per app launch (`yyyymmdd_hhmm.ss_logs.txt`) — matches CLAUDE.md spec.
- Use `IOSink` opened in append mode, `await sink.flush()` on every record (cheap on local FS, prevents loss on crash).
- JSON Lines (`{"ts":"...","level":"INFO","logger":"app","msg":"...","fields":{}}\n`) — tooling-friendly.
- Prune on startup: list `logs/*.txt` sorted oldest-first, delete until `dir_size < kMaxLogsDirBytes`. Don't run in a hot loop.
- The `Logger` instance is exposed via Riverpod provider so any consumer gets it via DI (not a global).

### Pattern 4: 7-Tap Easter Egg

**What:** Track tap count + last tap timestamp inside `AboutPlaceholderScreen`'s State. If 7 taps within 3 s, navigate to `/debug`.

```dart
class _AboutPlaceholderScreenState extends State<AboutPlaceholderScreen> {
  int _tapCount = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  static const _windowMs = 3000;
  static const _tapsToTrigger = 7;

  void _onTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds > _windowMs) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTap = now;
    if (_tapCount >= _tapsToTrigger) {
      _tapCount = 0;
      context.go('/debug');
    }
  }
  // ...
}
```

### Anti-Patterns to Avoid

- **Hidden global singletons** (`get_it` style) — violates CLAUDE.md DI rules. Use Riverpod providers.
- **`print()` anywhere in `lib/`** — `avoid_print: error` in `analysis_options.yaml` enforces this.
- **Magic numbers** in code (e.g. `if (tapCount >= 7)` outside config) — extract to constants per CLAUDE.md. The 7-tap counter is borderline but `_tapsToTrigger`/`_windowMs` are private locals at the right scope, so OK.
- **`!` (bang operator) without prior null check** — strict-mode catches most; review for `Future.value(x).then((v) => v!)` patterns.
- **`dynamic` without comment justifying it** — strict-raw-types catches inferred `dynamic`; use `Object?` if you really mean "unknown".
- **`await` followed by `BuildContext` use without `mounted` check** — `use_build_context_synchronously` lint catches; keep at error level (Pitfall #21 in research/PITFALLS.md).
- **Concatenating paths with `/` or `\\`** — use `p.join()` from `package:path`.
- **`then()` instead of `await`** — CLAUDE.md explicit ban without justification.
- **Putting bootstrap logic in `main()` body** — `main.dart` only does error-handler + `runApp`. The actual bootstrap (logger init, prune, ProviderScope) lives in `bootstrap.dart` or `app.dart`.
- **Pre-commit hooks for the gates** — explicitly out of scope per CONTEXT.md. CI is the authority.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-platform app docs path | manual `Platform.isAndroid ? '...' : '...'` | `path_provider.getApplicationDocumentsDirectory()` | Handles iOS sandbox UUID changes, scoped storage, Android app-specific dirs |
| Path joining | `'$dir/$file'` or `'$dir\\$file'` | `p.join(dir, file)` | CLAUDE.md mandates; handles Windows separators automatically (matters for desktop dev runs) |
| Persisting debug toggle | manual file or env var | `shared_preferences` | OS-managed key-value, atomic, survives app updates |
| Sharing a log file | custom intent / activity | `share_plus` `ShareParams` | OS share sheet, FileProvider auto-config on Android |
| JSON encoding for logs | string concat | `dart:convert` `jsonEncode` | Escapes properly, handles unicode |
| Routing | hand-written `Navigator` stack | `go_router` | Browser back-button on web, deep links, type safety with named routes |
| State management | global mutable singleton | `Riverpod` (project-wide single choice) | CLAUDE.md mandates a single system; constructor-injection-friendly |
| Pinning Flutter SDK locally | manual env switching | `.tool-versions` (asdf/mise) or CI matrix | Matches deterministic-build philosophy |
| License scanning | regex over `pubspec.lock` from scratch | `dart_license_checker --show-transitive-dependencies` (MIT) OR custom Dart script reading pub-cache LICENSE files | `dart_license_checker` is mature; CONTEXT.md prefers a custom script for fewer deps — both viable. **Audit `dart_license_checker` license itself if importing.** |
| Header check across many files | shell `grep`/`awk` | small Dart script in `tool/` | Same toolchain as CI step; cross-platform; testable |

**Key insight:** Phase 01's whole reason to exist is to make these "boring" choices once and lock them. Hand-rolling a license scanner is fine *if* it's properly tested — CONTEXT.md prefers fewer deps, so a hand-written `tool/check_licenses.dart` is the recommended path. But the scanner itself must be carefully written: parse `.dart_tool/package_config.json` to find each package's resolved path, then grep that package's root for `LICENSE` / `LICENSE.md` / `LICENSE.txt`, then SPDX-match the content (or use the `license:` field declared in each package's `pubspec.yaml` if present).

## Common Pitfalls

### Pitfall 1: SDK constraint cannot be exact
**What goes wrong:** Setting `environment.sdk: "3.11.0"` (no operator) makes `pub get` fail or behave inconsistently. Setting `environment.flutter: "3.41.5"` does not actually pin the Flutter SDK to that version (Flutter SDK pinning is enforced by the local Flutter install, not pub).
**Why it happens:** SDK constraints are special-cased in pub: they expect a *range*, not an exact pin. The exact-pin philosophy applies to packages, not SDKs.
**How to avoid:**
- For Dart SDK: `sdk: ">=3.11.0 <4.0.0"` (or tighter `>=3.11.0 <3.12.0` if you want strict).
- For Flutter SDK: `flutter: ">=3.41.0 <3.42.0"` and pin the *actual installed Flutter version* via `.tool-versions` (mise/asdf) and the CI workflow's `subosito/flutter-action@v2 with flutter-version: 3.41.5`.
**Warning signs:** `flutter pub get` complains about SDK constraint syntax; `pubspec.lock` regenerates with different SDK version on different machines.
**Source:** [Dart SDK constraint discussion #44072](https://github.com/dart-lang/sdk/issues/44072), [Flutter exact-version issue #113169](https://github.com/flutter/flutter/issues/113169)

### Pitfall 2: `runZonedGuarded` zone mismatch in Flutter 3.10+
**What goes wrong:** Wrapping `runApp` inside `runZonedGuarded` while ALSO calling `WidgetsFlutterBinding.ensureInitialized()` triggers "Zone mismatch" assertions in dev mode and can break Flutter framework hooks. Some Sentry / Crashlytics integrations recommend dropping `runZonedGuarded` for this reason.
**Why it happens:** Flutter framework calls `Zone.current` at init time; if `WidgetsFlutterBinding.ensureInitialized()` is called inside the zone but the zone is the wrong one, framework asserts fail.
**How to avoid:**
- **Modern path:** drop `runZonedGuarded` entirely; use `FlutterError.onError` (sync framework errors) + `PlatformDispatcher.onError` (async errors outside framework) + `Isolate.current.addErrorListener` (other isolates).
- **CONTEXT.md path:** keep `runZonedGuarded` BUT call `WidgetsFlutterBinding.ensureInitialized()` *inside* the zone, not outside.
**Warning signs:** Assertion errors mentioning "Zone mismatch"; intermittent test failures; some plugins (notably anything using method channels at startup) misbehave.
**Source:** [donny — Flutter 3.10 zone mismatch](https://medium.com/@ipsak2.dl/%ED%94%8C%EB%9F%AC%ED%84%B0-3-10-%EC%9D%B4%ED%9B%84-zone-mismatch-%EC%83%9D%EA%B8%B0%EB%8A%94-%EB%AC%B8%EC%A0%9C-%ED%95%B4%EA%B2%B0%ED%95%98%EA%B8%B0-eed81a814cc7), [Mastering error handling in Dart (lazebny.io)](https://lazebny.io/mastering-error-handling/), [Sentry Flutter usage docs](https://docs.sentry.io/platforms/flutter/usage/)

### Pitfall 3: macos-latest CI Xcode version drift
**What goes wrong:** `macos-latest` runner image bumps Xcode versions (sometimes mid-week). A Flutter version that worked on Xcode 15.4 may crash with `xcodebuild -list` on Xcode 16.x. CI starts failing without a code change.
**Why it happens:** GitHub auto-rolls the runner image. Flutter's iOS build tools sometimes lag.
**How to avoid:**
- Pin Xcode explicitly: `maxim-lobanov/setup-xcode@v1 with xcode-version: '16.1'` before the Flutter install step.
- Pin the runner: prefer `macos-14` or `macos-15` over `macos-latest` (lock to a known-good macOS version).
- Pin Flutter: `flutter-version: 3.41.5` exact, never `stable` channel.
**Warning signs:** CI green for weeks then suddenly red on iOS step with `xcodebuild` errors; runs fine locally on the dev's mac.
**Source:** [subosito/flutter-action issue #358](https://github.com/subosito/flutter-action/issues/358)

### Pitfall 4: `lock` file in `.gitignore`
**What goes wrong:** Current `.gitignore` (the upstream Flutter repo's gitignore, copy-pasted into this project) has `*.lock` on line 4 — this would make Git ignore `pubspec.lock`, defeating the entire pinned-deps strategy.
**Why it happens:** The current `.gitignore` is from `flutter/flutter` upstream, not a Flutter app. Apps MUST commit `pubspec.lock`.
**How to avoid:** Replace `.gitignore` entirely with a **Flutter-app** gitignore (the one `flutter create` generates). Wave 0 task. Verify `pubspec.lock` is tracked after the swap.
**Warning signs:** `git status` shows `pubspec.lock` as untracked; `flutter pub get` produces different lock contents on different machines.

### Pitfall 5: Missing GOSL header on generated files
**What goes wrong:** `*.g.dart` and `*.freezed.dart` files are generated by `build_runner`. They DON'T contain the GOSL header. If `tool/check_headers.dart` doesn't exclude them, the gate fails on every build.
**Why it happens:** `build_runner` doesn't know about project-specific headers; configuring it to add headers is fragile.
**How to avoid:**
- Exclude the standard codegen suffixes in `check_headers.dart`: `*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`, plus anything under `lib/generated/`.
- Add the exclude patterns also to `analysis_options.yaml` `analyzer.exclude` list (good practice anyway, generated code shouldn't be linted).
**Warning signs:** First post-codegen CI run fails with "missing header"; dev runs `dart run build_runner build` then `flutter analyze` complains in generated files.

### Pitfall 6: `pubspec.lock` and `DEPENDENCIES.md` drift
**What goes wrong:** A planned dep bump in Phase N updates `pubspec.lock` but the dev forgets to update `DEPENDENCIES.md`. CI fails (good!) but the fix is annoying because the script's error message must be precise.
**Why it happens:** Two sources of truth.
**How to avoid:**
- `tool/check_dependencies_md.dart` outputs **diff lines**: "Missing in DEPENDENCIES.md: `freezed 3.2.5`. Extra in DEPENDENCIES.md: `freezed 3.2.4`."
- Optionally generate `DEPENDENCIES.md` from `pubspec.lock` + a manual `audit/` directory of per-package audit notes — would eliminate drift but is more complex than CONTEXT.md scope. Defer.
**Warning signs:** Dev complains "the dep check is annoying" → improve the error messages, don't relax the rule.

### Pitfall 7: License scanner false-positives on dual-licensed packages
**What goes wrong:** `image_picker` is dual-licensed (Apache-2.0 + BSD-3-Clause). A naive scanner reading the LICENSE file may report "Apache-2.0" only, OR may report "Apache-2.0 OR BSD-3-Clause" depending on exact text. If allowlist is exact-match, this fails.
**Why it happens:** SPDX expressions can be compound; license files are often hand-written.
**How to avoid:**
- Allowlist matches against ANY license in a compound expression (`Apache-2.0 OR BSD-3-Clause` passes if either Apache-2.0 OR BSD-3-Clause is allowed).
- Maintain a manual override table: for known-good packages whose LICENSE files don't parse cleanly, hardcode the SPDX identifier.
- `pub.dev` shows the SPDX-resolved license per package — cross-check.
**Warning signs:** `image_picker` flagged as "unknown license"; transitive deps with custom LICENSE wording fail to parse.
**Source:** [pub.dev/image_picker license field](https://pub.dev/packages/image_picker), [SPDX expression syntax](https://spdx.dev/learn/handling-license-info/)

### Pitfall 8: Logger sink left open on hot reload
**What goes wrong:** Hot-reload in dev re-runs `main()` but doesn't close the previous `IOSink`. Multiple file handles to the same log file accumulate; on Windows specifically, "file in use" errors block the next launch.
**Why it happens:** `IOSink` is a long-lived OS resource; hot-reload bypasses normal teardown.
**How to avoid:**
- Make the file logger idempotent: store the active sink in a static `ValueNotifier`; on init, close any previous sink before opening a new one.
- Use `WidgetsBinding.instance.addObserver` + `AppLifecycleState.detached` to flush on app exit (best-effort; not guaranteed on iOS force-quit).
- Don't worry about full crash-safety in Phase 01 — `await sink.flush()` after each record is good enough.
**Warning signs:** Multiple incomplete log files after a dev session; "file in use" errors on Windows.

### Pitfall 9: Dependency-transitive GPL contamination
**What goes wrong:** A direct dep is MIT, but its transitive graph pulls a GPL-licensed package. CI must catch this.
**Why it happens:** `pub.dev` shows the direct license, not the transitive graph; `flutter pub deps` is JSON output that needs scripting.
**How to avoid:** This is exactly what `tool/check_licenses.dart` is for — must walk the **full** transitive set from `pubspec.lock`, not just direct deps. `dart pub deps --json` is the input.
**Warning signs:** New transitive package appears in `pubspec.lock` after an unrelated dep update.
**Source:** PITFALLS.md research §9, [STACK.md note on FMTC GPL-3.0](https://pub.dev/packages/flutter_map_tile_caching)

### Pitfall 10: Silent telemetry from a dep update
**What goes wrong:** A minor version bump (which we prevent via pinning) of a dep adds an analytics SDK. CONTEXT.md gates only license + header + drift — telemetry is an audit concern, not yet a CI gate.
**Why it happens:** Telemetry is hard to detect statically; STACK.md research §10 details this.
**How to avoid:** For Phase 01, document the workflow in `DEPENDENCIES.md`: "Every version bump audited (changelog + grep for `http`, `dio`, `analytics`, `firebase_*`, `sentry`, `mixpanel`)." A future phase (Phase 15 QUAL-05) can add a CI integration test that runs the app under a network proxy and asserts zero outbound HTTP in the idle flow.
**Warning signs:** New transitive dep with `*_analytics`, `*_crashlytics`, `firebase_*`, `sentry_*`, `appsflyer`, `adjust` in name.

### Pitfall 11: `setState` / `BuildContext` after async-gap (Phase 01 lint enforcement)
**What goes wrong:** Even in Phase 01's tiny UI (debug menu's "Share log file"), an `await` then `context.go(...)` without `mounted` check crashes if the widget disposed during the await.
**Why it happens:** Easy to forget; `flutter_lints` includes `use_build_context_synchronously` but at warning level by default.
**How to avoid:** Set `use_build_context_synchronously: error` in `analysis_options.yaml` `analyzer.errors`. Mandate `if (!context.mounted) return;` after every `await`.
**Warning signs:** `flutter analyze` warnings; debug menu actions throw "setState after dispose" intermittently.
**Source:** PITFALLS.md research §21, CLAUDE.md "Async / BuildContext" section.

## Code Examples

Verified patterns; sources cited inline.

### `pubspec.yaml` (Phase 01 baseline)

```yaml
# Source: STACK.md (verified versions) + Pitfall 1 (SDK constraint syntax)
name: mirkfall
description: Fog-of-war world map for real-life exploration. GOSL v1.0.
publish_to: none
version: 1.0.0+1

environment:
  sdk: ">=3.11.0 <4.0.0"            # SDK ranges, not exact pin (Pitfall 1)
  flutter: ">=3.41.0 <3.42.0"

dependencies:
  flutter:
    sdk: flutter

  # Phase 01 runtime
  flutter_riverpod: 3.3.1
  riverpod_annotation: 3.0.3
  go_router: 16.0.0
  logging: 1.3.0
  path_provider: 2.1.5
  path: 1.9.1
  shared_preferences: 2.5.5
  share_plus: 13.0.0

  # Pinned for later phases (declared day-1 to lock + audit)
  flutter_map: 8.3.0
  latlong2: 0.9.1
  geolocator: 14.0.2
  permission_handler: 12.0.1
  flutter_local_notifications: 21.0.0
  drift: 2.32.1
  drift_flutter: 0.3.0
  sqlite3_flutter_libs: 0.5.29
  image_picker: 1.2.1
  freezed_annotation: 3.1.0
  json_annotation: 4.9.0
  file_picker: 11.0.2
  collection: 1.19.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 6.0.0
  build_runner: 2.13.1
  freezed: 3.2.5
  json_serializable: 6.13.1
  riverpod_generator: 4.0.3
  custom_lint: 0.7.5
  riverpod_lint: 3.3.1

flutter:
  uses-material-design: true
```

### `analysis_options.yaml`

```yaml
# Source: dart.dev/tools/analysis (strict mode), flutter_lints package, CLAUDE.md
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    # Make selected lints fatal
    avoid_print: error                         # CLAUDE.md ban
    use_build_context_synchronously: error     # PITFALLS.md §21
    missing_required_param: error
    missing_return: error
    todo: ignore                               # we use `// TODO` markers liberally in Phase 01
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated/**"
    - "build/**"

linter:
  rules:
    # Above flutter_lints baseline:
    avoid_print: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    prefer_final_locals: true
    prefer_final_in_for_each: true
    use_super_parameters: true
    avoid_redundant_argument_values: true
    require_trailing_commas: true              # auto-formatted by `dart format`

# riverpod_lint runs via custom_lint; activate by:
#   1. Add `custom_lint` to dev_dependencies (done)
#   2. Run `dart run custom_lint` in CI (separate step)
```

### `main.dart` (CONTEXT.md-compliant variant — keeps `runZonedGuarded`)

```dart
// Source: CONTEXT.md §Logger scope at Phase 01, CLAUDE.md error-handling rules
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app.dart';
import 'infrastructure/logging/file_logger.dart';

Future<void> main() async {
  // CONTEXT.md mandates runZonedGuarded; modern alternative shown below in
  // "main.dart (modern variant)". Both forward exceptions to the logger.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Init the file logger (open today's file + prune to kMaxLogsDirBytes)
    await FileLogger.bootstrap();

    final log = Logger('main');

    // Framework errors (sync)
    FlutterError.onError = (FlutterErrorDetails details) {
      log.shout('FlutterError', details.exception, details.stack);
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    runApp(const ProviderScope(child: MirkFallApp()));
  }, (Object error, StackTrace stack) {
    Logger('main').shout('uncaughtZoneError', error, stack);
  });
}
```

### `main.dart` (modern variant — drops `runZonedGuarded`)

```dart
// Source: lazebny.io error handling guide, sentry.io Flutter docs (2026 best practice)
// Use this if planner/user agree to deviate from CONTEXT.md.
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app.dart';
import 'infrastructure/logging/file_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileLogger.bootstrap();

  final log = Logger('main');

  // Sync framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    log.shout('FlutterError', details.exception, details.stack);
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
  };

  // Async errors outside the framework (uncaught futures, etc.)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    log.shout('PlatformDispatcherError', error, stack);
    return true; // mark as handled
  };

  // Errors in spawned isolates (none in Phase 01, but cheap insurance)
  Isolate.current.addErrorListener(RawReceivePort((dynamic pair) {
    final list = pair as List<Object?>;
    log.shout('IsolateError', list[0], list[1] is String ? StackTrace.fromString(list[1]! as String) : null);
  }).sendPort);

  runApp(const ProviderScope(child: MirkFallApp()));
}
```

### `infrastructure/logging/file_logger.dart` (sketch)

```dart
// Source: pub.dev/logging API, path_provider 2.1.5, CONTEXT.md JSON Lines decision
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';

class FileLogger {
  static IOSink? _sink;
  static String? _activeFilename;

  /// Bootstrap: create today's log file, prune oldest until dir < kMaxLogsDirBytes,
  /// set Logger.root.level from --dart-define=DEBUG or SharedPreferences.
  static Future<void> bootstrap() async {
    const debugDefine = bool.fromEnvironment('DEBUG', defaultValue: false);
    final prefs = await SharedPreferences.getInstance();
    final verboseFromPrefs = prefs.getBool('debug_logging_enabled') ?? false;
    Logger.root.level = (debugDefine || verboseFromPrefs) ? Level.ALL : Level.INFO;

    final docsDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(p.join(docsDir.path, 'logs'));
    if (!await logsDir.exists()) await logsDir.create(recursive: true);

    await _pruneToSizeLimit(logsDir);

    final now = DateTime.now();
    final ts = '${_pad(now.year, 4)}${_pad(now.month, 2)}${_pad(now.day, 2)}'
        '_${_pad(now.hour, 2)}${_pad(now.minute, 2)}.${_pad(now.second, 2)}';
    _activeFilename = p.join(logsDir.path, '${ts}_logs.txt');
    final file = File(_activeFilename!);
    _sink = file.openWrite(mode: FileMode.append);

    Logger.root.onRecord.listen(_onRecord);
  }

  static String? get activeFilename => _activeFilename;

  static Future<void> _onRecord(LogRecord rec) async {
    final entry = <String, Object?>{
      'ts': rec.time.toIso8601String(),
      'level': rec.level.name,
      'logger': rec.loggerName,
      'msg': rec.message,
      if (rec.error != null) 'error': rec.error.toString(),
      if (rec.stackTrace != null) 'stack': rec.stackTrace.toString(),
    };
    _sink?.writeln(jsonEncode(entry));
    await _sink?.flush();
  }

  static Future<void> _pruneToSizeLimit(Directory logsDir) async {
    final files = await logsDir
        .list()
        .where((e) => e is File && e.path.endsWith('_logs.txt'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path)); // chronological by filename
    int total = 0;
    for (final f in files) {
      total += await f.length();
    }
    int i = 0;
    while (total > kMaxLogsDirBytes && i < files.length) {
      final size = await files[i].length();
      await files[i].delete();
      total -= size;
      i++;
    }
  }

  static String _pad(int n, int width) => n.toString().padLeft(width, '0');
}
```

### `tool/check_headers.dart` (sketch)

```dart
// Source: CONTEXT.md §License enforcement gates (exact-match policy)
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

const _expectedHeader = '''// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details''';

final _excludePatterns = [
  RegExp(r'\.g\.dart$'),
  RegExp(r'\.freezed\.dart$'),
  RegExp(r'\.gr\.dart$'),
  RegExp(r'\.config\.dart$'),
  RegExp(r'/generated/'),
];

Future<int> main(List<String> args) async {
  final root = Directory(args.isNotEmpty ? args.first : 'lib');
  final failures = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (_excludePatterns.any((re) => re.hasMatch(entity.path.replaceAll('\\', '/')))) continue;
    final contents = await entity.readAsString();
    if (!contents.startsWith(_expectedHeader)) {
      failures.add(entity.path);
    }
  }
  if (failures.isEmpty) {
    stdout.writeln('check_headers: OK');
    return 0;
  }
  stderr.writeln('check_headers: ${failures.length} file(s) missing GOSL header:');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exitCode = 1;
  return 1;
}
```

### `tool/check_licenses.dart` (skeleton, fill in cache scan)

```dart
// Source: CONTEXT.md §License enforcement, dart.dev pub deps --json output format
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

const _allowedSpdx = <String>{
  'MIT',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'Apache-2.0',
  'Unlicense',
  'CC0-1.0',
  'ISC',
  'Zlib',
};

Future<int> main(List<String> args) async {
  // 1. Run `dart pub deps --json` to enumerate every package (direct + transitive)
  final result = await Process.run('dart', ['pub', 'deps', '--json']);
  if (result.exitCode != 0) {
    stderr.writeln('dart pub deps failed: ${result.stderr}');
    return 1;
  }
  final deps = jsonDecode(result.stdout as String) as Map<String, Object?>;
  final packages = (deps['packages'] as List).cast<Map<String, Object?>>();

  final violations = <String>[];
  for (final pkg in packages) {
    final name = pkg['name'] as String;
    final kind = pkg['kind'] as String;
    if (kind == 'root') continue; // skip our own app
    // 2. Resolve LICENSE file via package_config.json (paths under .dart_tool/)
    // 3. Read LICENSE content; SPDX-match.
    final spdxId = await _resolveSpdx(name); // implementation TBD
    if (spdxId == null) {
      violations.add('$name: license could not be resolved');
      continue;
    }
    // Compound expressions: split on " OR " / " AND ", any allowed → pass on OR
    final ids = spdxId.split(RegExp(r'\s+OR\s+'));
    final ok = ids.any(_allowedSpdx.contains);
    if (!ok) {
      violations.add('$name: $spdxId NOT in allowlist');
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_licenses: OK (${packages.length - 1} packages)');
    return 0;
  }
  stderr.writeln('check_licenses: ${violations.length} violation(s):');
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  exitCode = 1;
  return 1;
}

Future<String?> _resolveSpdx(String packageName) async {
  // TODO: read .dart_tool/package_config.json, find rootUri of packageName,
  //       look for LICENSE / LICENSE.md / LICENSE.txt in that dir,
  //       SPDX-match the content (string equality against the SPDX-published texts,
  //       OR check pubspec.yaml's `license:` field if present).
  return null; // placeholder
}
```

### `.github/workflows/ci.yml` (sketch)

```yaml
# Source: subosito/flutter-action README, CONTEXT.md gates spec, Pitfall 3 (pin Xcode)
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:

  gates:
    name: Lint, Licence, Headers, Deps
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: stable
          cache: true
      - run: flutter pub get
      - name: dart format check
        run: dart format --set-exit-if-changed .
      - name: flutter analyze
        run: flutter analyze --fatal-infos --fatal-warnings
      - name: check headers
        run: dart run tool/check_headers.dart
      - name: check licenses
        run: dart run tool/check_licenses.dart
      - name: check DEPENDENCIES.md
        run: dart run tool/check_dependencies_md.dart
      - name: smoke tests
        run: flutter test

  android:
    name: Build Android APK
    needs: gates
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build apk --debug
      - uses: actions/upload-artifact@v4
        with:
          name: mirkfall-android-debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk

  ios:
    name: Build iOS unsigned
    needs: gates
    runs-on: macos-14   # pin per Pitfall 3
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.1'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: stable
          cache: true
      - run: flutter pub get
      - run: cd ios && pod install
      - run: flutter build ios --release --no-codesign
      # No artifact upload in Phase 01 (Phase 15 adds release artifacts).
```

### `lib/config/constants.dart`

```dart
// Source: CONTEXT.md §App bootstrap, CLAUDE.md §Magic numbers
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Display name shown in launcher / About screen.
const String kAppName = 'MirkFall';

/// Bundle / application ID — same on Android and iOS.
const String kBundleId = 'app.gosl.mirkfall';

/// Hard cap on total bytes used by `<app_docs>/logs/` after startup prune.
const int kMaxLogsDirBytes = 10 * 1024 * 1024; // 10 MB

/// 7-tap easter-egg parameters for the about-screen → debug-menu navigation.
const int kAboutTapsToTriggerDebugMenu = 7;
const int kAboutTapWindowMilliseconds = 3000;

// Reserved for later phases (declared empty here so adding them later is touch-free):
// const double kDefaultRevealRadiusMeters = ...;  // Phase 09
// const Duration kHttpTimeout = ...;              // Phase 07
// const int kMarkerPhotoMaxDimension = ...;       // Phase 11
```

### `DEPENDENCIES.md` (stub layout)

```markdown
# DEPENDENCIES.md — MirkFall

Audit log for every direct and transitive Dart/Flutter dependency.
**Mandatory:** every entry in `pubspec.lock` (direct + transitive) must have a row here.
Enforced by `tool/check_dependencies_md.dart` in CI.

## Direct dependencies

| Package | Version | License | Source | Telemetry audit | Date |
|---------|---------|---------|--------|-----------------|------|
| flutter_riverpod | 3.3.1 | MIT | https://pub.dev/packages/flutter_riverpod | No outbound HTTP. Pure DI / state container. | 2026-04-17 |
| riverpod_annotation | 3.0.3 | MIT | https://pub.dev/packages/riverpod_annotation | Annotations-only, no runtime. | 2026-04-17 |
| go_router | 16.0.0 | BSD-3-Clause | https://pub.dev/packages/go_router | No outbound HTTP. Pure routing. | 2026-04-17 |
| logging | 1.3.0 | BSD-3-Clause | https://pub.dev/packages/logging | No outbound HTTP. Sinks defined by user. | 2026-04-17 |
| path_provider | 2.1.5 | BSD-3-Clause | https://pub.dev/packages/path_provider | No outbound HTTP. Wraps native API. | 2026-04-17 |
| ... | ... | ... | ... | ... | ... |

## Transitive dependencies

| Package | Version | License | Pulled in by | Notes | Date |
|---------|---------|---------|--------------|-------|------|
| ... | ... | ... | ... | ... | ... |

## Tooling / GitHub Actions

| Action | Version | License | Notes |
|--------|---------|---------|-------|
| subosito/flutter-action | v2 | MIT | https://github.com/subosito/flutter-action — used in CI |
| maxim-lobanov/setup-xcode | v1 | MIT | Pins Xcode on iOS job |
| actions/setup-java | v4 | MIT | Java 17 for Android Gradle |
| actions/checkout | v4 | MIT | Standard |
| actions/upload-artifact | v4 | MIT | APK upload for download |
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `runZonedGuarded` for top-level error catch | `FlutterError.onError` + `PlatformDispatcher.onError` + `Isolate.current.addErrorListener` | Flutter 3.10 (2023) introduced "Zone mismatch" friction; consensus solidified by 2025 | CONTEXT.md still uses `runZonedGuarded` — see "Important Discrepancy" |
| `StateNotifierProvider` (Riverpod 2.x) | `Notifier` / `AsyncNotifier` (Riverpod 3.x) | Riverpod 3.0 (Nov 2025) | `StateNotifierProvider` is now in `legacy.dart` import. New code uses `Notifier`. |
| `Share.share(text)` (share_plus < 12) | `SharePlus.instance.share(ShareParams(...))` (share_plus ≥ 12) | share_plus 12.0 (2025) | Old API is deprecated. Use `ShareParams(files: [XFile(path)])`. |
| `flutter pub deps --style=tree` (text output) | `dart pub deps --json` | Dart 2.10+ | JSON is parseable; what `tool/check_licenses.dart` should consume. |
| Caret pinning (`^1.0.0`) | Exact pinning (`1.0.0`) for app projects | Industry shift toward reproducibility (2023+) | CLAUDE.md mandates exact pinning + committed `pubspec.lock`. |
| `flutter_lints` baseline only | `flutter_lints` + custom `analyzer.errors` overrides + `riverpod_lint` via `custom_lint` | 2024+ | Phase 01 follows this multi-layer pattern. |

**Deprecated/outdated:**
- **`runZonedGuarded` (in modern Flutter)**: anti-pattern in 3.10+; CONTEXT.md should be updated post-Phase-01 if the team adopts the modern variant.
- **`StateNotifier` / `StateProvider` / `ChangeNotifierProvider`**: now under `package:flutter_riverpod/legacy.dart`. Don't use in new code.
- **`Share.shareXFiles(...)`**: replaced by `SharePlus.instance.share(ShareParams(files: [...]))`. Old API still works but produces deprecation warnings.
- **`actions/cache@v3` and earlier**: use `@v5` (or rely on `subosito/flutter-action`'s built-in caching, which uses `actions/cache@v5` internally as of late 2025).

## Open Questions

1. **Should `runZonedGuarded` be replaced with `PlatformDispatcher.onError`?**
   - What we know: CONTEXT.md mandates `runZonedGuarded`. Current Flutter best practice (3.10+) treats it as anti-pattern.
   - What's unclear: Is CONTEXT.md's `runZonedGuarded` decision a deliberate choice or based on older guidance?
   - Recommendation: **Surface to user during planning** — provide both code variants, ask which to ship. Either works; the modern variant is preferred for cleanliness.

2. **Is `drift_dev` declared in `dev_dependencies` for Phase 01 even though Drift schemas don't exist until Phase 03?**
   - What we know: CONTEXT.md mentions `drift_dev 2.32.x` in the codegen pipeline declared day-1.
   - What's unclear: STACK.md listed `drift 2.32.1` runtime + `drift_flutter 0.3.0` but did not list `drift_dev` separately. `drift_dev` is the codegen.
   - Recommendation: Add `drift_dev: 2.32.1` to `dev_dependencies` in Phase 01 to lock the pin and exercise the codegen pipeline (even on an empty database). Audit it in `DEPENDENCIES.md`.

3. **License scanner: roll our own vs use `dart_license_checker`?**
   - What we know: CONTEXT.md prefers a custom Dart script (`tool/check_licenses.dart`).
   - What's unclear: `dart_license_checker` (MIT, redsolver) is mature and supports `--show-transitive-dependencies`. Adding it as a dev_dep means one more audit row but saves us from writing the SPDX-matching logic.
   - Recommendation: **Roll our own** per CONTEXT.md. The SPDX-matching logic is < 100 lines and matches the "no extra deps" philosophy. If it proves brittle, swap to `dart_license_checker` in a future phase.

4. **Should the smoke test (Wave 1) actually launch the full app or just import key files?**
   - What we know: A smoke test is needed to prove the bootstrap doesn't throw.
   - What's unclear: A `pumpWidget(MirkFallApp)` test requires `path_provider` mocks (since `FileLogger.bootstrap()` calls `getApplicationDocumentsDirectory()`).
   - Recommendation: Use `path_provider`'s `setMockInitialValues` (or override the file logger via a Riverpod override in the test) to avoid touching real filesystem. Phase 01 ships ONE smoke test that pumps the app and verifies the home screen text.

5. **`flutter_lints` 6.0.0 vs `very_good_analysis` 10.2.0 — final call?**
   - What we know: CONTEXT.md leaves this as Claude's discretion. STACK.md proposes both as dev_dependencies.
   - What's unclear: VGA's stricter rules might force premature refactors during early phases.
   - Recommendation: **Use `flutter_lints 6.0.0` only** in Phase 01, layer custom rules above (per code example). Drop `very_good_analysis` from STACK.md's proposed list to keep the dev_deps surface small. If we want stricter later, easy to add.

6. **Who provides `pod install` on the iOS CI job, given iOS folder may have stale pod lockfiles?**
   - What we know: `pod install` is needed before `flutter build ios`.
   - What's unclear: First commit will not have an `ios/Podfile.lock`. CI behaviour on missing lockfile.
   - Recommendation: After `flutter create` in Wave 0, run `cd ios && pod install` LOCALLY to seed the `Podfile.lock`, then commit it. CI then reuses; future `pub get` may need `pod install` re-runs which is fine.

## Validation Architecture

> nyquist_validation is enabled in `.planning/config.json` (workflow.nyquist_validation: true).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Flutter SDK, BSD-3-Clause) |
| Config file | none — `dart_test.yaml` not needed for Flutter widget tests |
| Quick run command | `flutter test test/smoke_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | `analysis_options.yaml` loads strict modes; `flutter analyze` returns zero | static analysis | `flutter analyze --fatal-infos --fatal-warnings` | ❌ Wave 1 |
| FOUND-02 | Every `lib/**/*.dart` has GOSL header (excluding `*.g.dart`, `*.freezed.dart`) | tooling test | `dart run tool/check_headers.dart` | ❌ Wave 3 |
| FOUND-02 | `check_headers.dart` self-test: a fixture file without header fails | unit | `dart test tool/test/check_headers_test.dart` | ❌ Wave 3 |
| FOUND-03 | `DEPENDENCIES.md` covers every entry in `pubspec.lock` | tooling test | `dart run tool/check_dependencies_md.dart` | ❌ Wave 3 |
| FOUND-03 | `check_dependencies_md.dart` self-test on fixtures | unit | `dart test tool/test/check_dependencies_md_test.dart` | ❌ Wave 3 |
| FOUND-04 | CI workflow files exist and are syntactically valid YAML | manual-once | `actionlint .github/workflows/ci.yml` (or visual review) | ❌ Wave 4 — manual; full validation = first push to GitHub |
| FOUND-04 | License scan rejects a GPL-licensed dep | unit | `dart test tool/test/check_licenses_test.dart` (fixture deps with mocked LICENSE files) | ❌ Wave 3 |
| FOUND-05 | All `pubspec.yaml` deps are pinned (no `^`, no `~`) | unit | `dart test test/pubspec_pinned_test.dart` (read pubspec.yaml, parse, assert no caret/tilde) | ❌ Wave 1 |
| FOUND-05 | `pubspec.lock` is committed | tooling | `git ls-files pubspec.lock` returns the file (CI runs `git ls-files pubspec.lock` and asserts non-empty) | ❌ Wave 4 |
| FOUND-06 | Logger bootstrap creates a file under `<app_docs>/logs/` matching format | widget test | `flutter test test/file_logger_test.dart` (use `path_provider`'s test mock to redirect docs dir) | ❌ Wave 2 |
| FOUND-06 | Logger writes JSON Lines | unit | same test: read written file, parse each line as JSON | ❌ Wave 2 |
| FOUND-06 | `--dart-define=DEBUG=true` raises `Logger.root.level` to ALL | unit | `flutter test --dart-define=DEBUG=true test/file_logger_debug_define_test.dart` | ❌ Wave 2 |
| FOUND-06 | `kMaxLogsDirBytes` enforced via prune | unit | `flutter test test/file_logger_prune_test.dart` (seed 11 MB of fake logs, bootstrap, assert dir < 10 MB) | ❌ Wave 2 |
| FOUND-06 | Debug menu UI renders + buttons callable | widget test | `flutter test test/debug_menu_screen_test.dart` (mock providers) | ❌ Wave 2 |
| FOUND-07 | `lib/config/constants.dart` defines `kAppName`, `kBundleId`, `kMaxLogsDirBytes`, etc. | unit | `flutter test test/constants_test.dart` (assert exported symbols + types) | ❌ Wave 1 |
| FOUND-08 | `flutter analyze` returns zero | static | `flutter analyze --fatal-infos --fatal-warnings` | ❌ Wave 1 |
| FOUND-08 | `dart format` is a no-op | static | `dart format --set-exit-if-changed .` | ❌ Wave 1 |

### Sampling Rate
- **Per task commit:** `flutter analyze --fatal-infos --fatal-warnings && dart format --set-exit-if-changed . && flutter test test/smoke_test.dart`
- **Per wave merge:** `flutter test && dart run tool/check_headers.dart && dart run tool/check_dependencies_md.dart`
- **Phase gate:** Full suite green + first GitHub Actions run on `main` succeeds (proves CI gates work end-to-end). Required before `/gsd:verify-work`.

### Wave 0 Gaps

- [ ] `pubspec.yaml` — must exist with pinned deps before any `flutter test` works
- [ ] `analysis_options.yaml` — must exist before `flutter analyze`
- [ ] `test/smoke_test.dart` — minimal app-boots widget test (Wave 1)
- [ ] `test/pubspec_pinned_test.dart` — assert no caret/tilde in pubspec (Wave 1)
- [ ] `test/constants_test.dart` — verify config exports (Wave 1)
- [ ] `test/file_logger_test.dart` — file logger creates file + writes JSONL (Wave 2)
- [ ] `test/file_logger_debug_define_test.dart` — DEBUG define toggle (Wave 2)
- [ ] `test/file_logger_prune_test.dart` — size-bound prune (Wave 2)
- [ ] `test/debug_menu_screen_test.dart` — debug menu UI smoke (Wave 2)
- [ ] `tool/test/check_headers_test.dart` — header script unit tests (Wave 3)
- [ ] `tool/test/check_licenses_test.dart` — license script unit tests with fixture LICENSE files (Wave 3)
- [ ] `tool/test/check_dependencies_md_test.dart` — deps script unit tests (Wave 3)
- [ ] `actionlint` (optional) — validates CI YAML syntax locally; binary install in CI not required

Framework install: none — `flutter_test` ships with Flutter SDK. Wave 0 just runs `flutter create` (which seeds `test/widget_test.dart` we will replace).

## Sources

### Primary (HIGH confidence)
- [pub.dev/flutter_riverpod 3.3.1](https://pub.dev/packages/flutter_riverpod) — Riverpod 3.x current API
- [riverpod.dev migration 2.0 → 3.0](https://riverpod.dev/docs/3.0_migration) — `StateNotifierProvider` legacy, `Notifier` standard
- [pub.dev/go_router 16.x](https://pub.dev/packages/go_router) — current routing API
- [pub.dev/logging 1.3.0](https://pub.dev/packages/logging) — Logger / LogRecord API
- [pub.dev/path_provider 2.1.5](https://pub.dev/packages/path_provider) — `getApplicationDocumentsDirectory`
- [pub.dev/share_plus 13.0.0](https://pub.dev/packages/share_plus) — `ShareParams` API
- [pub.dev/flutter_lints 6.0.0](https://pub.dev/packages/flutter_lints) — baseline lints
- [dart.dev/tools/analysis](https://dart.dev/tools/analysis) — strict-casts, strict-inference, strict-raw-types
- [dart.dev/tools/pub/pubspec](https://dart.dev/tools/pub/pubspec) — SDK constraint syntax
- [GitHub subosito/flutter-action](https://github.com/subosito/flutter-action) — CI Flutter setup with caching
- [project STACK.md](.planning/research/STACK.md) — pre-existing project research with verified versions and licenses
- [project ARCHITECTURE.md](.planning/research/ARCHITECTURE.md) — layered structure rationale, dependency rule
- [project PITFALLS.md](.planning/research/PITFALLS.md) — pitfalls #9, #10, #11, #21 directly inform Phase 01

### Secondary (MEDIUM confidence — verified pattern with multiple sources)
- [Mastering Error Handling in Dart (lazebny.io)](https://lazebny.io/mastering-error-handling/) — `runZonedGuarded` anti-pattern
- [Sentry Flutter usage docs](https://docs.sentry.io/platforms/flutter/usage/) — modern error handling pattern
- [donny — Flutter 3.10+ zone mismatch](https://medium.com/@ipsak2.dl/%ED%94%8C%EB%9F%AC%ED%84%B0-3-10-%EC%9D%B4%ED%9B%84-zone-mismatch-%EC%83%9D%EA%B8%B0%EB%8A%94-%EB%AC%B8%EC%A0%9C-%ED%95%B4%EA%B2%B0%ED%95%98%EA%B8%B0-eed81a814cc7) — concrete repro of the issue
- [Very Good CLI license check docs](https://cli.vgv.dev/docs/commands/check_licenses) — alternative to hand-rolled scanner
- [GitHub redsolver/dart_license_checker](https://github.com/redsolver/dart_license_checker) — alternative tool
- [subosito/flutter-action issue #358](https://github.com/subosito/flutter-action/issues/358) — Xcode version drift
- [SPDX expression handling](https://spdx.dev/learn/handling-license-info/) — compound license expressions

### Tertiary (LOW confidence — single source, flag for validation)
- "Default `compileSdkVersion` is 35 in current Flutter" — verified through multiple Medium articles but not direct from Flutter docs; confirm by inspecting `flutter create` output during Wave 0.
- "subosito/flutter-action uses `actions/cache@v5` internally" — single source (action README); validate by reading the action.yml in the GitHub repo if bundled-cache behavior matters.
- iOS `pod install` failure modes on `macos-14` runner — based on issue threads; first CI run will validate.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — STACK.md already verified all package versions / licenses against pub.dev; this research re-checked Riverpod 3.x and share_plus 13 current API.
- Architecture: HIGH — CONTEXT.md is prescriptive; ARCHITECTURE.md is the source of truth.
- CI plumbing: MEDIUM-HIGH — `subosito/flutter-action@v2` is the de-facto standard; iOS Xcode pin and `pod install` step are the proven workaround for known runner-image drift.
- Pitfalls: HIGH for the ones inherited from PITFALLS.md (#9, #10, #11, #21); MEDIUM for the new ones surfaced here (`runZonedGuarded`, `.gitignore` `.lock` issue, codegen header exclude).
- Discrepancy with CONTEXT.md (`runZonedGuarded`): MEDIUM-HIGH — strong recent consensus but CONTEXT.md is intentional, so user call.

**Research date:** 2026-04-17
**Valid until:** 2026-07-17 (3 months — stable Flutter ecosystem; revalidate when Flutter 3.42 ships or any pinned dep enters major-version pre-release).

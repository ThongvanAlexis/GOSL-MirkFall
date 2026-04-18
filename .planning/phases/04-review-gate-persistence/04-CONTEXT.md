# Phase 04: Review Gate — Persistence - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Audit exhaustif de Phase 03 (Persistence & Domain Models — 6/6 truths VERIFIED par `gsd-verifier` le 2026-04-18) avant que Phase 05 GPS ne commence à écrire dans la DB. Une erreur de modèle rattrapée ici coûte une semaine ; rattrapée Phase 09 elle coûte un mois.

Phase 04 réutilise et étend le pattern Phase 02 Review Gate Foundation (5-section REVIEW.md, 4 sub-agents `general-purpose` parallèles, sévérité Blocker/Should/Could/Noted, atomic commits CI-vert avant le suivant) avec des concerns persistance-spécifiques.

**Dans le scope Phase 04 :**
- Audit exhaustif fichier-par-fichier de tous les artefacts Phase 03 (`lib/domain/`, `lib/infrastructure/`, `lib/application/providers/`, `test/`, `tool/check_domain_purity.dart`, `drift_schemas/`, `pubspec.yaml` deltas, `analysis_options.yaml`)
- Pre-classification dans REVIEW.md §2 des 3 candidats déjà flaggés par 03-VERIFICATION.md (flaky backup test / custom_lint dégradé / computeRevealMask UnimplementedError)
- Runtime walk Windows (boot + observation filesystem `<app_support>/mirkfall.db` + dump sqlite3) — **plan dédié** dans la séquence des waves, AVANT le spawn des sub-agents
- Stress-test adversaire des 2 nouveaux garde-fous CI Phase 03 (check_domain_purity, drift_dev schema dump guard) sur branches jetables `adversarial/04-*` + 1 test unitaire de régression pour SchemaSanityChecker
- Application des fixes choisis (Blocker + Should), commits atomiques `fix(04-rev): <title>`, CI verte avant clearance
- Artefact persistant `04-REVIEW.md` (5 sections : User-observed+Runtime walk / Claude audit / Triage / Adversarial / CI-green)

**Hors scope (autres phases) :**
- Toute ligne de code GPS, Map, Fog, Markers, Import/Export — Phases 05+
- ProviderScope wiring de `AppDatabase` dans `lib/main.dart` — explicitement déféré Phase 05 par 03-CONTEXT (`ActiveSessionController` est le premier consommateur productif)
- Implémentation finale de `computeRevealMask` (UnimplementedError by design) — Phase 09 (MIRK-01..02 fog rendering)
- Pipeline photos (capture, EXIF strip, downscale, FilesystemPhotoStore) — Phase 11
- ZIP archive `.mirkfall`, SCHEMA.md, ImportExportController — Phase 13
- Fix MPL-unreachable heuristic dans `tool/check_licenses.dart` — backlog Phase 02 (4ème Blocker non couvert par adversarial Phase 02)

</domain>

<decisions>
## Implementation Decisions

### Sub-agent slicing : par layer technique (4 agents)

- **Agent #1 — Schema + migrations + backup** :
  - `lib/infrastructure/db/app_database.dart` (Drift schema, 6 tables, FK CASCADE policy, partial unique index `idx_t_sessions_status_active`, BLOB MIRK-03, schemaVersion=2, MigrationStrategy)
  - `lib/infrastructure/db/migrations/v1_to_v2_notes.dart` (ALTER raw `customStatement`)
  - `lib/infrastructure/db/backup.dart` + `lib/infrastructure/db/schema_sanity.dart` + `lib/infrastructure/db/app_database_factory.dart` + `lib/infrastructure/db/pragma_setup.dart`
  - `drift_schemas/drift_schema_v{1,2,_current}.json` (frozen snapshots vs rolling)
  - `test/infrastructure/db/**` (~13 test files)
  - Pragma wiring (WAL via NativeDatabase setup, FK + busy_timeout + synchronous via beforeOpen)

- **Agent #2 — Domain models + pureté** :
  - `lib/domain/**` (entities Freezed, sealed `MirkStyleConfig` + `UnknownConfig` fallback, `@Assert` invariants, errors taxonomy, ports stores)
  - Vérifie : zéro `import 'package:flutter/'` ou `import 'package:drift/'`, zéro `is`-chain, zéro `dynamic` non documenté, zéro singleton global caché
  - Extension type IDs (6 types) + ULID + IdGenerator seam
  - Envelope `{schemaVersion, type, payload}` + JsonMigrator framework + IdentityMigrationV1 + V1ToV2RenameRadius
  - `test/domain/**` (~10 test files)

- **Agent #3 — Store layer + factory + providers** :
  - `lib/infrastructure/stores/drift_*_store.dart` (5 stores : SessionStore SqliteException 2067 wrap scope, RevealedTileStore transactional mergeMask, MarkerCategoryStore reassign-to-default, MarkerStore, MirkStyleStore)
  - Vérifie : aucune fuite Drift dans les couches supérieures, transactions correctes pour multi-write, FK CASCADE comportement réel (pas juste schéma)
  - `lib/application/providers/*_store_provider.dart` (7 providers @Riverpod keepAlive=true) + `lib/infrastructure/ids/random_id_generator.dart` + `seeded_id_generator.dart`
  - `test/infrastructure/stores/**` (~6 test files)

- **Agent #4 — Tests + fixtures + tooling + CLAUDE.md sweep** :
  - Qualité tests : assertions réelles vs placebo, mock correctness, `@Tags(['migration'])` discipline, `dart_test.yaml`
  - `test/fixtures/` (drift_schemas/, json/v{1,2}, db_seed/v1_baseline.sql 70 rows, mirk_style_unknown_renderer.json)
  - `tool/check_domain_purity.dart` + son test
  - `pubspec.yaml` deltas Phase 03 (drift, drift_flutter, sqlite3_flutter_libs, freezed, json_serializable, build_runner, custom_lint, riverpod_lint, riverpod_generator) + `dependency_overrides analyzer ^10.0.0 + dart_style 3.1.7`
  - `analysis_options.yaml` (custom_lint plugin)
  - CLAUDE.md anti-patterns sweep sur tout le code Phase 03 : magic numbers hors `constants.dart`, naming conventions (`xxxFilename` vs `xxxFileName` vs `xxxBasename` vs `xxxDir`, `valueByKey` Maps, `xxxSet` Sets, `xxxs` Lists), DTOs sans sémantique distincte, wrappers de delegation, commentaires narrant le quoi
  - `lib/config/constants.dart` deltas (`kDbFilename`, `kDbBackupDirName`, `kMaxDbBackups`, `kDbBusyTimeoutMs`)
  - `DEPENDENCIES.md` spot-check des entrées Phase 03 ajoutées

### Audit depth : exhaustif fichier-par-fichier

- Mêmes règles que Phase 02 (CONTEXT 02 §Audit scope & depth) :
  - Chaque `.dart` sous `lib/` modifié ou créé Phase 03 audité ligne à ligne
  - Chaque `test/**` Phase 03 audité (assertions réelles vs placebo)
  - Chaque fixture committée vérifiée (cohérence schema, parseable, anti-régression)
  - `drift_schemas/` : v1+v2 frozen jamais re-écrits, current rolling
  - Aucune exclusion silencieuse (les `.g.dart` / `.freezed.dart` ne sont pas audités comme code humain mais leur génération est validée par les tests)
- ~40 fichiers `.dart` Phase 03 + ~25 test files + 6 fixtures + 3 schema dumps. Charge équivalente à Phase 02.

### Output contract des sub-agents : même que Phase 02

- **Structured findings** (l'essentiel, alimente la présentation user) :
  ```
  [severity] Title — 1-line explanation — file:line
  ```
  Sévérités : `Blocker` / `Should` / `Could` / `Noted` (mêmes définitions que CONTEXT 02 §Findings artefact & triage).
- **Narrative appendix** : prose audit report archivé dans `04-REVIEW.md` section "Audit Notes" (pas montré à l'user dans la présentation initiale, consultable si question).
- gsd-verifier grep `^## [1-5]\.` pour confirmer les 5 sections présentes (pattern locked Phase 02).

### Ordering : strict user-first protocol Phase 02

- User poste ses findings IDE en chat **AVANT** que Claude spawn quoi que ce soit
- Claude capture verbatim dans `04-REVIEW.md §1`
- **ENSUITE** runtime walk Windows (plan dédié, voir ci-dessous)
- **ENSUITE** spawn les 4 sub-agents en single tool-use message
- Si user flag un point, un agent peut être briefé explicitement à le creuser
- Parallèle (user tape pendant que agents tournent) explicitement rejeté — même précédent Phase 02

### Adversarial test design : 2 branches CI + 1 test unitaire (3 stress-tests total)

Ciblent les nouveaux garde-fous installés Phase 03. Phase 02 a déjà couvert les 3 garde-fous Foundation (licence/headers/deps).

- **Test #1 — `tool/check_domain_purity.dart`** :
  - Branch `adversarial/04-domain-import-flutter-and-drift` (one branch, two violations)
  - Poison commit : ajouter `import 'package:flutter/material.dart';` dans `lib/domain/sessions/session.dart` ET `import 'package:drift/drift.dart';` dans une autre entité domain (ex: `lib/domain/markers/marker.dart`)
  - Push → CI step `dart run tool/check_domain_purity.dart` doit fail avec exit 1 ET lister les DEUX violations dans la même run (prouve que le check ne s'arrête pas au premier)
  - Evidence dans REVIEW.md §4 : branch name, commit hash, run URL, exit code, stderr extrait listant les 2 fichiers + imports

- **Test #2 — drift schema dump CI guard** :
  - Branch `adversarial/04-schema-drift-stale`
  - Poison commit : ajouter une colonne `TextColumn get notesExtra => text().nullable()();` sur `t_sessions` dans `lib/infrastructure/db/app_database.dart`, run `dart run build_runner build --delete-conflicting-outputs` pour les `.g.dart`, **PAS** de `dart run drift_dev schema dump`
  - Push → CI step `drift schema dump up-to-date` (le `git diff --exit-code drift_schemas/drift_schema_current.json` du guard) doit fail avec un diff montrant que `drift_schema_current.json` n'est plus frais
  - Evidence dans REVIEW.md §4 : branch, commit, run URL, exit code, diff extrait

- **Test #3 — `SchemaSanityChecker` row-loss detection (test unitaire, PAS branche CI)** :
  - Différent des deux précédents : `SchemaSanityChecker` est code runtime (`lib/infrastructure/db/schema_sanity.dart`), pas un script CI à poisoner. La méthode adversaire correcte est un test de régression permanent.
  - Ajouter `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart`
  - Test : injecter le V1 fixture (70 rows), exécuter une migration adversaire factice qui fait `ALTER TABLE` + `DELETE FROM t_sessions WHERE rowid % 2 = 0` (perd ~50% des sessions), prouver que `SchemaSanityChecker.assertNoLoss` throw `MigrationFailureException` avec le row-count diff exact
  - Devient régression-guard permanent dans le repo (pas une throwaway branch)
  - Evidence dans REVIEW.md §4 : commit hash du test ajouté, output `dart test` du nouveau test green

- **Structure adversarial : sym\u00e9trique \u00e0 Phase 02**
  - Tests #1 + #2 = throwaway branches `adversarial/04-*` créées from `main`, poison commit pushed, CI run observé jusqu'à l'échec attendu, URL archivée, branche supprimée local + remote après archivage
  - Pas de PR (évite notifications, conserve historique `main` propre)
  - Sequencing libre (parallèle ou séquentiel à décider en planning selon charge CI)
  - Test #3 = commit normal sur `main`, pas de cleanup nécessaire

### Triage des 3 candidats VERIFICATION.md : pre-classification §2

`03-VERIFICATION.md §Outstanding minor items` a déjà flaggé 3 items "candidate content for Phase 04". On les pré-classe dans `04-REVIEW.md §2` sous-section "Pre-known from VERIFICATION" AVANT spawn agents pour éviter le bruit dupliqué + accélérer le triage §3.

- **Flaky `backup_test.dart::rotate keeps the 3 newest when 4 exist`** (1 fail / ~30 runs Windows parallel)
  - **Severity : Blocker**
  - Fix déterministe : ajouter `Future.delayed(Duration(milliseconds: 10))` entre créations consécutives de fichiers backup dans le test pour normaliser la résolution mtime Windows. Ou trier par nom de fichier (qui contient un timestamp ms) au lieu de mtime.
  - CLAUDE.md §Ordre des collections externes : ne jamais compter sur l'ordre fs.
  - Si l'audit révèle que `DbBackupService.rotate` runtime repose aussi sur mtime (pas seulement le test), ré-évaluer en Blocker fix runtime + test (Agent #1 lens).

- **`custom_lint` silently degraded** (analyzer-10 API rename `Element2` casse `custom_lint_core` 0.8.1)
  - **Severity : Noted**
  - Accept + documenter explicitement dans `STATE.md` Accumulated Decisions ET dans une nouvelle ligne `DEPENDENCIES.md` (`custom_lint` flagged "silently-degraded until 0.9.x ships analyzer-10 support")
  - `flutter analyze --fatal-infos --fatal-warnings` est déjà vert via analyzer-10 stack (pas via custom_lint), donc impact opérationnel = 0
  - Tâche de re-vérification : à chaque bump deps + au démarrage de Phase 15 polish au plus tard

- **`computeRevealMask` throws `UnimplementedError`** (Phase 09 scope)
  - **Severity : Should**
  - Ajouter un test guard `test/domain/compute_reveal_mask_no_callers_test.dart` qui scan tous les `.dart` du projet hors `lib/domain/revealed/reveal_calculator.dart` et fail si quelqu'un appelle `computeRevealMask`
  - Implémentation : `Process.run('rg', ['computeRevealMask', '-l', 'lib/', 'test/'])`, count == 1 (le definition site seul) sinon fail avec liste des callers
  - Évite qu'un dev Phase 05 GPS appelle accidentellement la fonction non-implémentée
  - Test devient guard permanent jusqu'à Phase 09 où il est supprimé en même temps que le `throw`

### Runtime walk Windows : plan dédié, AVANT spawn agents

Phase 03 = pure data, mais quelques chemins runtime existent (`buildAppDatabase` factory ouvre la vraie DB sur disque, pragmas WAL appliqués sur vrai filesystem) et n'ont jamais été exécutés contre un vrai fs (tests in-memory ou tempdir uniquement).

- **Owner : plan dédié 04-XX-PLAN runtime walk** dans la séquence des waves Phase 04. Pas un agent (les agents general-purpose ont des soucis pour piloter `flutter run` long-vivant). Pas user manuel seul (Claude prépare le script, demande à l'user de lancer + coller observations, capture dans REVIEW.md).
- **Scope** :
  - `flutter run -d windows` (kill après observations)
  - Vérifier `<app_support>/mirkfall.db` créé, `mirkfall.db-wal` + `mirkfall.db-shm` créés (preuve WAL active)
  - Ouvrir DB avec sqlite3 CLI :
    - `.schema` → 6 tables déclarées
    - `PRAGMA user_version;` → 2
    - `PRAGMA journal_mode;` → wal
    - `PRAGMA foreign_keys;` → 1
    - `PRAGMA synchronous;` → 1 (NORMAL)
    - `PRAGMA busy_timeout;` → 5000
    - `.indexes t_sessions` → `idx_t_sessions_status_active` présent
- **PAS de UI walk** : ProviderScope wiring de `AppDatabase` dans `lib/main.dart` est explicitement déféré Phase 05 par 03-CONTEXT. Rien d'observable côté écran. Bouton "Backup DB now" debug menu = Claude's discretion 03-CONTEXT (peut-être pas livré) ; si l'audit Agent #1 trouve qu'il n'a pas été livré, c'est une finding `Should` séparée, pas dans le walk.
- **Timing** : Plan 04-01 ou 04-02 (après scaffold REVIEW.md + capture user IDE findings + pre-class 3 candidats), AVANT spawn des 4 sub-agents (Plan 04-03). Cohérent user-first : observation runtime réelle avant audit synthétique. Si le boot révèle un soucis, agent #1 (schema+migrations) peut le creuser explicitement.
- **Evidence dans REVIEW.md** : nouvelle sous-section §1b "Runtime walk Windows" listant inline :
  - Path absolu DB créé
  - Tailles des 3 fichiers (DB, WAL, SHM)
  - Output complet `sqlite3 .schema`
  - Output de chaque PRAGMA query ci-dessus
  - Output `.indexes t_sessions`
  - Date + commit hash de l'app exécutée

### Fix workflow + gate-closed criteria : pattern Phase 02

- Commits atomiques `fix(04-rev): <title>` (ou `refactor(04-rev):` / `docs(04-rev):` / `test(04-rev):` selon nature), un per finding
- Chaque commit passe la CI avant le suivant — feedback rapide + bisectable + revertable finding-par-finding
- **Gate-closed** :
  - Tous findings `Blocker` fixés (pas de waiver possible)
  - Tous findings `Should` soit fixés soit explicitement waiver avec rationale inline dans REVIEW.md §3
  - CI verte sur le commit final `main`
  - `04-REVIEW.md` complet, 5 sections remplies, runtime walk evidence dans §1b, 2 evidence blocks adversaires CI dans §4, test #3 (data-loss) commit hash dans §4
  - `gsd-verifier` vérifie ces 5 conditions pour marquer Phase 04 complete et débloquer Phase 05

### Claude's Discretion

- Choix exact du wave layout des plans Phase 04 (combien de plans, scaffold/walk/agents/adversarial/fixes — à arbitrer en planning, mais le runtime walk DOIT être un plan séparé AVANT les agents)
- Ordre d'exécution des 2 adversarial branches CI (parallèle vs séquentiel selon charge CI runner)
- Format exact de l'evidence inline du runtime walk dans REVIEW.md (collapsed `<details>` markdown vs liste plate)
- Découpage interne de l'agent #4 (CLAUDE.md anti-patterns sweep peut être un pass combiné ou un pass par anti-pattern, à arbitrer selon ce que l'agent estime tractable)
- Choix de la colonne fictive ajoutée au test adversaire #2 (`notesExtra` est un suggested name, peut être autre chose tant que le diff schema dump est observable)
- Stratégie de cleanup des branches adversaires (delete immédiat post-archivage vs delete batch en fin de Plan 04-03)
- Format exact du test guard `compute_reveal_mask_no_callers_test.dart` (Process.run rg vs lecture File + regex Dart pure)
- Format ligne `DEPENDENCIES.md` documentant le silent-degraded `custom_lint` (commentaire inline vs colonne supplémentaire vs note de bas de tableau)
- Re-vérification audit que `DbBackupService.rotate` runtime ne repose pas sur mtime fragile (si oui, escalation flaky test → Blocker runtime + Blocker test)

</decisions>

<specifics>
## Specific Ideas

- **CI est l'autorité aussi pour les adversarial Phase 04** — pas de `act` local, pas de simulation. On pousse réellement `adversarial/04-*`, on observe la vraie CI, on archive le vrai run ID. Même précédent Phase 02 : si on ne fait pas confiance à la CI pour les tests adversaires, on ne peut pas lui faire confiance pour la production.
- **Pre-classification des 3 candidats VERIFICATION économise un cycle de redondance** — les 4 agents les redécouvriraient probablement tous les 3 (flaky est dans test runner output, custom_lint dans pubspec, computeRevealMask dans le code). En pré-classant on libère leur attention pour chercher les angles morts adjacents (autres UnimplementedError silencieux ailleurs ? autres flakes Windows-spécifiques ?).
- **Le runtime walk est la première fois qu'on exécute `buildAppDatabase` contre un vrai filesystem.** 64 tests infrastructure Phase 03 utilisent `NativeDatabase.memory()` ou tempdir. Le vrai chemin `<app_support>/mirkfall.db` + WAL/SHM files + permissions Windows n'a jamais été observé. Si le boot crashe, tous les tests verts sont potentiellement une illusion (même précédent Phase 02 §FileLogger visual walk).
- **SchemaSanityChecker mérite un test adversaire unitaire, pas une throwaway branch.** C'est du code runtime, pas un script CI. La discipline anti-régression veut que le test reste dans le repo. Phase 02 a poisoner les 3 scripts CI (gate scripts) ; Phase 04 mélange les 2 modes (CI guard adversarial sur 2 garde-fous, test unit adversarial sur SchemaSanityChecker) parce que les artefacts Phase 03 sont mélangés CI + runtime.
- **Le test guard `compute_reveal_mask_no_callers_test.dart` est un anti-pattern à doc** — un test qui scan le source code pour interdire des appels est inhabituel. Commentaire CLAUDE.md §Workarounds explicite : "guard temporaire jusqu'à Phase 09 où computeRevealMask sera implémenté + ce test supprimé".
- **Acceptation `custom_lint` silently degraded est un trade-off documenté, pas un oubli.** STATE.md déjà a "REVERSED 03-01 analyzer-<9 pin: dependency_overrides analyzer ^10.0.0 forces toolchain onto analyzer-10 because drift_dev 2.32.1 requires it; custom_lint 0.8.1 silently degrades". On le promeut en décision Noted explicite dans REVIEW.md + DEPENDENCIES.md pour qu'un futur dev (incl. Claude session future) ne le re-flag pas comme bug.
- **Solo-dev review sans PR, sans reviewer humain tiers** — l'audit Claude (4 sub-agents) + l'audit IDE de l'user + le runtime walk sont les trois seuls moteurs de review. Le protocole `user first → walk second → Claude agents third` n'est pas cosmétique : il force l'user à ne pas être biaisé par ce que Claude trouve, et le walk à ne pas être biaisé par ce que les agents trouvent.
- **Les 4 sub-agents sont lancés en une seule tool-use message** (multi Agent tool calls en parallèle), pas en série. Sinon l'avantage wall-clock est perdu et on se retrouve avec un single thorough Explore déguisé. Même précédent Phase 02.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phase 02 + Phase 03)

- **Pattern Phase 02 review-gate complet** (`02-CONTEXT.md`, `02-REVIEW.md`, plans 02-01..02-04) — template directement réutilisable. 5-section REVIEW.md, 4 parallel `general-purpose` sub-agents, severity scheme, atomic commits, adversarial CI evidence trail. Phase 04 hérite + adapte aux concerns persistance.
- **`tool/check_domain_purity.dart`** (créé Plan 03-01) — un des 2 nouveaux garde-fous CI à stress-tester. Audit d'Agent #4 doit confirmer son test unit existe + couvre exit codes 0/1/2.
- **`drift_schemas/drift_schema_v{1,2,_current}.json`** (Plan 03-04) — schémas frozen vs rolling. CI guard `git diff --exit-code drift_schemas/drift_schema_current.json` est l'autre garde-fou à stress-tester.
- **`SchemaSanityChecker`** (`lib/infrastructure/db/schema_sanity.dart`, Plan 03-05) — code runtime à régresser via test unit adversaire (test #3).
- **`DbBackupService`** (`lib/infrastructure/db/backup.dart`, Plan 03-05) — flaky `rotate` test à investiguer + fix déterministe.
- **`AppDatabase` + `buildAppDatabase`** (`lib/infrastructure/db/app_database.dart` + `app_database_factory.dart`, Plans 03-04 + 03-05) — entité centrale du runtime walk (premier exec contre vrai filesystem).
- **`03-VERIFICATION.md`** — point de départ documenté de l'audit, source des 3 pré-classifications. Phase 04 ne ré-audite pas les 6 truths déjà VERIFIED mais peut challenger une evidence si une finding Blocker surface.
- **`03-{01..06}-SUMMARY.md`** — listent les déviations auto-documentées de Phase 03 (analyzer-10 pin reversal, V1ToV2Notes raw customStatement, byte-count ordering proof, etc.) — à spot-check pour s'assurer qu'aucune n'est une régression sous-documentée. Pattern Phase 02 §Reusable Assets identique.
- **`02-REVIEW.md` (Phase 02 closed 2026-04-18)** — exemplar concret du format final attendu pour `04-REVIEW.md`. Réutilisation du template 5 sections + sous-section narrative Audit Notes.
- **GitHub Actions CI** (`.github/workflows/ci.yml`) — la `gates` job inclut depuis Plan 03-01 : `dart run tool/check_domain_purity.dart`, `git diff --exit-code drift_schemas/drift_schema_current.json`, `dart test test/domain/ test/infrastructure/`. Phase 04 valide que ces 3 nouveaux steps fail correctement quand poisonés.

### Established Patterns (from Phase 02)

- **5-section REVIEW.md artifact contract** locked Phase 02 (`02-CONTEXT §Findings artefact & triage`). gsd-verifier grep `^## [1-5]\.` to confirm 5 headings. Reusable across all even-numbered phases incl. Phase 04.
- **4-parallel-sub-agent audit wave template validated** Phase 02 (54 findings in one wall-clock slot). Single tool-use message spawning 4 concern-sliced `general-purpose` agents. Phase 04 reuses pattern + adapts slicing to layer technique (schema+migrations, domain+pureté, store, tests+fixtures+tooling).
- **All 4 audit agents `general-purpose`** for wave consistency (Phase 02 décision conservée même pour les agents read-only) — Phase 04 garde la règle.
- **User-first ordering strict** locked Phase 02. Phase 04 ajoute le runtime walk comme étape intermédiaire AVANT spawn agents : `user IDE → runtime walk → 4 agents`.
- **Severity tiers Blocker / Should / Could / Noted** + définitions conservées (cf 02-CONTEXT §Findings artefact & triage).
- **Atomic commits `fix(02-rev): <title>`** → Phase 04 utilise `fix(04-rev): <title>` (incrément du préfixe).
- **Adversarial branches throwaway `adversarial/02-*`** deleted local + remote post-archivage → Phase 04 utilise `adversarial/04-*` même discipline.
- **CI exit code contract `0=clean / 1=policy violation / 2=misconfiguration`** des gate scripts s'applique aux 2 nouveaux garde-fous Phase 03 (check_domain_purity, drift schema dump guard) — adversarial Phase 04 attend exit 1 avec message identifiant la violation.

### Integration Points

- **`.planning/phases/04-review-gate-persistence/04-REVIEW.md`** — artefact persistant produit par Phase 04, consulté par `gsd-verifier` pour vérifier la gate-closed condition (5 sections + runtime walk evidence + 2 adversarial CI evidence blocks + test #3 hash + CI-green confirmation)
- **`.planning/STATE.md`** — mis à jour après chaque commit atomique (current_plan incrémenté, progress percent recalculé) ; nouvelle entrée Accumulated Decisions pour le silent-degraded `custom_lint`
- **`.planning/phases/03-persistence-domain-models/03-VERIFICATION.md`** — lu en début de Phase 04 pour pré-classification des 3 candidats + connaître le baseline VERIFIED 6/6
- **`.planning/phases/03-persistence-domain-models/03-{01..06}-SUMMARY.md`** — lus pour identifier les déviations auto-documentées de Phase 03 qui méritent lecture de confirmation (pas ré-audit complet)
- **GitHub Actions CI (repository `GOSL-MirkFall`)** — les 2 adversarial branches Phase 04 y tournent, les run IDs deviennent l'evidence trail §4
- **`DEPENDENCIES.md`** — nouvelle ligne ou colonne pour documenter `custom_lint` silently-degraded (Noted #2)
- **`test/domain/compute_reveal_mask_no_callers_test.dart`** — nouveau test guard à créer (Should #3), commit hash archivé §4
- **`test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart`** — nouveau test adversaire #3 SchemaSanityChecker, commit hash archivé §4
- **`test/infrastructure/db/backup_test.dart`** — fix déterministe à appliquer (Blocker #1 flaky), via `Future.delayed(10ms)` ou tri par filename

</code_context>

<deferred>
## Deferred Ideas

- **Pre-commit hooks (lefthook ou autre)** — rejeté Phase 01, reste rejeté Phases 02 + 04. CI est l'autorité unique. Si l'user change d'avis plus tard, c'est une phase dédiée, pas une finding de review gate.
- **Persistent adversarial matrix dans `ci.yml`** (matrix job ré-exécutant les 5 adversarial tests known-bad à chaque push) — considéré, non retenu Phases 02 + 04. Si les garde-fous doivent être re-stressés à chaque phase de code, justifie une phase dédiée plus tard (peut-être Phase 16 release audit). En V1.0, 1 stress par review-gate suffit.
- **Audit exhaustif `pubspec.lock` paquet par paquet (175+ entries)** — remplacé par spot-check des deltas Phase 03 dans Agent #4. Ré-audit exhaustif = jours de travail pour signal minimal additionnel.
- **Automatisation du fix des Could / Noted** — pas dans Phase 04. Les Could peuvent être triagés `defer-to-phase-15-polish`, les Noted alimentent `deferred` de phases futures.
- **Rapport de stress-test comme artefact permanent séparé** (`docs/guardrail-stress-tests.md`) — non retenu Phases 02 + 04. Les evidences vivent dans les `XX-REVIEW.md` review-gate-par-review-gate, pas agrégé. Si un pattern de réutilisation émerge sur plusieurs gates, on promeut V1.1.
- **Investigation profonde de `DbBackupService.rotate` runtime mtime-dependence** — fait dans le scope du Blocker #1 fix, pas une investigation séparée. Si le runtime repose vraiment sur mtime, l'escalation Blocker runtime + Blocker test se fait pendant Plan 04-XX (apply fixes), pas comme phase à part.
- **Remplacer custom_lint par alternative (lint_lab, dart_code_metrics)** — overkill V1.0. Si on en a vraiment besoin, phase dédiée. Pour l'instant accepté Noted.
- **Re-pinner downgrade analyzer + Drift pour rétablir custom_lint actif** — drift_dev 2.32.1 require analyzer ^10 (note STATE.md), donc downgrade drift = casse Phase 03. Pas viable.
- **MPL-unreachable heuristic fix dans `tool/check_licenses.dart`** — Phase 02 backlog (4ème Blocker non couvert par adversarial Phase 02). Pas mélangé avec Phase 04. Reste à faire dans une hot-fix Phase 02 résiduelle ou en Phase 16.
- **ProviderScope wiring de `AppDatabase` dans `lib/main.dart`** — explicitement déféré Phase 05 par 03-CONTEXT (`ActiveSessionController` premier consommateur productif). Phase 04 ne touche pas.
- **UI debug menu walk** — ProviderScope non wiré, donc pas de UI à walk. Si Agent #1 trouve que le bouton "Backup DB now" debug menu n'est pas livré (Claude's discretion 03-CONTEXT), ça devient une finding `Should` séparée triagée §3, pas un walk étendu.
- **Test guard pattern réutilisable pour autres `UnimplementedError` futurs** — si plus de chantiers similaires apparaissent (Phase 09 fog, Phase 11 photos), on promeut le pattern. Pour l'instant 1-shot pour `computeRevealMask`.
- **Rotation backups par âge** — déjà déféré Phase 15 par 03-CONTEXT. 3 rolling suffit V1.0.
- **Soft-delete / corbeille / undo** — déjà déféré post-V1 par 03-CONTEXT. Pas réouvert ici.

</deferred>

---

*Phase: 04-review-gate-persistence*
*Context gathered: 2026-04-18*

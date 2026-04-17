# Phase 02: Review Gate — Foundation - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Audit exhaustif de Phase 01 (Foundation) avant d'ouvrir Phase 03 (Persistence). Objectif explicite du roadmap : vérifier que les garde-fous tiennent **sous pression** — pas seulement qu'ils sont présents. Phase 01 est déjà `VERIFIED: PASSED` par `gsd-verifier`. Phase 02 ajoute la dimension adversaire : prouver que les 3 scripts CI (`check_licenses.dart`, `check_headers.dart`, `check_dependencies_md.dart`) échouent comme attendu quand on leur injecte réellement une violation.

**Dans le scope Phase 02 :**
- Audit exhaustif de tous les artefacts de Phase 01 (code `lib/`, tests, outils `tool/`, workflow `.github/`, `DEPENDENCIES.md`, `pubspec.yaml`)
- Stress-test adversaire des 3 garde-fous CI (1 branche jetable par garde-fou, réel paquet GPL pub.dev pour la licence)
- Protocole de review Claude-solo-dev (`CLAUDE.md §Code Review Phases`) : user d'abord, puis Claude présente des **titres + explication courte**, user choisit
- Application des fixes choisis (Blocker + Should), commits atomiques, CI verte avant clearance
- Artefact persistant `02-REVIEW.md` (trail d'audit pour future référence)

**Hors scope (d'autres phases) :**
- Toute ligne de code métier (persistance, GPS, carte, mirk, markers, import/export) — Phases 03+
- Nouveaux garde-fous Day-1 au-delà des 3 déjà en place — si le besoin apparaît, c'est une finding de Phase 02 à triager, pas un ajout automatique
- Polish final de l'écran À propos / licences tierces — Phase 15 (ABOUT-*)
- Store-grade copy iOS `UsageDescription` — Phase 15 (QUAL-04)

</domain>

<decisions>
## Implementation Decisions

### Audit scope & depth (exhaustive)

- **Scope : exhaustif** — chaque `.dart` sous `lib/`, chaque fichier sous `test/` et `tool/`, le workflow `.github/workflows/ci.yml`, `DEPENDENCIES.md`, `pubspec.yaml`, `analysis_options.yaml`, les 5 layer READMEs (`lib/**/README.md`), les `Info.plist` / `AndroidManifest.xml` / `build.gradle.kts`. Aucune exclusion.
- **`tool/check_licenses.dart` : audit adversaire + edge cases.** Au-delà de la lecture ligne à ligne, construire des fixtures qui stressent le parser : casse SPDX atypique (`gpl-3.0` vs `GPL-3.0`), licences multiples (`Apache-2.0 OR GPL-2.0`, `MIT AND BSD-3-Clause`), LICENSE absent, chaîne vide, licences personnalisées. Objectif : prouver que le parser dénie GPL même quand les variations humaines s'y glissent.
- **`DEPENDENCIES.md` : spot-check des soft-spots, pas de ré-audit des 175 entrées.**
  - Les 4 `_manualOverrides` MPL-2.0-Linux-only (dbus/geoclue/gsettings, +1 autre) : re-vérifier que la justification est toujours narrow et qu'un commentaire SPDX synthétique explicite reste en place
  - Les dépendances ré-exportées (ex: `cross_file` via `share_plus`) : confirmer qu'elles ne devraient pas être promues en direct
  - ~5 entrées aléatoires pour vérifier la cohérence SPDX / télémétrie / date
  - Pas de ré-audit exhaustif des 175 entrées — le CI cross-check script + l'audit initial de Phase 01 suffisent
- **FileLogger runtime : read-through + visual walk sur Windows.** Phase 01 a vérifié le logger programmatiquement (widget tests + DEBUG-define test), mais jamais observé sur un vrai filesystem. Phase 02 exécute `flutter run -d windows`, déclenche le 7-tap sur `/about`, crée des logs, share-file (via share_plus), clear-all avec confirmation. Valide : chemin `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` réel, permissions filesystem, SharedPreferences écrit, rotation amorcée. Soak-test prune (1000+ lignes → 10 MB) : optionnel, à décider pendant la walk selon ce qu'on observe.

### Audit methodology (4 parallel sub-agents, slicé par concern)

- **4 sub-agents parallèles, split par concern** (pas par layer filesystem — les concerns touchent plusieurs couches mais sont sémantiquement séparables) :
  1. **Agent #1 : CI gate scripts + adversarial design** — audit de `tool/check_licenses.dart`, `check_headers.dart`, `check_dependencies_md.dart`, leurs tests, + conception des 3 branches adversaires
  2. **Agent #2 : Bootstrap runtime** — audit de `lib/main.dart`, `lib/app.dart`, `FlutterError.onError`, `runZonedGuarded`, `FileLogger.bootstrap/prune/JSONL/toggleVerbosePref`, `SharedPreferences` flow, `--dart-define=DEBUG` path
  3. **Agent #3 : Code quality sweep** — audit anti-patterns CLAUDE.md (is-chains, dynamic non-documenté, magic numbers hors `constants.dart`, singletons cachés, wrappers sans valeur ajoutée, DTOs sans sémantique distincte, commentaires inutiles) sur tout `lib/`
  4. **Agent #4 : Tests + tooling + CI workflow** — audit qualité des tests (mocks corrects, assertions réelles vs. placebo), `.github/workflows/ci.yml` (fan-out `gates → android + ios`, `needs: gates` contract, fail-fast, cache hits, diagnostic step), platform stubs (`Info.plist` TODO markers, `AndroidManifest.xml`, Podfile.lock bootstrap Option A)
- **Claude-main : synthesizer only.** Main dispatche les 4 agents, reçoit leurs rapports, déduplique les findings overlap, construit la liste unifiée `titre + explication 1-ligne + severity` pour présentation à l'user. Pas d'audit direct par main — garde le contexte main propre pour la conversation review avec l'user.
- **Output contract des agents : structured findings list + narrative appendix.**
  - **Structured** (l'essentiel, ce qui alimente la présentation CLAUDE.md) : liste markdown `[severity] Titre — explication 1 ligne — file:line`
  - **Narrative** (appendice) : prose audit report pour contexte riche, archivé dans `02-REVIEW.md` section "Audit Notes" (pas montré à l'user dans la présentation initiale, consultable si question)
- **Ordering : user d'abord, puis Claude.** Protocole `CLAUDE.md §Code Review Phases` strict : user poste ses findings IDE en chat, Claude les capture, **ensuite** spawn les 4 sub-agents. L'audit Claude est informé par les observations de l'user — si user flag quelque chose, un agent peut être briefé explicitement à creuser ce point. Parallèle (user tape pendant que agents tournent) explicitement rejeté.

### Adversarial stress-test coverage (all 3 guardrails, real poison, throwaway branches)

- **Les 3 garde-fous sont stress-testés**, pas seulement le scan de licence (roadmap criterion 3 est le minimum) :
  1. **Licence** : ajouter un **vrai paquet GPL** depuis pub.dev (paquet identifiable comme GPL dans son pubspec metadata) dans `pubspec.yaml`, push, CI `check_licenses.dart` doit échouer avec message clair identifiant le paquet + sa licence GPL
  2. **Headers** : commit un fichier `.dart` sous `lib/` sans le header GOSL 3-lignes, push, CI `check_headers.dart` doit échouer avec message identifiant le fichier
  3. **DEPENDENCIES.md** : ajouter une nouvelle dépendance MIT dans `pubspec.yaml` **sans** ajouter la ligne correspondante dans `DEPENDENCIES.md`, push, CI `check_dependencies_md.dart` doit échouer avec diff identifiant l'entrée manquante
- **Structure : throwaway branch par test, delete après.**
  - Nommage : `adversarial/02-licence-gpl-scan`, `adversarial/02-header-missing`, `adversarial/02-deps-missing-entry`
  - Chaque branche est créée from `main`, le commit poison est pushed, la CI run est observée jusqu'à l'échec attendu, l'URL du run est capturée dans `02-REVIEW.md`, puis la branche est supprimée (local + remote) une fois l'évidence archivée
  - Pas de PR — évite les notifications + conserve l'historique `main` propre
  - Sequencing : libre (peuvent être exécutés en parallèle ou séquentiellement, à décider pendant planning selon la charge CI)
- **Evidence contract dans `02-REVIEW.md`** — pour chaque test adversaire :
  - Nom du garde-fou + nom de la branche jetable
  - Commit poison (hash + 1-line description de la violation)
  - URL du run CI qui a échoué
  - Exit code + extrait du message d'erreur attendu (prouve que l'échec est le bon — pas un échec fortuit d'une autre cause)
  - Date + confirmation branche supprimée

### Findings artefact & triage

- **`02-REVIEW.md` — 5 sections**, file au path `.planning/phases/02-review-gate-foundation/02-REVIEW.md` :
  1. **User-observed findings** — ce que l'user a vu dans son IDE (capturé verbatim ou résumé, en début de phase avant que Claude audit)
  2. **Claude audit findings** — liste des titres + explication 1-ligne + severity, groupés par concern-slice (les 4 agents)
  3. **Triage decisions** — pour chaque finding : `fix` / `defer-to-phase-X` / `won't-fix` + rationale 1-ligne
  4. **Adversarial evidence** — les 3 tests adversaires (format ci-dessus)
  5. **CI-green confirmation** — final run ID sur `main` après application des fixes, lien GitHub Actions, date
- **Severity scheme : 4 tiers** `Blocker` / `Should` / `Could` / `Noted` :
  - **Blocker** : doit être fixé avant que Phase 03 ne soit ouverte (violation CLAUDE.md critique, bug silencieux dans un garde-fou, régression de test, etc.)
  - **Should** : fix fortement recommandé, à fixer sauf décision explicite de waiver (anti-pattern, magic number, commentaire inutile, convention de naming)
  - **Could** : amélioration bas-coût-haut-bénéfice (refactor cosmétique, documentation mineure)
  - **Noted** : observation capturée sans action (souvent une chose à surveiller dans une phase future — alimente `deferred` ici ou un TODO roadmap)
- **Fix workflow : commits atomiques, un par finding.**
  - Message : `fix(02-rev): <titre de la finding>` (ou `refactor(02-rev):` / `docs(02-rev):` selon la nature)
  - Chaque commit passe la CI avant le suivant — feedback rapide + bisectable + revertable finding-par-finding
  - Aligne avec la discipline GSD atomic-commit
- **Gate closed = Blockers + Shoulds fixed + CI green + `02-REVIEW.md` committed**
  - Tous les findings `Blocker` sont fixés (pas de waiver possible)
  - Tous les findings `Should` sont soit fixés soit explicitement waiver avec rationale inline dans REVIEW.md triage section
  - CI verte sur le commit final `main`
  - `02-REVIEW.md` complet, les 5 sections remplies, les 3 evidence blocks adversaires présents
  - `gsd-verifier` vérifie ces 4 conditions pour marquer Phase 02 complete et débloquer Phase 03

### Claude's Discretion

- Choix exact du **real GPL pub.dev package** utilisé pour le test licence (doit vraiment apparaître sur pub.dev avec licence GPL identifiable — Claude propose, user peut override)
- Ordre d'exécution des 3 adversarial branches (parallèle vs. séquentiel)
- Décision sur le **soak-test prune 10 MB** pendant la visual walk (déclencher ou non selon ce qu'on observe)
- Découpage interne de l'agent #3 "Code quality sweep" (chaque anti-pattern de CLAUDE.md mérite-t-il un pass dédié ou un scan combiné ?)
- Format exact des "narrative appendices" des sub-agents dans REVIEW.md (collapsed markdown sections, liens vers transcripts, etc.)
- Choix entre `Explore` et `general-purpose` pour chacun des 4 sub-agents (Explore si read-only, general-purpose si l'agent a besoin de construire des fixtures ou faire des writes)

</decisions>

<specifics>
## Specific Ideas

- **"CI est l'autorité" s'applique aussi aux adversarial tests.** Pas de `act` local, pas de simulation — on pousse réellement une branche, on observe la vraie CI, on archive le vrai run ID. Si on ne fait pas confiance à la CI pour les tests adversaires, on ne peut pas lui faire confiance pour la production.
- **Le `real GPL pub.dev package` est une contrainte volontaire** : si le parser plante sur un paquet synthétique mais passe sur un vrai paquet (ou inversement), on veut le savoir. Le vecteur d'attaque "contamination accidentelle par une transitive" est réaliste, pas synthétique.
- **La visual walk sur Windows est la première fois que l'app est réellement exécutée par un humain depuis le bootstrap.** Phase 01 VERIFICATION liste explicitement ce point comme "Human Verification Required". Phase 02 ferme cette boucle. Si l'app ne démarre pas, tous les widgets tests passés sont potentiellement une illusion.
- **Solo-dev review sans PR, sans reviewer humain tiers** — l'audit Claude + l'audit IDE de l'user sont les deux seuls moteurs de review. Le protocole `user first → Claude second` n'est pas une convention cosmétique : il force l'user à ne pas être biaisé par ce que Claude trouve.
- **Les 4 sub-agents sont lancés en une seule tool-use message** (multi Agent tool calls en parallèle), pas en série. Sinon l'avantage wall-clock est perdu et on se retrouve avec un single thorough Explore déguisé.
- **Les branches adversaires sont supprimées après archivage** — garde `main` et le list de branches remote propre. L'evidence vit dans `02-REVIEW.md`, pas dans une branche morte.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phase 01)

- **3 CI gate scripts** (`tool/check_licenses.dart`, `check_headers.dart`, `check_dependencies_md.dart`) — déjà en place, déjà testés. Phase 02 les audit pour vérifier qu'ils n'ont pas de trou + les stress-teste adversairement. Pas de modification prévue sauf si une finding Blocker/Should l'exige.
- **CI workflow** `.github/workflows/ci.yml` — 3 jobs (`gates` → `android` + `ios`), fan-out via `needs: gates`. Phase 02 confirme qu'un échec d'un gate script bloque réellement les builds, ne les laisse pas passer en parallèle.
- **`FileLogger`** (`lib/infrastructure/logging/file_logger.dart`, 175 lignes) — static class, JSONL format, prune par taille, toggle `SharedPreferences` + `--dart-define=DEBUG`. Phase 02 audit + visual walk.
- **`DEPENDENCIES.md`** (230 lignes, 175 packages + 5 GitHub Actions) — cross-checked par `check_dependencies_md.dart`. Phase 02 spot-check des 4 `_manualOverrides` MPL-2.0-Linux-only + ré-export `cross_file` + ~5 random.
- **`VERIFICATION.md` Phase 01** (`.planning/phases/01-foundation/01-VERIFICATION.md`, PASSED) — le point de départ documenté de l'audit. Phase 02 ne ré-audite pas les criteria déjà VERIFIED mais peut challenger une evidence si une finding Blocker surface.
- **`SUMMARY.md` des 4 plans Phase 01** — listent les déviations du plan original (versions pinned révisées, ecosystem conflicts, etc.) — à spot-check pour s'assurer qu'aucune n'est une régression sous-documentée.
- **Debug menu UI** (`lib/presentation/screens/debug_menu_screen.dart`) — SwitchListTile verbose, log list + share, clear-all confirm. Phase 02 visual walk.

### Established Patterns

- **CI est l'unique autorité d'enforcement** (pas de pre-commit hook) — s'applique à Phase 02 : les adversarial tests exercent la VRAIE CI, pas une simulation locale
- **Commits atomiques + message structurés** (`docs(01-04):`, `fix(01-01):`, etc.) — Phase 02 utilise `fix(02-rev): <title>` pour chaque fix de finding
- **Layer READMEs comme documentation de convention** (`lib/domain/README.md : "Pas d'import flutter, drift..."`) — Phase 02 audit vérifie que les READMEs sont à jour + que les imports respectent les règles
- **Exit code contract `0=clean / 1=policy violation / 2=misconfiguration`** des gate scripts — Phase 02 adversarial tests attendent `exit 1` avec message identifiant la violation (pas `exit 2` qui serait une run cassée)

### Integration Points

- **`.planning/phases/02-review-gate-foundation/02-REVIEW.md`** — artefact persistant produit par Phase 02, consulté par `gsd-verifier` pour vérifier la gate-closed condition
- **`.planning/STATE.md`** — mis à jour après chaque commit atomique (current_plan incrémenté, progress percent recalculé)
- **`.planning/phases/01-foundation/01-VERIFICATION.md`** — lu en début de Phase 02 pour savoir ce qui a déjà été mécaniquement vérifié (ne pas re-dupliquer l'effort)
- **GitHub Actions CI (repository `GOSL-MirkFall`)** — les adversarial branches poussées y tournent, les run IDs deviennent l'evidence trail
- **`.planning/phases/01-foundation/01-{01,02,03,04}-SUMMARY.md`** — lus pour identifier les déviations auto-documentées de Phase 01 qui méritent une lecture de confirmation (pas ré-audit complet)

</code_context>

<deferred>
## Deferred Ideas

- **Custom_lint pour enforcer les règles d'import inter-couches** — déjà différé en Phase 01 à Phase 04 (review gate persistance, quand @riverpod providers apparaissent). Phase 02 ne l'introduit pas. Si findings montrent une dérive d'import, note-le pour Phase 04.
- **Pre-commit hooks (lefthook ou autre)** — rejeté Phase 01, reste rejeté Phase 02. CI est l'autorité unique. Si l'user change d'avis plus tard, c'est une phase dédiée, pas une finding de review gate.
- **Persistent adversarial matrix dans `ci.yml`** (une matrix job qui à chaque push ré-exécute les 3 adversarial tests contre des fixtures known-bad) — considéré, non retenu pour Phase 02. Si les garde-fous doivent être re-stressés à chaque phase de code, ça justifiera une phase dédiée plus tard (peut-être Phase 16 release audit). En V1.0, 1 stress par review-gate est suffisant.
- **Log rotation par âge (14 jours)** — déjà différé Phase 15 en Phase 01. Pas réouvert ici.
- **Audit de `pubspec.lock` paquet par paquet (175 entries)** — remplacé par le spot-check des soft-spots ci-dessus. Ré-audit exhaustif des 175 = des jours de travail pour signal minimal additionnel.
- **Automatisation du fix des Could / Noted** — pas dans Phase 02. Les Could peuvent être triagés `defer-to-phase-15-polish`, les Noted alimentent `deferred` de phases futures.
- **Rapport de stress-test comme artefact permanent séparé** (`docs/guardrail-stress-tests.md`) — non retenu. Les evidences vivent dans les `02-REVIEW.md` / `04-REVIEW.md` / etc. — review-gate-par-review-gate, pas agrégé. Si un pattern de ré-utilisation émerge sur plusieurs gates, on promeut en V1.1.
- **Store-grade copy iOS `UsageDescription`** — reste Phase 15 (QUAL-04). Phase 02 note que les TODO markers sont toujours en place, c'est une `Noted` finding maximum.
- **Polished About screen + licences tierces** — reste Phase 15 (ABOUT-*). Phase 02 audit le placeholder actuel tel quel.

</deferred>

---

*Phase: 02-review-gate-foundation*
*Context gathered: 2026-04-17*

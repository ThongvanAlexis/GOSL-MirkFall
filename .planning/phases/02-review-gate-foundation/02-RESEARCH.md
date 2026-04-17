# Phase 02: Review Gate — Foundation - Research

**Researched:** 2026-04-17
**Domain:** Solo-dev code review protocol + adversarial stress-testing of CI guardrails (Dart/Flutter + GitHub Actions + GOSL licensing policy)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Audit scope & depth (exhaustive)**
- **Scope : exhaustif** — chaque `.dart` sous `lib/`, chaque fichier sous `test/` et `tool/`, le workflow `.github/workflows/ci.yml`, `DEPENDENCIES.md`, `pubspec.yaml`, `analysis_options.yaml`, les 5 layer READMEs (`lib/**/README.md`), les `Info.plist` / `AndroidManifest.xml` / `build.gradle.kts`. Aucune exclusion.
- **`tool/check_licenses.dart` : audit adversaire + edge cases.** Construire des fixtures qui stressent le parser : casse SPDX atypique (`gpl-3.0` vs `GPL-3.0`), licences multiples (`Apache-2.0 OR GPL-2.0`, `MIT AND BSD-3-Clause`), LICENSE absent, chaîne vide, licences personnalisées.
- **`DEPENDENCIES.md` : spot-check des soft-spots, pas de ré-audit des 175 entrées.** Les 4 `_manualOverrides` MPL-2.0-Linux-only (dbus/geoclue/gsettings + flutter_plugin_android_lifecycle), les ré-exportations (ex: `cross_file` via `share_plus`), ~5 entrées aléatoires.
- **FileLogger runtime : read-through + visual walk sur Windows.** `flutter run -d windows`, 7-tap sur `/about`, créer logs, share-file, clear-all avec confirmation. Valide : chemin `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` réel, permissions filesystem, SharedPreferences écrit, rotation amorcée. Soak-test prune (1000+ lignes → 10 MB) **optionnel**, à décider pendant la walk.

**Audit methodology (4 parallel sub-agents, slicé par concern)**
1. **Agent #1** : CI gate scripts + adversarial design — audit de `tool/check_*.dart`, leurs tests, + conception des 3 branches adversaires
2. **Agent #2** : Bootstrap runtime — `lib/main.dart`, `lib/app.dart`, `FlutterError.onError`, `runZonedGuarded`, `FileLogger.bootstrap/prune/JSONL/toggleVerbosePref`, `SharedPreferences` flow, `--dart-define=DEBUG` path
3. **Agent #3** : Code quality sweep — anti-patterns CLAUDE.md (is-chains, dynamic non-documenté, magic numbers hors `constants.dart`, singletons cachés, wrappers sans valeur ajoutée, DTOs sans sémantique distincte, commentaires inutiles) sur tout `lib/`
4. **Agent #4** : Tests + tooling + CI workflow — tests qualité (mocks corrects, assertions réelles vs placebo), `.github/workflows/ci.yml` (fan-out `gates → android + ios`, `needs: gates`, fail-fast, cache hits, diagnostic step), platform stubs

- **Claude-main : synthesizer only.** Pas d'audit direct — main dispatche les 4 agents, reçoit, déduplique, construit la liste unifiée pour présentation.
- **Output contract des agents** : structured findings list (`[severity] Titre — explication 1 ligne — file:line`) + narrative appendix (prose pour contexte, archivé dans `02-REVIEW.md` section "Audit Notes").
- **Ordering : user d'abord, puis Claude.** Protocole `CLAUDE.md §Code Review Phases` strict. Parallèle (user tape pendant que agents tournent) explicitement **rejeté**.

**Adversarial stress-test coverage (all 3 guardrails, real poison, throwaway branches)**
1. **Licence** : ajouter un **vrai paquet GPL** depuis pub.dev dans `pubspec.yaml`
2. **Headers** : commit un fichier `.dart` sous `lib/` sans le header GOSL 3-lignes
3. **DEPENDENCIES.md** : ajouter une nouvelle dépendance MIT dans `pubspec.yaml` **sans** ajouter la ligne correspondante dans `DEPENDENCIES.md`

- **Structure : throwaway branch par test, delete après.**
  - Nommage : `adversarial/02-licence-gpl-scan`, `adversarial/02-header-missing`, `adversarial/02-deps-missing-entry`
  - Chaque branche : créée from `main`, commit poison pushed, CI observée jusqu'à l'échec attendu, URL run capturée dans `02-REVIEW.md`, branche supprimée (local + remote)
  - **Pas de PR** — évite les notifications + conserve l'historique `main` propre
  - Sequencing : libre (parallèle ou séquentiel)
- **Evidence contract dans `02-REVIEW.md`** : nom du garde-fou + nom de branche jetable + commit poison (hash + description) + URL du run CI + exit code + extrait message d'erreur + date + confirmation branche supprimée

**Findings artefact & triage**
- **`02-REVIEW.md` — 5 sections**, file au path `.planning/phases/02-review-gate-foundation/02-REVIEW.md` :
  1. User-observed findings
  2. Claude audit findings (groupés par concern-slice)
  3. Triage decisions (`fix` / `defer-to-phase-X` / `won't-fix` + rationale)
  4. Adversarial evidence
  5. CI-green confirmation
- **Severity scheme : 4 tiers** `Blocker` / `Should` / `Could` / `Noted`
- **Fix workflow : commits atomiques, un par finding.** Message `fix(02-rev): <titre>` (ou `refactor(02-rev):` / `docs(02-rev):`). Chaque commit passe la CI avant le suivant.
- **Gate closed = Blockers + Shoulds fixed + CI green + `02-REVIEW.md` committed**

### Claude's Discretion

- Choix exact du **real GPL pub.dev package** utilisé pour le test licence (Claude propose, user peut override)
- Ordre d'exécution des 3 adversarial branches (parallèle vs séquentiel)
- Décision sur le **soak-test prune 10 MB** pendant la visual walk (déclencher ou non selon observation)
- Découpage interne de l'agent #3 "Code quality sweep" (chaque anti-pattern dédié vs scan combiné)
- Format exact des "narrative appendices" des sub-agents dans REVIEW.md
- Choix entre `Explore` et `general-purpose` pour chacun des 4 sub-agents

### Deferred Ideas (OUT OF SCOPE)

- **Custom_lint pour enforcer les règles d'import inter-couches** — reporté à Phase 04
- **Pre-commit hooks (lefthook ou autre)** — rejeté, CI reste autorité unique
- **Persistent adversarial matrix dans `ci.yml`** — non retenu V1.0
- **Log rotation par âge (14 jours)** — Phase 15
- **Audit de `pubspec.lock` paquet par paquet (175 entries)** — remplacé par spot-check
- **Automatisation du fix des Could / Noted** — hors scope ; Could → `defer-to-phase-15-polish`, Noted → `deferred` de phases futures
- **Rapport de stress-test comme artefact permanent séparé** (`docs/guardrail-stress-tests.md`) — non retenu
- **Store-grade copy iOS `UsageDescription`** — Phase 15 (QUAL-04), Phase 02 note les TODO markers max `Noted`
- **Polished About screen + licences tierces** — Phase 15 (ABOUT-*)
</user_constraints>

<phase_requirements>
## Phase Requirements

Review gates ne possèdent pas de REQ-ID dédiés — elles vérifient les REQ de la phase précédente (FOUND-01..08 pour Phase 01).

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUND-01 | `analysis_options.yaml` strict | Agent #3 re-scan + Agent #4 CI step re-verification |
| FOUND-02 | GOSL header partout | Agent #1 audits `check_headers.dart` + adversarial branch `adversarial/02-header-missing` prouve détection |
| FOUND-03 | `DEPENDENCIES.md` audit trail | Agent #1 audits `check_dependencies_md.dart` + spot-check overrides + adversarial branch `adversarial/02-deps-missing-entry` prouve détection |
| FOUND-04 | CI pipeline Android + iOS + license scan | Agent #4 audit `ci.yml` fan-out + adversarial branch `adversarial/02-licence-gpl-scan` prouve licence scan détecte un vrai GPL |
| FOUND-05 | Versions pinnées exactement | Agent #4 re-verifies `pubspec_pinned_test.dart` + lockfile cohérence |
| FOUND-06 | Logger + debug menu + DEBUG define | Agent #2 read-through + visual walk Windows (flow 7-tap → share → clear-all) |
| FOUND-07 | Constants centralisées | Agent #3 grep pour magic numbers hors `constants.dart` |
| FOUND-08 | `flutter analyze` zero warning + `dart format` | Agent #4 verifies CI step + local clean run |

**Meta-requirement:** Les 4 `Success Criteria` du roadmap Phase 02 s'ajoutent :
1. User sollicité d'abord — garanti par protocole strict, rejet explicite du parallélisme
2. Findings = **titres + explication courte** — format structuré imposé, l'user choisit
3. Scan licence CI échoue sur vrai paquet GPL — `adversarial/02-licence-gpl-scan` avec `multi_dropdown` ou `line_icons` (GPL-3.0, confirmé pub.dev)
4. CI repasse au vert avant Phase 03 — commit final `main` + run ID archivé dans `02-REVIEW.md`
</phase_requirements>

## Summary

Phase 02 est une **review gate adversaire** — Phase 01 est déjà `VERIFIED: PASSED` par `gsd-verifier`, Phase 02 ne re-vérifie pas les criteria mécaniques, elle ajoute la dimension **stress-test** : prouver que les 3 scripts CI (`check_licenses.dart`, `check_headers.dart`, `check_dependencies_md.dart`) échouent effectivement quand on leur injecte une violation réelle, pas seulement qu'ils compilent. Le protocole de review CLAUDE.md (user first → Claude second → titres courts → user décide quoi fixer) est strict, non-négociable, et explicitement anti-parallélisation.

Le recherche couvre 5 domaines : (a) le **protocole de code review solo-dev** (CLAUDE.md §Code Review Phases), (b) la **mécanique des 4 sub-agents parallèles** consolidés par Claude-main, (c) la **sélection d'un vrai paquet GPL pub.dev** (candidates vérifiées : `multi_dropdown` 3.1.1, `line_icons` 2.0.3, `iconsax` 0.0.8 — tous GPL-3.0 sur pub.dev), (d) la **mécanique des adversarial branches** (push réel, pas `act` local, URL run archivée, branche supprimée), (e) le **format `02-REVIEW.md` 5-sections** avec severity 4-tiers.

**Primary recommendation:** Utiliser `multi_dropdown: 3.1.1` comme paquet GPL pour `adversarial/02-licence-gpl-scan` — le plus populaire (381 likes, 30.7k downloads), licence GPL-3.0 clairement identifiée sur pub.dev, aucune transitive complexe, et son LICENSE file devrait déclencher le substring `GNU GENERAL PUBLIC LICENSE` ou un declared `license:` field dans son `pubspec.yaml`. `iconsax` en backup.

## Standard Stack

Phase 02 n'introduit aucune nouvelle dépendance runtime. Les outils utilisés sont déjà en place ou natifs à la plateforme.

### Core (déjà présents, ré-utilisés)

| Tool / Library | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `flutter_test` (SDK) | 3.41.5 | widget + smoke tests | BSD-3-Clause, bundled avec Flutter SDK, aucune dep externe |
| `package:test` | 1.30.0 | tool/test runners (plain Dart) | Déjà dans `dev_dependencies`, utilisé pour `tool/test/*_test.dart` |
| `package:yaml` | 3.1.3 | parser pubspec.lock dans les check_* | Déjà dans `dev_dependencies`, pinned |
| `gh` CLI (installé) | — | consultation des CI runs (capture URL + exit code) | Déjà installé + authentifié (confirmé CLAUDE.md §Git & CI) |
| Git (natif) | — | création/delete des throwaway branches | Natif |

### Supporting (optionnels, Claude's discretion)

| Tool | Purpose | When to Use |
|------|---------|-------------|
| Windows `flutter run -d windows` | visual walk FileLogger | obligatoire pour Agent #2 validation runtime (decision user-locked) |
| `actionlint` (optionnel) | lint workflow `ci.yml` | si Agent #4 soupçonne une erreur syntaxique ; pas obligatoire |

### Alternatives Considered (et rejetées)

| Instead of | Could Use | Rejected Because |
|------------|-----------|------------------|
| Real pub.dev GPL package | Synthetic fixture LICENSE with GPL substring | User-locked: "Le `real GPL pub.dev package` est une contrainte volontaire : si le parser plante sur un paquet synthétique mais passe sur un vrai paquet (ou inversement), on veut le savoir" |
| `act` local simulation of CI | — | User-locked: "Pas de `act` local, pas de simulation — on pousse réellement une branche, on observe la vraie CI, on archive le vrai run ID" |
| PR-based adversarial tests | `gh pr create` | User-locked: "Pas de PR — évite les notifications + conserve l'historique `main` propre" |
| Sequential sub-agents | Spawn agents in series | Context: "Les 4 sub-agents sont lancés en une seule tool-use message (multi Agent tool calls en parallèle), pas en série. Sinon l'avantage wall-clock est perdu" |

**Installation:** Aucune. Phase 02 utilise uniquement l'outillage déjà en place.

## Architecture Patterns

### Recommended Execution Structure

```
Phase 02 execution flow:
1. /gsd:code-review (review gate entry)
   ↓
2. User posts IDE findings in chat → Claude captures verbatim
   ↓
3. Claude spawns 4 sub-agents in PARALLEL (single tool-use message):
   - Agent #1 (CI gates + adversarial design)
   - Agent #2 (Bootstrap runtime + visual walk)
   - Agent #3 (Code quality sweep)
   - Agent #4 (Tests + tooling + CI workflow)
   ↓
4. Claude-main SYNTHESIZER consolidates findings:
   - Dedup overlap (findings that surface in multiple agents)
   - Merge into single list: [severity] Title — 1-line explanation — file:line
   - Archive narrative appendix sections
   ↓
5. Claude presents to user: TITLES + 1-line explanations ONLY (no diffs)
   ↓
6. User selects what to fix (Blockers mandatory, Should recommended, Could/Noted optional)
   ↓
7. Claude applies fixes as ATOMIC commits: fix(02-rev): <title>
   Each commit passes CI before the next
   ↓
8. Adversarial stress-tests (sequencing Claude's discretion):
   - Branch adversarial/02-licence-gpl-scan → push GPL poison → wait CI red
   - Branch adversarial/02-header-missing → push header-less .dart → wait CI red
   - Branch adversarial/02-deps-missing-entry → push MIT dep without DEPS entry → wait CI red
   - For each: capture run URL + exit code + error message → archive in 02-REVIEW.md
   - Delete branch (local + remote)
   ↓
9. Final CI green on main → commit 02-REVIEW.md (5 sections filled)
   ↓
10. /gsd:verify-work → Phase 02 marked complete → Phase 03 unblocked
```

### Pattern 1: User-First Protocol (CLAUDE.md §Code Review Phases)

**What:** Strict ordering, user posts IDE observations BEFORE Claude spawns any audit agent. Claude's findings are informed by user observations — if user flags something, an agent can be briefed explicitly to dig that point.

**When to use:** Every review gate phase in this project. Non-négociable.

**Example:**
```
Claude: "Avant que je lance mes 4 sub-agents, qu'as-tu vu dans ton IDE
         qui mérite d'être revu ?"
User: "[posts findings]"
Claude: [captures verbatim in 02-REVIEW.md §1, THEN spawns agents]
```

**Anti-pattern:** Parallèle "user tape pendant que agents tournent" — explicitement rejeté par CONTEXT.md. Raison : force l'user à ne pas être biaisé par ce que Claude trouve.

### Pattern 2: 4 Parallel Sub-Agents, Sliced by Concern (not by Filesystem Layer)

**What:** Agents are partitioned by **semantic concern** (CI gates, bootstrap runtime, code quality, tests+tooling), not by filesystem path (e.g. `lib/`, `test/`, `tool/`). Concerns cross filesystem layers — e.g. "bootstrap runtime" audits `lib/main.dart` + `lib/app.dart` + `lib/infrastructure/logging/file_logger.dart` but NOT `lib/presentation/screens/placeholder_home_screen.dart` (pure UI, belongs to Agent #3).

**When to use:** When the codebase has enough cross-layer concerns that sharding by directory would force agents to duplicate context. GSD Phase 01 is small (~21 `.dart` files) but semantically split.

**Example:**
```
Agent #1 "CI gates" audits:
  - tool/check_licenses.dart (implementation)
  - tool/check_headers.dart (implementation)
  - tool/check_dependencies_md.dart (implementation)
  - tool/test/check_*_test.dart (fixtures + coverage)
  - .github/workflows/ci.yml (step references)
  Designs: 3 adversarial branch poison payloads

Agent #2 "Bootstrap runtime" audits:
  - lib/main.dart (runZonedGuarded + FlutterError.onError)
  - lib/app.dart (MaterialApp.router wiring)
  - lib/infrastructure/logging/file_logger.dart (bootstrap/prune/JSONL)
  - Visual walk via `flutter run -d windows`

Agent #3 "Code quality" audits:
  - Every .dart under lib/ for CLAUDE.md anti-patterns
  - Magic numbers hors lib/config/constants.dart
  - is-chains, wrappers sans valeur, dynamic undocumented

Agent #4 "Tests + tooling + CI" audits:
  - test/*.dart (mock correctness, assertion quality)
  - tool/test/*.dart (fixture coverage)
  - .github/workflows/ci.yml (fan-out, needs contract, cache)
  - Platform stubs: Info.plist, AndroidManifest.xml, build.gradle.kts
```

**Anti-pattern:** Single thorough Explore agent — loses wall-clock benefit, and one agent holding too much context tends to miss specific anti-patterns a specialized agent would catch.

### Pattern 3: Throwaway Adversarial Branch per Guardrail

**What:** Each guardrail is stress-tested on its own ephemeral branch (not a PR, not `main`), with a single poison commit. CI observes the expected failure. Run URL + exit code + error message archived. Branch deleted local + remote.

**When to use:** Every review gate that needs to prove CI policy enforcement is real, not theatre. Pattern reusable for Phase 04, 06, 08... (future review gates).

**Example workflow:**
```bash
# For adversarial/02-licence-gpl-scan
git checkout -b adversarial/02-licence-gpl-scan
# edit pubspec.yaml: add "multi_dropdown: 3.1.1" under dependencies
flutter pub get  # regenerate lockfile
git add pubspec.yaml pubspec.lock
git commit -m "test(adversarial): inject GPL package multi_dropdown to exercise check_licenses gate"
git push -u origin adversarial/02-licence-gpl-scan

# Wait for CI to fail
gh run list --branch adversarial/02-licence-gpl-scan --limit 1
gh run view <run-id> --log-failed  # capture exit code + error message

# Archive evidence in 02-REVIEW.md
# Then delete branch
git checkout main
git branch -D adversarial/02-licence-gpl-scan
git push origin --delete adversarial/02-licence-gpl-scan
```

**Evidence block format in 02-REVIEW.md:**
```markdown
### Adversarial test 1: Licence GPL scan

- **Branch:** `adversarial/02-licence-gpl-scan` (deleted 2026-04-17)
- **Poison commit:** `<hash>` — added `multi_dropdown: 3.1.1` (GPL-3.0) to `pubspec.yaml`
- **CI run:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/<id>
- **Gate step:** "Check licenses (GPL/AGPL/copyleft scan)" failed with exit code 1
- **Error message (excerpt):**
  ```
  check_licenses: 1 violation(s):
    - multi_dropdown: UNKNOWN-FORBIDDEN-MARKER: GNU GENERAL PUBLIC LICENSE NOT in allowlist
  ```
- **Confirms:** `tool/check_licenses.dart` detects real GPL packages, not only synthetic fixtures
```

### Pattern 4: Severity 4-Tier Triage

**What:** Every finding gets exactly one of: `Blocker` / `Should` / `Could` / `Noted`. Gate closes only when `Blocker`s are all fixed and `Should`s are either fixed or explicitly waived with inline rationale.

**Definitions from CONTEXT.md:**
- **Blocker** : doit être fixé avant Phase 03 (violation CLAUDE.md critique, bug silencieux dans un garde-fou, régression de test)
- **Should** : fix fortement recommandé (anti-pattern, magic number, commentaire inutile, convention de naming) — fixable sauf waiver explicite
- **Could** : amélioration bas-coût-haut-bénéfice (refactor cosmétique, doc mineure)
- **Noted** : observation capturée sans action (souvent watch-future — alimente `deferred` ou TODO roadmap)

### Anti-Patterns to Avoid

- **Claude audits first, THEN asks user:** Viole CLAUDE.md §Code Review Phases. L'user doit poster ses findings IDE AVANT que Claude spawn les agents.
- **Findings presented as diffs:** L'user perd son pouvoir de décider quoi corriger. CONTEXT.md impose `titres + explication 1 ligne` uniquement.
- **Re-running `gsd-verifier` scope on Phase 01 criteria:** Phase 01 est déjà PASSED. Phase 02 ne re-vérifie pas, elle ajoute la couche adversaire. Ne pas dupliquer l'effort.
- **Creating a PR for adversarial branches:** Gonfle le remote history, déclenche notifications, brouille `main`. `git push` direct + `git push --delete` est le pattern propre.
- **Skipping the visual walk on Windows:** Phase 01 VERIFICATION §Human Verification Required flag explicite "app boots and renders correctly — Cannot run Flutter app in this session". Phase 02 est la première session humaine à cette app ; si elle ne démarre pas, tous les widget tests sont potentiellement une illusion.
- **Fix commit batching:** CLAUDE.md impose commits atomiques. Chaque finding = un commit `fix(02-rev): <title>`. Permet revert finding-par-finding + bisect.
- **Auto-commit Podfile.lock in CI** after adversarial run: Option A bootstrap (CI read-only) explicitement locked dans STATE.md décisions Phase 01. Ne pas régresser ici.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GPL package detection | Custom SPDX parser from scratch | `tool/check_licenses.dart` (existe déjà) + real pub.dev GPL package | Parser déjà fixture-tested (GPL → exit 1) ; adversarial test exerce le parser sur un vrai LICENSE file |
| Adversarial test evidence storage | Ad-hoc notes or separate file | Evidence blocks inside `02-REVIEW.md` §4 | User-locked: "Les evidences vivent dans les `02-REVIEW.md` / `04-REVIEW.md` / etc. — review-gate-par-review-gate, pas agrégé" |
| CI run URL capture | Screenshots or manual copy | `gh run view <id>` CLI | `gh` installé + authentifié (CLAUDE.md §Git & CI). Déterministe, scriptable, archivable |
| Multi-agent coordination | Sequential agent spawn with manual handoff | Single parallel tool-use message with 4 Agent calls | Context locked: "lancés en une seule tool-use message, pas en série. Sinon l'avantage wall-clock est perdu" |
| Fix commit automation | Auto-apply all findings | Atomic commit per finding with CI-green gate between each | CLAUDE.md §Git : "commits atomiques + message structurés" ; REVIEW.md mandate: "Chaque commit passe la CI avant le suivant — feedback rapide + bisectable + revertable finding-par-finding" |
| Branch cleanup | Let adversarial branches rot on remote | `git push origin --delete <branch>` after evidence captured | User-locked: "Les branches adversaires sont supprimées après archivage" |

**Key insight:** Phase 02 est principalement un **protocole d'exécution** (quelle commande dans quel ordre avec quel output). Toutes les briques (scripts, CI, gh, git) existent déjà. Le risque est procédural (ordre du protocole, format du review), pas technique.

## Common Pitfalls

### Pitfall 1: Claude audits before user posts findings

**What goes wrong:** Claude spawn les 4 sub-agents immédiatement, puis demande "quoi revoir ?" à l'user. L'user est alors biaisé par la liste Claude et ne regarde plus son IDE avec un œil neuf.

**Why it happens:** C'est le réflexe naturel "parallélise pour gagner du temps". Mais CLAUDE.md §Code Review Phases et CONTEXT.md rejettent explicitement ce parallélisme.

**How to avoid:** Lire CLAUDE.md §Code Review Phases avant de démarrer Phase 02. Le premier message Claude doit être "qu'as-tu vu ?" — strictement. Aucun `Agent` tool call avant que l'user ait posté.

**Warning signs:** Voir apparaître `Task`/`Agent` tool invocations dans les premiers messages de Phase 02 sans que l'user ait encore parlé.

### Pitfall 2: Adversarial test exit code 2 (misconfiguration) misread as exit code 1 (violation)

**What goes wrong:** Le poison push pour `adversarial/02-licence-gpl-scan` casse `pubspec.lock` (oubli de `flutter pub get` après edit de `pubspec.yaml`), le check_licenses script trouve `.dart_tool/package_config.json` absent, retourne exit code 2 (misconfiguration). CI échoue — **mais pas pour la bonne raison**. Evidence archivée est trompeuse.

**Why it happens:** Le contract `0=clean / 1=policy violation / 2=misconfiguration` (STATE.md décision Phase 01) est crucial ; les trois exit codes ressemblent à "CI red" de l'extérieur.

**How to avoid:** Pour chaque adversarial branch, vérifier le **message stderr** dans le log CI, pas seulement l'exit code. L'evidence bloc dans `02-REVIEW.md` doit contenir un extrait du message qui prouve que l'échec est `exit 1 + violation identifiée`, pas `exit 2 + config cassée`. Commande utile : `gh run view <id> --log-failed | grep -A3 "check_licenses:"`.

**Warning signs:** `check_licenses: pubspec.lock not found` ou `check_licenses: .dart_tool/package_config.json not found` dans les logs = exit 2, pas exit 1. Test invalide, refaire en exécutant `flutter pub get` avant le commit poison.

### Pitfall 3: GPL package LICENSE file doesn't contain the exact substring `GNU GENERAL PUBLIC LICENSE`

**What goes wrong:** Un paquet pub.dev déclare `license: GPL-3.0-or-later` dans son `pubspec.yaml` mais son fichier `LICENSE` contient seulement un court résumé (e.g. "This software is licensed under GPL-3.0. See https://...") sans la phrase canonique. Le checker `check_licenses.dart` lit d'abord le `pubspec.yaml` `license:` field (returns `GPL-3.0-or-later` ou similar), passe dans `_allowedSpdx.contains` → false → violation. **Cela fonctionne quand même**, mais pour une raison différente de l'intention (substring match du LICENSE file).

**Why it happens:** Le checker a deux voies de détection : (1) déclaration explicite dans pubspec, (2) substring scan dans LICENSE. Le paquet pub.dev réel peut emprunter soit l'une soit l'autre.

**How to avoid:** Dans l'evidence bloc, noter quelle voie a détecté la violation. Pour `multi_dropdown` 3.1.1 : pub.dev reporte `GPL-3.0` via son metadata — le checker le lira soit via `pubspec.yaml` `license:` field soit via LICENSE scan. Soit les deux voies passent, soit une seule — les deux détectent. Adversarial test réussi dans tous les cas, mais documenter quelle voie. Candidate de backup : `iconsax` ou `line_icons` si `multi_dropdown` a une forme inhabituelle.

**Warning signs:** Si le stderr dit `multi_dropdown: GPL-3.0 NOT in allowlist` → voie 1 (pubspec field). Si `multi_dropdown: UNKNOWN-FORBIDDEN-MARKER: GNU GENERAL PUBLIC LICENSE NOT in allowlist` → voie 2 (LICENSE substring). Les deux comptent comme "gate fonctionne sur paquet réel".

### Pitfall 4: FileLogger visual walk discovers a bug but no guardrail catches it

**What goes wrong:** Visual walk révèle que le 7-tap sur `/about` ne navigue pas réellement vers `/debug` sur Windows (par exemple GestureDetector hit-area trop restrictive), ou que `listLogFiles()` ne montre jamais le fichier actif. Widget tests passent (mocked path_provider), real runtime broken. Finding = Blocker, mais aucune CI n'aurait pu le catch.

**Why it happens:** Widget tests en environnement simulé avec MockPlatformInterface couvre l'API path_provider, pas le runtime réel Windows/Android/iOS. CLAUDE.md §Plateformes explicite: "Tester systématiquement sur Android (dev principal) et sur desktop Windows (`flutter run -d windows`) pour la logique".

**How to avoid:** Agent #2 "Bootstrap runtime" doit obligatoirement exécuter `flutter run -d windows` (user-locked decision), pas uniquement lire le code. La walk couvre le flow complet : start → observe log file created → 7-tap on /about → debug menu ouvre → share log file → clear-all confirm dialog → files deleted. Si un bug surface, c'est un finding Blocker (Phase 02 existe exactement pour ça).

**Warning signs:** Agent #2 retourne un rapport qui ne mentionne aucun observation runtime (aucun chemin fichier réel, aucun timestamp, aucun screenshot/description d'écran). C'est un signal que la walk n'a pas eu lieu.

### Pitfall 5: Adversarial branches not deleted, cluttering the remote

**What goes wrong:** Les 3 branches `adversarial/02-*` sont créées + poussées, mais oubliées après l'archivage. `git branch -a` du futur Phase 04 trouve une prolifération. Le remote est pollué. Pattern ne scale pas à 7 review gates (Phase 02, 04, 06, 08, 10, 12, 14, 16).

**Why it happens:** Oubli après une longue session + pas d'automatisation.

**How to avoid:** La dernière action de chaque adversarial test DOIT être `git push origin --delete <branch>` + `git branch -D <branch>` (local). L'evidence bloc dans `02-REVIEW.md` inclut explicitement "confirmation branche supprimée: 2026-04-17" — checklist visible, impossible à oublier silencieusement.

**Warning signs:** `git branch -a` ou `gh api repos/:owner/:repo/branches` retourne des `adversarial/02-*` après la fermeture de Phase 02.

### Pitfall 6: DEPENDENCIES.md spot-check misses a soft-spot

**What goes wrong:** Le spot-check "5 entrées aléatoires" tombe sur des packages qui sont OK et manque les vrais soft-spots (nouveau override MPL ajouté subtilement, cross_file mal attribué). User-locked scope: **4 `_manualOverrides` MPL-2.0-Linux-only** (dbus/geoclue/gsettings + flutter_plugin_android_lifecycle qui est BSD-3-Clause override, pas MPL — à clarifier), **ré-exports** (cross_file via share_plus), **~5 random**.

**Why it happens:** "spot-check" laisse sous-entendre du sampling aléatoire, mais les soft-spots sont ciblés.

**How to avoid:** Agent #1 et Agent #4 auditent explicitement :
1. Les 4 entrées de `_manualOverrides` dans `check_licenses.dart` — vérifier rationale à jour + synthetic SPDX commentaire visible
2. Les ré-exports documentés dans STATE.md (cross_file via share_plus) — vérifier qu'ils ne méritent pas promotion en direct dep
3. 5 entrées aléatoires pour cohérence format SPDX + télémétrie + date

L'audit NE fait PAS le tour des 175 entrées — c'est explicitement deferred dans CONTEXT.md.

**Warning signs:** Agent #1 rapport mentionne "audité 175 packages" = scope creep, Phase 02 n'est pas le moment.

## Code Examples

Verified patterns — already in the codebase, to reuse.

### Example 1: Adversarial branch for GPL scan test

```bash
# 1. Create throwaway branch from current main
git checkout main
git pull  # ensure up-to-date
git checkout -b adversarial/02-licence-gpl-scan

# 2. Inject GPL package (Claude's Discretion: multi_dropdown 3.1.1, GPL-3.0)
# Edit pubspec.yaml under dependencies:
#   multi_dropdown: 3.1.1
# Run pub get to regenerate lockfile (so check_licenses doesn't exit 2)
flutter pub get

# 3. Atomic poison commit
git add pubspec.yaml pubspec.lock
git commit -m "test(adversarial): inject GPL package multi_dropdown to exercise check_licenses gate

This commit is POISONED INTENTIONALLY to verify that CI's license scan
(tool/check_licenses.dart) detects a real GPL-3.0 package on pub.dev,
not just synthetic fixture LICENSE files. The branch will be deleted
once evidence is archived in .planning/phases/02-review-gate-foundation/02-REVIEW.md."

# 4. Push + observe CI
git push -u origin adversarial/02-licence-gpl-scan

# 5. Wait for CI red (gh CLI)
gh run list --branch adversarial/02-licence-gpl-scan --limit 1
# Capture run ID
RUN_ID=$(gh run list --branch adversarial/02-licence-gpl-scan --limit 1 --json databaseId --jq '.[0].databaseId')
echo "Run ID: $RUN_ID"

# 6. Extract the failure message
gh run view $RUN_ID --log-failed | grep -B2 -A5 "check_licenses"

# 7. Archive evidence in 02-REVIEW.md §4 (adversarial evidence)

# 8. Cleanup — MANDATORY
git checkout main
git branch -D adversarial/02-licence-gpl-scan
git push origin --delete adversarial/02-licence-gpl-scan
```

### Example 2: Adversarial branch for missing GOSL header

```bash
git checkout main && git pull
git checkout -b adversarial/02-header-missing

# Create a .dart file WITHOUT the 3-line GOSL header
cat > lib/presentation/screens/poison_no_header.dart <<'EOF'
import 'package:flutter/material.dart';

class PoisonNoHeaderScreen extends StatelessWidget {
  const PoisonNoHeaderScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}
EOF

git add lib/presentation/screens/poison_no_header.dart
git commit -m "test(adversarial): inject .dart file without GOSL header to exercise check_headers gate

Branch will be deleted once evidence archived."

git push -u origin adversarial/02-header-missing

# Wait for CI red, capture run + error
RUN_ID=$(gh run list --branch adversarial/02-header-missing --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view $RUN_ID --log-failed | grep -B2 -A5 "check_headers"

# Archive evidence, delete branch
git checkout main
git branch -D adversarial/02-header-missing
git push origin --delete adversarial/02-header-missing
```

### Example 3: Adversarial branch for missing DEPENDENCIES.md entry

```bash
git checkout main && git pull
git checkout -b adversarial/02-deps-missing-entry

# Add a small MIT-licensed package to pubspec.yaml but NOT to DEPENDENCIES.md
# Choose something tiny + clearly MIT, e.g. `equatable: 2.0.5`
# Edit pubspec.yaml dependencies: equatable: 2.0.5
flutter pub get

git add pubspec.yaml pubspec.lock
# Note: intentionally NOT touching DEPENDENCIES.md
git commit -m "test(adversarial): add equatable 2.0.5 without DEPENDENCIES.md entry to exercise check_dependencies_md gate

Branch will be deleted once evidence archived."

git push -u origin adversarial/02-deps-missing-entry

RUN_ID=$(gh run list --branch adversarial/02-deps-missing-entry --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view $RUN_ID --log-failed | grep -B2 -A5 "check_dependencies_md"

# Archive evidence + delete branch
git checkout main
git branch -D adversarial/02-deps-missing-entry
git push origin --delete adversarial/02-deps-missing-entry
```

### Example 4: 02-REVIEW.md skeleton (5 sections)

```markdown
# Phase 02: Review Gate — Foundation Review

**Opened:** 2026-04-17
**Status:** open / closed
**Closed:** <date>

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude's audit.*

- [User finding 1]
- [User finding 2]

## 2. Claude audit findings

Grouped by concern-slice. Format: `[severity] Title — 1-line explanation — file:line`.

### Agent #1 — CI gate scripts
- [Blocker] ...
- [Should] ...

### Agent #2 — Bootstrap runtime
- [Could] ...

### Agent #3 — Code quality sweep
- [Noted] ...

### Agent #4 — Tests + tooling + CI workflow
- [Blocker] ...

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>
... prose from each agent's full report ...
</details>

## 3. Triage decisions

| # | Finding | Severity | Decision | Rationale |
|---|---------|----------|----------|-----------|
| 1 | ... | Blocker | fix | Required before Phase 03 |
| 2 | ... | Should | fix | ... |
| 3 | ... | Should | waived | [explicit rationale here — required for Should-waived] |
| 4 | ... | Could | defer-to-phase-15 | Cosmetic, batch with polish |
| 5 | ... | Noted | won't-fix | Tracking only, no action |

## 4. Adversarial evidence

### Test 1: License GPL scan
- **Branch:** adversarial/02-licence-gpl-scan (deleted <date>)
- **Poison commit:** `<hash>` — added `multi_dropdown: 3.1.1`
- **Run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/<id>
- **Gate step:** "Check licenses (GPL/AGPL/copyleft scan)" — exit code 1
- **Error excerpt:** `check_licenses: 1 violation(s): - multi_dropdown: ...`
- **Confirms:** Gate detects real pub.dev GPL-3.0, not only synthetic fixtures

### Test 2: Missing GOSL header
[same format]

### Test 3: Missing DEPENDENCIES.md entry
[same format]

## 5. CI-green confirmation

- **Final commit on main:** `<hash>` (after all Blocker + non-waived Should fixes)
- **CI run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/<id>
- **Status:** All 3 jobs green (gates / android / ios)
- **Date:** <date>

---
_Phase 02 closed: <date>_
_Phase 03 unblocked._
```

### Example 5: Atomic fix commit format

```bash
# Per finding, one commit
git add <files-fixed>
git commit -m "fix(02-rev): <finding title from triage table>

Addresses [Blocker|Should] finding #N from 02-REVIEW.md:
<1-line rationale, if not self-evident>"

# Immediately verify CI green before next commit
git push
gh run watch
# Only proceed to next finding once green
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pre-commit hooks for policy enforcement | CI-only enforcement (dart run tool/check_*) | Phase 01 decision (STATE.md) | Authoritative single source, no bypass via `--no-verify` |
| Single-agent exhaustive Explore for review | 4 parallel sub-agents sliced by concern + main as synthesizer | Phase 02 decision (CONTEXT.md) | Wall-clock speedup + specialized coverage per concern |
| Stress-test only license scan (roadmap §3) | Stress-test ALL 3 guardrails (license + headers + deps.md) | Phase 02 decision (CONTEXT.md) | 3× evidence coverage ; roadmap §3 was the minimum, not the intent |
| Synthetic fixture LICENSE for GPL test | Real pub.dev GPL-3.0 package | Phase 02 decision (CONTEXT.md) | Proves parser handles real-world LICENSE wording variations, not just fixture text |
| `act` local CI simulation | Real branch push + observe real CI run | Phase 02 decision (CONTEXT.md) | "CI est l'autorité" applies to adversarial tests too |

**Deprecated/outdated:**
- **Custom_lint + riverpod_lint** : deferred to Phase 03/04 (STATE.md) — ecosystem analyzer ^9 convergence pending, not Phase 02's job.
- **PR-based reviews** : solo-dev, no tiered reviewer, push direct on main per CLAUDE.md §Git.

## Open Questions

1. **Will `multi_dropdown 3.1.1` actually trigger the GPL marker, or only the `license:` field?**
   - What we know: pub.dev reports `GPL-3.0` for `multi_dropdown`.
   - What's unclear: Does the packaged LICENSE file on pub.dev contain the exact canonical string `GNU GENERAL PUBLIC LICENSE`? If it only has a short summary, detection runs via the `pubspec.yaml` `license:` field path instead.
   - Recommendation: Proceed with `multi_dropdown` as primary. Document which detection path fired (field vs substring) in evidence bloc — both count as "gate works on real package". Backup candidate: `line_icons 2.0.3` or `iconsax 0.0.8`.

2. **Should the soak-test prune (1000+ lines → 10 MB) be triggered during visual walk?**
   - What we know: Claude's Discretion — user explicitly left this open.
   - What's unclear: Whether the visual walk will surface symptoms that justify the soak-test (e.g. prune logic suspicious during code read).
   - Recommendation: Decide pendant la walk — if nothing suspect surfaces, the unit test `test/file_logger_prune_test.dart` is sufficient. If prune behavior looks fishy on read-through, trigger the soak-test.

3. **Does the visual walk need a Windows-specific `flutter run -d windows` AND Android emulator run, or just Windows?**
   - What we know: CLAUDE.md §Plateformes recommends both Windows + Android for logic dev. CONTEXT.md Agent #2 scope says "sur Windows" (explicit).
   - What's unclear: Whether Android emulator walk adds signal given Android platform channels for SharedPreferences + path_provider differ from Windows.
   - Recommendation: Windows is mandatory (user-locked). Android emulator walk is bonus — if Agent #2 has cheap access to an emulator, run it; otherwise Windows is sufficient for Phase 02 gate purposes. iOS remains gated to CI-only (no Mac dev host, per roadmap).

4. **Who's responsible for `02-REVIEW.md` authorship — main agent or a dedicated writer sub-agent?**
   - What we know: CONTEXT.md says "Claude-main : synthesizer only" for findings consolidation.
   - What's unclear: Whether the final `02-REVIEW.md` write is also main's job (natural) or if it would benefit from a dedicated writer agent.
   - Recommendation: Main writes. The 5 sections are assembled from (a) user input captured verbatim, (b) 4 sub-agents structured outputs deduped, (c) adversarial evidence captured by main's own `gh run view` calls, (d) final CI run URL. No need for extra agent.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Flutter SDK, BSD-3-Clause) + `package:test` 1.30.0 for tool/test/* |
| Config file | none — `dart_test.yaml` not needed |
| Quick run command | `flutter analyze --fatal-infos --fatal-warnings && dart format --line-length 160 --set-exit-if-changed . && flutter test test/smoke_test.dart` |
| Full suite command | `flutter test && dart test tool/test/ && dart run tool/check_headers.dart && dart run tool/check_licenses.dart && dart run tool/check_dependencies_md.dart` |

### Phase Requirements → Test Map

Phase 02 is a review gate — it does NOT add new REQ-IDs. Instead, it **exercises** Phase 01's gates with poison injection. The validation map documents what each gate IS EXPECTED TO CATCH.

| Requirement verified | Behavior | Test Type | Automated Command | File Exists? |
|----------------------|----------|-----------|-------------------|--------------|
| FOUND-01 | `strict-casts/inference/raw-types` still enforced | static analysis | `flutter analyze --fatal-infos --fatal-warnings` | OK (in `ci.yml` gates step) |
| FOUND-02 | GOSL header scan catches violation on adversarial branch | integration | `gh run view <adversarial/02-header-missing run>` — exit 1 | OK (pre-existing) |
| FOUND-03 | DEPENDENCIES.md cross-ref catches missing entry | integration | `gh run view <adversarial/02-deps-missing-entry run>` — exit 1 | OK (pre-existing) |
| FOUND-04 | License scan catches real GPL from pub.dev | integration | `gh run view <adversarial/02-licence-gpl-scan run>` — exit 1 | OK (pre-existing) |
| FOUND-04 | CI fan-out: gates failure blocks android + ios | meta-CI | Observe `needs: gates` gate blocks downstream jobs (part of each adversarial run) | OK (`.github/workflows/ci.yml` line 62, 151) |
| FOUND-05 | Pin enforcement on adversarial branches | unit | `flutter test test/pubspec_pinned_test.dart` (ran on each adversarial push) | OK (pre-existing) |
| FOUND-06 | FileLogger visual walk confirms real runtime on Windows | manual (user + Agent #2) | `flutter run -d windows`, 7-tap, share, clear-all | Windows host configured |
| FOUND-07 | Constants still all in `lib/config/constants.dart` | unit + scan | `flutter test test/constants_test.dart` + Agent #3 grep | OK (pre-existing) |
| FOUND-08 | `dart format --line-length 160` clean | static | `dart format --line-length 160 --set-exit-if-changed .` | OK (in `ci.yml` gates step) |

### Sampling Rate

- **Per adversarial push:** Observe exact CI run until conclusion (success or failure). Gate step logs captured via `gh run view --log-failed`.
- **Per fix commit:** Quick run (`flutter analyze && dart format --set-exit-if-changed . && flutter test test/smoke_test.dart`) before push, then `gh run watch` after.
- **Per wave merge (Phase 02 has one wave):** Full suite green locally + on `main` after all fixes applied.
- **Phase gate:** Full suite green on `main` final commit + `02-REVIEW.md` fully filled (5 sections) + 3 adversarial branches deleted + `gsd-verifier` green.

### Wave 0 Gaps

- None for new infrastructure. All tests, gates, and CI steps are pre-existing (Phase 01 delivered them).
- **Wave 0 for Phase 02 is:** (a) the user's IDE review session being held (CLAUDE.md §Code Review Phases §1), and (b) `gh` CLI authenticated + network access to pub.dev confirmed.

If Agent #1 designs a 4th guardrail test (e.g. stress `_manualOverrides` by faking a fake package), that's a scope creep — NOT in Phase 02. Note as `Noted` finding for future review gate.

## Sources

### Primary (HIGH confidence)

- `.planning/phases/01-foundation/01-VERIFICATION.md` — source of truth for what Phase 01 already verified. Status: PASSED.
- `.planning/phases/01-foundation/01-CONTEXT.md` + `01-RESEARCH.md` + 4 PLAN.md + 4 SUMMARY.md — full Phase 01 artifact trail.
- `CLAUDE.md` §Code Review Phases (user-first protocol, titles + explanation, user selects fixes). §Git & CI (gh authenticated, solo dev direct-push, atomic commits). §Licences interdites / acceptées (GPL forbidden, MIT/BSD/Apache/etc allowed). §Télémétrie (no SDKs without explicit user action). §Longueur de ligne (160 chars). §Plateformes (Windows + Android dev, iOS CI+sideload).
- `tool/check_licenses.dart` (source — exact exit code contract, `_allowedSpdx` set, `_manualOverrides` map, `_forbiddenSubstrings` list including `GNU GENERAL PUBLIC LICENSE`).
- `tool/check_headers.dart` (source — byte-exact match, exclude `.g.dart` / `.freezed.dart`, default roots `lib/test/tool`).
- `tool/check_dependencies_md.dart` (source — pubspec.lock vs DEPENDENCIES.md diff, ignores rows with `/` for GitHub Actions table).
- `.github/workflows/ci.yml` (source — 3 jobs `gates → android + ios`, `needs: gates` fan-out gates, diagnostic step continue-on-error, Podfile.lock placeholder bootstrap).
- `tool/test/check_licenses_test.dart`, `check_headers_test.dart`, `check_dependencies_md_test.dart` (existing fixture patterns — `returns 0/1/2` contract).
- `.planning/STATE.md` Phase 01 decisions (MPL-2.0-Linux-only for dbus/geoclue/gsettings, Option A Podfile.lock bootstrap, exit code contract 0/1/2).
- pub.dev `multi_dropdown 3.1.1` license metadata (GPL-3.0 confirmed via WebFetch).

### Secondary (MEDIUM confidence)

- pub.dev `line_icons 2.0.3` and `iconsax 0.0.8` license metadata — GPL-3.0 per pub.dev search (single source, but pub.dev is authoritative for its own metadata).
- GitHub CLI `gh run view` / `gh run list --branch` documentation (cli.github.com) — standard, well-documented.

### Tertiary (LOW confidence)

- None. Every recommendation in this research is backed by existing artifact in the repo or pub.dev metadata directly.

## Metadata

**Confidence breakdown:**

- User Constraints capture: HIGH — verbatim copy from `02-CONTEXT.md`, all decisions logged.
- Audit methodology (4 parallel agents + synthesizer): HIGH — user-locked.
- Adversarial pattern (throwaway branches + real pub.dev GPL): HIGH — CLAUDE.md + CONTEXT.md + repo tooling all align.
- GPL package recommendation (`multi_dropdown 3.1.1`): MEDIUM-HIGH — pub.dev metadata confirmed via WebFetch ; remaining uncertainty is which detection path (field vs substring) fires at runtime, both count as success.
- Code examples: HIGH — each uses existing repo tooling (gh, git, flutter, dart) and already-in-ci scripts ; no unverified commands.
- Pitfalls: HIGH — derived from existing STATE.md decisions (exit code contract, Option A Podfile, MPL overrides) and CLAUDE.md rules.
- Review.md 5-section format: HIGH — user-locked in CONTEXT.md.

**Research date:** 2026-04-17
**Valid until:** 30 days (stable review protocol ; no fast-moving externals). Re-check before Phase 04 (next review gate) if any guardrail script is modified or if pub.dev removes `multi_dropdown` / changes its license.

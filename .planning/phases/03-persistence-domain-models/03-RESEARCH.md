// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

# Phase 03: Persistence & Domain Models — Research

**Researched:** 2026-04-18
**Domain:** Persistence (Drift/SQLite), immutable domain modelling (Freezed), pure-Dart utilities (tile math, reveal calc), versioned JSON migrator, DB migration framework + backup/sanity.
**Confidence:** HIGH (Drift, Freezed, SQLite, tile math verified via official docs); MEDIUM (lint ecosystem convergence — needs confirmation at implementation time); LOW (exact bitmap column strategy — choose at plan time between two verified-viable options).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Stockage DB + backup:**
- **Fichier DB** : `<app_support>/mirkfall.db` via `getApplicationSupportDirectory()` — invisible utilisateur, jamais iCloud-backupé, séparation propre Documents vs AppSupport.
- **Dossier backups** : `<app_support>/db_backups/` — même racine que la DB (copy atomique garantie).
- **Rétention backups** : **3 derniers, rolling** — nommés `mirkfall.db.backup-v{N}-to-v{M}-<timestamp>`.
- **Timing backups** : pré-migration automatique (via `MigrationStrategy.beforeOpen` avant `onUpgrade`) + bouton "Backup DB now" dans le debug menu.
- **WAL mode** : `PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA busy_timeout = 5000;` appliqué en `MigrationStrategy.beforeOpen`.

**Schéma d'ID:**
- **ULID in-house** (zero dep), ~30-40 lignes. 48 bits timestamp ms + 80 bits random, 26 chars. K-sortable → `ORDER BY id` = ordre de création.
- **Wrapper domaine** : `extension type SessionId(String value)` (Dart 3). Zero-cost runtime, type-safe.
- **Seam génération** : interface `IdGenerator` dans `lib/domain/ids/` + implémentations `RandomIdGenerator` (prod) et `SeededIdGenerator` (tests). Injection via provider Riverpod `idGeneratorProvider`.
- **Préfixes typés** : `sess_`, `mrk_`, `cat_`, `mst_`, `phr_`, `rvt_`. **Préfixe stocké dans la valeur wrappée**.

**Framework migration (Drift + JsonMigrator):**
- **Drift V1→V2 fictive livrée en Phase 03** : V2 = V1 + colonne `notes TEXT NULLABLE` sur `t_sessions`.
- **JsonMigrator V1→V2 fictive livrée en Phase 03** : rename `mirk_radius_m` → `reveal_radius_m` dans payload session.
- **Test strategy hybride** : schema canonique via `dart run drift_dev schema dump` → `drift_schemas/drift_schema_v{1,2}.json` commités + `VerifyMigration` + data de test via fichiers `.sql` hand-written.
- **Pre-migration backup** : exécuté avant chaque `onUpgrade`, fichier survit jusqu'à sanity check row-count OK, puis rotation (3 rolling).
- **Sanity row-count** : après `onUpgrade`, comparer `COUNT(*)` par table. Échec hard (throw `MigrationFailureException`) si row-count a diminué.

**Shape config MirkStyle:**
- **Sealed class `MirkStyleConfig` + `UnknownConfig` catch-all**. Exhaustivité pattern match + dégradé gracieux sur inconnus.
- **Validation au boundary** : `MirkStyleConfig.fromJson` dispatch selon `rendererType`. Inconnu → `UnknownConfig(raw)`.
- **Storage Drift** : `TextColumn get config => text().map(MirkStyleConfigJsonConverter())();`.

**Politique cascade DELETE:**
- **`t_sessions.delete(id)`** : FK `ON DELETE CASCADE` sur `t_markers`, `t_revealed_tiles`, `t_photos` (via transitive).
- **`t_marker_categories.delete(id)`** : **PAS de CASCADE**. Transaction : `UPDATE t_markers SET category_id = 'cat_default' WHERE ...; DELETE FROM t_marker_categories WHERE id = ?;`.
- **Hard-delete uniquement** : pas de `deletedAt`, pas de corbeille.
- **Table `t_photos` déclarée en Phase 03** : `PhotoRef` déjà dans les modèles Phase 03.

**DateTime + timezone:**
- **Stockage domaine** : UTC + offset original préservé. Deux champs : `startedAtUtc: DateTime` (INT unix ms via `UnixMsToDateTimeConverter`) + `startedAtOffsetMinutes: int` (INT + `CHECK (BETWEEN -720 AND 840)`).
- **JSON export format** : ISO 8601 avec offset explicite, un seul champ (`"startedAt": "2026-06-10T08:00:00+02:00"`).
- **Validation import** : timestamp malformé → import annulé avec message clair (PORT-09 tout-ou-rien).

**Stratégie erreurs domain:**
- **Exceptions typées** (pas de `Result<T, E>`) dans `lib/domain/errors/` : `SessionNotFoundException`, `InvalidSessionTransition`, `ConcurrentActivationException`, `MarkerNotFoundException`, `CategoryInUseException`, `MirkStyleConfigException`, `ImportValidationException`, `MigrationFailureException`.
- Toutes `implements Exception` (pas `Error`).
- **Invariants domain** : assertions dans constructor Freezed via `@Assert` décorateur.
- **find vs require** : `findById` (null si absent) vs `requireById` (throw).
- **Violations DB** : catch `SqliteException` dans store, wrap en exception domain. Pas de fuite Drift vers couches supérieures.

**Test runner split + fixtures:**
- **Tout sous `dart test`** : pure utils + stores Drift (via `NativeDatabase.memory()`) + migrations tests. Zero Flutter dep. CI : un seul job Ubuntu.
- **`AppDatabase(QueryExecutor executor)` injectable**.
- **Fixtures** : `test/fixtures/drift_schemas/`, `test/fixtures/json/`, `test/fixtures/db_seed/`. Tout commité.
- **CI** : ajout `dart test` en fin de step du job `gates`, pas de nouveau job.

**Nommage tables, colonnes, indices:**
- Tables au pluriel, préfixe `t_` : `t_sessions`, `t_markers`, `t_revealed_tiles`, `t_marker_categories`, `t_mirk_styles`, `t_photos`.
- Mapping Dart via override `tableName`.
- Colonnes : snake_case (défaut Drift).
- Indices : `idx_t_<table>_<column>[_<qualifier>]` (ex: `idx_t_sessions_status_active`).
- FK colonnes : `<table_référencée_singulier>_id`.

**Entités vs DTOs:**
- **Pas de DTO 1:1** : `Session`, `Marker`, `MarkerCategory`, `MirkStyle` = entités domain ET modèles d'export JSON.
- **DTOs justifiés** : `SessionBundleExport`, `MarkersOnlyImport`, `RevealedTileExport` (chacun documenté par docstring).

**Lint ecosystem:**
- **`custom_lint` + `riverpod_lint` ajoutés en Phase 03**. Re-pin versions compatibles avec analyzer du stack existant.

### Claude's Discretion

- Valeur exacte de `busy_timeout` (5000 ms par D4, à confirmer via test charge).
- Placement exact `lib/infrastructure/ids/ulid.dart` vs `lib/domain/ids/id_generator.dart` (interface dans domain, impl dans infrastructure — convention déjà posée Phase 01).
- Champs Freezed exacts des `AtmosphericConfig` / `ShaderConfig` V1.0 (Phase 09 décidera les paramètres visuels ; Phase 03 peut sealed class + 1 champ placeholder).
- Nommage exact `display_name` vs `name` selon entité.
- Format exact du fichier `backup-v{N}-to-v{M}-<timestamp>` (ISO vs unix ms vs compact).
- Implementation exacte du bouton "Backup DB now" du debug menu (copier vs `VACUUM INTO`).
- Liste exacte des default categories IDs réservés (`cat_default` certain ; reste Phase 11).
- Stratégie `setBitCount` (colonne cached vs trigger SQL vs compute runtime).
- **Choix du format de stockage bitmap 64×64** parmi les options documentées ci-dessous (section "Standard Stack → Bitmap storage").

### Deferred Ideas (OUT OF SCOPE)

- Rotation backups par âge (3 rolling suffit V1.0).
- Soft-delete / corbeille / undo (pas V1.0).
- `VACUUM INTO` vs copy brute pour backups (Claude's discretion Phase 03, pas architectural).
- Champs visuels exacts `AtmosphericConfig` / `ShaderConfig` (Phase 09).
- Seed effectif des default categories (Phase 11 — Phase 03 réserve juste l'ID).
- Pipeline photos (Phase 11 — Phase 03 livre model + table + port).
- `ImportExportController` + ZIP archive + SCHEMA.md (Phase 13).
- Matrice tests cross-version V1↔V2↔V3 (PORT-13 Phase 13).
- `setBitCount` cached vs trigger vs runtime compute (Claude's discretion Phase 03).
- Stats « % du monde révélé » (V1.x STAT-*).
- Update paths à chaque changement `path_provider` (Phase 15).
- `custom_lint` règles custom enforcement imports inter-layers (Phase 03 ou Phase 04 review-gate, selon si stock lints couvrent).
- POC MPL-unreachable heuristic fix pour `tool/check_licenses.dart` (Phase 02 backlog, pas mélangé Phase 03).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **SESS-06** | Démarrer une session arrête automatiquement toute autre session en cours (exclusivité enforcée au niveau DB). | Partial unique index Drift : `CREATE UNIQUE INDEX idx_t_sessions_status_active ON t_sessions(status) WHERE status='active'`. SQLite enforce au niveau DB — toute tentative de second `status='active'` → `SqliteException` extended code 2067 (`SQLITE_CONSTRAINT_UNIQUE`). Store wrap en `ConcurrentActivationException`. Validated: sqlite.org/partialindex.html + drift docs `@TableIndex.sql()`. |
| **MIRK-03** | Le mirk effacé reste effacé pour toute la durée de vie de la session (pas de re-brumage). | Bitmap 64×64 par parent-tile stocké en colonne BLOB (`Uint8List` 512 bytes / tile). Write pattern : `INSERT` nouveau row si absent, sinon `UPDATE bitmap = bitmap | :mask` (OR-monotone). La monotonie bitwise OR garantit qu'un bit à 1 ne peut plus redevenir 0 — invariant algébrique, pas juste convention. Alternative équivalente : `INSERT OR IGNORE` pour le row initial + `UPDATE` OR-mask. Tests unitaires : set bit au cycle 1, mask vide au cycle 2, assert bit toujours à 1. |

</phase_requirements>

## Summary

Phase 03 pose les deux fondations les plus coûteuses à réécrire : **stockage bitmap du mirk révélé** (MIRK-03) et **format d'échange JSON versionné** (envelope D9). Toute la phase tient sur Drift 2.32.1 + Freezed 3.2.3 déjà pinnés en Phase 01, avec un double test-runner split résolu par la décision d'unifier sous `dart test` (zero Flutter dep) grâce à `NativeDatabase.memory()` + l'injection `AppDatabase(QueryExecutor)`.

Les deux invariants critiques (SESS-06 "au plus une session active", MIRK-03 "bit revealed monotonique") sont poussés au niveau SQLite : un **partial unique index** `WHERE status='active'` pour SESS-06 (violation → `SQLITE_CONSTRAINT_UNIQUE` code 2067), et l'**algèbre bitwise OR** pour MIRK-03 (bit↑1 ne peut plus ↓0 par construction mathématique). Les deux approches transfèrent la responsabilité de la discipline caller vers la base, exactement comme la roadmap l'exige ("une contrainte DB, pas une assertion caller").

Le framework migration double-stack (Drift `schemaVersion` + `JsonMigrator` custom) livre sa V1→V2 fictive en Phase 03 au lieu de Phase 04 : c'est en l'utilisant qu'on trouve les trous d'API. Le pipeline de test officiel Drift (`drift_dev schema dump` → `drift_dev schema generate` → `SchemaVerifier.migrateAndValidate`) est mature et documenté.

**Primary recommendation:** Stocker le bitmap 64×64 en **colonne BLOB Dart `Uint8List` de 512 bytes/tile** (option A ci-dessous), écrire via read-modify-write `UPDATE ... SET bitmap = :newBytes` dans une transaction Drift où `newBytes = oldBytes | maskBytes`. Simple à raisonner, simple à tester (fixture `.sql` d'INSERT d'une ligne, test calcule un mask, assert byte-par-byte sur le résultat), aucun code C natif à invoquer, 100 % portable sur `NativeDatabase.memory()` côté Ubuntu CI.

## Standard Stack

### Core (déjà pinnés Phase 01, aucun ajout runtime)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `drift` | 2.32.1 | ORM SQLite + migrations + codegen | Library standard Flutter persistence. 667k downloads/mois. Stable API, migration framework mature, bonne pureté Dart (compile sans Flutter pour tests). MIT. |
| `drift_flutter` | 0.3.0 | Helper `driftDatabase(name: ...)` avec `path_provider` auto-wiring | Officiel simonbinder, wrap path_provider. **Attention** : retourne `getApplicationDocumentsDirectory()` par défaut — on veut `getApplicationSupportDirectory()` → utiliser `DriftNativeOptions.databasePath` pour override. MIT. |
| `sqlite3_flutter_libs` | 0.6.0+eol | Bundle sqlite3 natif pour Android/iOS | Déjà pinné. **Note importante** : sur `dart test` / Ubuntu CI, ce package ne s'applique pas — sqlite3 doit être dispo via `libsqlite3-0 libsqlite3-dev` apt install OU via `package:sqlite3` 2.x+ (qui bundle via code assets). |
| `freezed_annotation` | 3.1.0 | Annotations Freezed (runtime) | Déjà pinné. Dart 3 compat, supporte `sealed class`, `@Assert`, et la génération `fromJson` dispatch par discriminateur. MIT. |
| `json_annotation` | 4.9.0 | Annotations json_serializable | Déjà pinné. Génère (de)sérialisation standard. BSD. |
| `path` | 1.9.1 | `p.join()` multi-plateforme | Déjà pinné. Obligatoire CLAUDE.md §Naming de chemins. BSD. |
| `path_provider` | 2.1.5 | `getApplicationSupportDirectory()` | Déjà pinné. Retourne le dossier idéal (invisible, non-iCloud-backupé, stable entre versions OS). BSD. |
| `collection` | 1.19.1 | `ListEquality`, `MapEquality` | Déjà pinné. Utile pour les Freezed equality tests sur `Uint8List` (besoin `ListEquality<int>().equals`). BSD. |
| `flutter_riverpod` | 3.1.0 | State management + DI | Déjà pinné. Providers `idGeneratorProvider`, `appDatabaseProvider`. |
| `riverpod_annotation` | 4.0.0 | `@riverpod` annotations | Déjà pinné. Phase 03 = premier usage effectif. |

### Supporting (dev_dependencies — ajouts Phase 03)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `drift_dev` | match runtime (2.32.1) | Codegen Drift + `schema dump/generate/steps` CLI | **Transitive via `build_runner`** — déjà utilisable. Vérifier via `dart pub deps` en début Phase 03. Appelé directement par `dart run drift_dev schema dump/generate/steps`. |
| `custom_lint` | **À re-pin en début Phase 03** | Plugin analyzer pour custom lints | Deferred de Phase 01. Le trio `custom_lint` + `riverpod_lint` + analyzer doit converger. `custom_lint` 0.8.1 targets analyzer ^8.0.0 ; `custom_lint` 0.7.5 targets analyzer ^6.7.0 ; vérifier pub.dev au moment exact du plan. Recommandation : la version la plus récente compatible avec l'analyzer déjà en place (via `flutter_lints 6.0.0` → `lints 6.1.0`). |
| `riverpod_lint` | **À re-pin idem** | Lints Riverpod (@riverpod misuse, etc.) | Deferred de Phase 01. Vérifier compat avec `custom_lint` choisi. Vraisemblablement `riverpod_lint` 2.6.5 ou supérieur — mais la ligne d'attache est le couple `analyzer` + `custom_lint`. |
| `drift` + `package:test` | déjà pinné `test: 1.30.0` | `dart test` runner | Déjà disponible après Phase 02. Un seul runner unifié pour tous les tests Phase 03. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bitmap stocké en colonne BLOB Dart (512 bytes `Uint8List`) | Bitmap stocké en BLOB SQLite avec `sqlite3_blob_open()` incremental I/O | Incremental BLOB I/O évite de charger 512 bytes par update, mais demande bindings C via `package:sqlite3` direct + complique le cross-platform. Pour 64×64 (512 bytes) le gain est nul — on charge déjà moins qu'un int64 row-dict overhead Drift. Option A gagne. |
| Bitmap en 64 BigInt rows (1 row = 1 ligne 64 bits du bitmap) | Bitmap en 1 row BLOB | 64 rows/tile multiplie par 64 le cost d'insertion + requête + la complexité du schema. Option A (BLOB 512B) gagne sans contestation. |
| `json_serializable` `fromJson` default sur `runtimeType` pour MirkStyleConfig | Custom dispatcher factory avec `rendererType` + catch-all `UnknownConfig` | Freezed 3.x support natif de `@Freezed(fallback: '...')` pour unknown discriminator → clean. Le custom dispatcher est plus explicite mais dupe la logique. Recommandation : utiliser `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` puis custom `fromJson` factory côté `MirkStyleConfig` qui wrap si besoin. **À valider** en plan : Freezed 3.2.3 peut avoir une syntaxe légèrement différente. |
| `IdGenerator` seam + seeded impl | Hardcoded `Random.secure()` dans un helper | Seam préservé = tests déterministes gratuits (IDs reproductibles). Cost ~20 lignes. Gain : tests sans "expect contains valid ULID"-style regex, expect exact `'sess_01JBA...'`. |

**Installation:**
```bash
# Runtime : aucun ajout — déjà pinné Phase 01.
# Dev : ajout custom_lint + riverpod_lint en Phase 03.
# (Versions exactes à re-pinner en début de plan — voir "Open Questions".)

# Commandes codegen (Phase 03) :
dart run build_runner build --delete-conflicting-outputs  # freezed + json_serializable + drift + riverpod_generator
dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/ --data-classes --companions
dart run drift_dev schema steps drift_schemas/ lib/infrastructure/db/migrations/schema_versions.dart
```

### Bitmap Storage — Final Recommendation

Stocker chaque bitmap 64×64 en une **seule colonne BLOB** de **512 bytes** (`Uint8List`).

- **Drift declaration:**
  ```dart
  @DataClassName('RevealedTileRow')
  class RevealedTiles extends Table {
    @override String get tableName => 't_revealed_tiles';
    TextColumn get id => text()();                    // rvt_<ULID>
    TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
    IntColumn get parentX => integer()();             // tile X at zoom 14
    IntColumn get parentY => integer()();             // tile Y at zoom 14
    IntColumn get parentZoom => integer().withDefault(const Constant(14))();
    BlobColumn get bitmap => blob()();                // 512 bytes = 64*64 bits
    IntColumn get setBitCount => integer().withDefault(const Constant(0))();  // cached popcount
    IntColumn get updatedAtUtc => integer().map(const UnixMsToDateTimeConverter())();

    @override
    Set<Column> get primaryKey => {id};
    @override
    List<Set<Column>> get uniqueKeys => [{sessionId, parentX, parentY, parentZoom}];
  }
  ```
- **Write pattern (OR-monotone):**
  ```dart
  await db.transaction(() async {
    final existing = await (db.select(db.revealedTiles)
      ..where((t) => t.sessionId.equals(sessionId.value) &
                     t.parentX.equals(x) &
                     t.parentY.equals(y))
    ).getSingleOrNull();
    if (existing == null) {
      await db.into(db.revealedTiles).insert(RevealedTilesCompanion.insert(
        id: idGen.newId('rvt_').value,
        sessionId: sessionId.value,
        parentX: x, parentY: y,
        bitmap: maskBytes,
        setBitCount: Value(_popcount(maskBytes)),
        updatedAtUtc: DateTime.now().toUtc(),
      ));
    } else {
      final merged = _or(existing.bitmap, maskBytes);  // bytewise OR, Uint8List
      await (db.update(db.revealedTiles)..where((t) => t.id.equals(existing.id)))
        .write(RevealedTilesCompanion(
          bitmap: Value(merged),
          setBitCount: Value(_popcount(merged)),
          updatedAtUtc: Value(DateTime.now().toUtc()),
        ));
    }
  });
  ```
- **Why this wins:**
  - **Monotonie par construction** : `a | b ≥ a` bit-par-bit, donc un bit à 1 ne redescend jamais. MIRK-03 garanti algébriquement.
  - **Idempotence** : `a | a = a`, donc appliquer le même mask N fois = 1 fois. Pas besoin de `INSERT OR IGNORE` tricks.
  - **Test trivial sous `dart test`** : Uint8List in, Uint8List out, zero plugin. Compare byte-par-byte.
  - **Pas de BLOB API C** : portable Android/iOS/Windows/Ubuntu identique.
  - **`setBitCount` column cached** : mise à jour dans la même transaction, zéro coût de calcul à la lecture. Trigger SQL serait plus exotique — runtime compute serait lent sur 50k tiles. Column cached gagne.

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── domain/                                    # PURE Dart. No flutter/, no drift/.
│   ├── ids/
│   │   ├── session_id.dart                    # extension type SessionId(String value)
│   │   ├── marker_id.dart                     # idem for each entity
│   │   ├── category_id.dart
│   │   ├── mirk_style_id.dart
│   │   ├── photo_ref_id.dart
│   │   ├── revealed_tile_id.dart
│   │   ├── id_generator.dart                  # interface IdGenerator { SessionId newId(String prefix); }
│   │   └── default_ids.dart                   # kCategoryDefaultId = CategoryId('cat_default')
│   ├── sessions/
│   │   ├── session.dart                       # @freezed Session with invariants
│   │   ├── session_status.dart                # enum SessionStatus { active, stopped }
│   │   └── session_store.dart                 # abstract class SessionStore (port)
│   ├── markers/
│   │   ├── marker.dart
│   │   ├── marker_category.dart
│   │   ├── marker_store.dart                  # port
│   │   └── marker_category_store.dart         # port
│   ├── mirk/
│   │   ├── mirk_style.dart                    # @freezed MirkStyle with config
│   │   ├── mirk_style_config.dart             # sealed class + UnknownConfig
│   │   └── mirk_style_store.dart              # port
│   ├── revealed/
│   │   ├── revealed_tile.dart                 # @freezed RevealedTile
│   │   ├── revealed_tile_store.dart           # port
│   │   ├── tile_math.dart                     # pure functions — lat/lon ↔ tile
│   │   └── reveal_calculator.dart             # pure functions — radius → mask computation
│   ├── photos/
│   │   ├── photo_ref.dart                     # @freezed PhotoRef (path + size metadata)
│   │   └── photo_store.dart                   # port only — impl Phase 11
│   ├── envelope/
│   │   ├── envelope.dart                      # @freezed Envelope {schemaVersion, type, payload}
│   │   └── json_migrator.dart                 # framework + identity v1 + v1→v2 fictive
│   ├── errors/
│   │   ├── session_errors.dart                # SessionNotFoundException, InvalidSessionTransition
│   │   ├── marker_errors.dart                 # MarkerNotFoundException
│   │   ├── category_errors.dart               # CategoryInUseException
│   │   ├── mirk_errors.dart                   # MirkStyleConfigException
│   │   ├── import_errors.dart                 # ImportValidationException
│   │   ├── concurrent_errors.dart             # ConcurrentActivationException
│   │   └── migration_errors.dart              # MigrationFailureException
│   └── README.md                              # (already exists — rule "no flutter/drift imports")
├── infrastructure/
│   ├── db/
│   │   ├── app_database.dart                  # @DriftDatabase, AppDatabase(QueryExecutor)
│   │   ├── app_database_provider.dart         # appDatabaseProvider (Riverpod) w/ path_provider wiring
│   │   ├── pragma_setup.dart                  # fn applied via beforeOpen: WAL + synchronous + busy_timeout
│   │   ├── backup.dart                        # DbBackupService (pre-migration + debug-menu button)
│   │   ├── schema_sanity.dart                 # SchemaSanityChecker — row-count pre/post + hard-fail
│   │   └── migrations/
│   │       ├── schema_versions.dart           # generated via drift_dev schema steps
│   │       └── v1_to_v2_notes.dart            # fictive migration (add t_sessions.notes column)
│   ├── ids/
│   │   ├── ulid.dart                          # Crockford base32 encoder + generator ~30 lines
│   │   ├── random_id_generator.dart           # production IdGenerator impl
│   │   └── seeded_id_generator.dart           # test IdGenerator impl (deterministic)
│   └── stores/
│       ├── drift_session_store.dart           # SessionStore impl — wraps SqliteException → domain errors
│       ├── drift_marker_store.dart
│       ├── drift_revealed_tile_store.dart
│       ├── drift_marker_category_store.dart   # cascade-safe delete via transaction
│       └── drift_mirk_style_store.dart
├── application/
│   └── providers/
│       ├── id_generator_provider.dart         # @Riverpod RandomIdGenerator
│       ├── app_database_provider.dart         # @Riverpod AppDatabase with beforeOpen wiring
│       ├── session_store_provider.dart
│       ├── marker_store_provider.dart
│       └── ...                                # one per store
├── config/
│   └── constants.dart                         # + kDbFilename, kDbBackupDirName, kMaxDbBackups, kDbBusyTimeoutMs, kRevealedTileZoom=14
└── main.dart

test/
├── fixtures/
│   ├── drift_schemas/
│   │   ├── drift_schema_v1.json               # dumped via drift_dev
│   │   └── drift_schema_v2.json
│   ├── json/
│   │   ├── session_v1.json
│   │   ├── session_v2.json
│   │   ├── markers_only_v1.json
│   │   └── mirk_style_unknown_renderer.json   # UnknownConfig fallback test
│   └── db_seed/
│       ├── v1_baseline.sql                    # INSERT statements for migration tests
│       └── revealed_tile_session_50tiles.sql
├── generated_migrations/                      # drift_dev schema generate output (committed)
│   ├── schema.dart
│   ├── schema_v1.dart
│   └── schema_v2.dart
├── domain/                                    # pure-Dart tests (dart test)
│   ├── tile_math_test.dart
│   ├── reveal_calculator_test.dart
│   ├── session_invariants_test.dart           # @Assert → AssertionError
│   ├── mirk_style_config_fromjson_test.dart   # UnknownConfig fallback
│   └── json_migrator_test.dart                # v1 identity + v1→v2 fictive
├── infrastructure/
│   ├── ids/
│   │   ├── ulid_test.dart                     # k-sortability, 26 chars, prefix
│   │   ├── random_id_generator_test.dart
│   │   └── seeded_id_generator_test.dart      # determinism
│   ├── db/
│   │   ├── app_database_pragma_test.dart      # asserts journal_mode=wal, synchronous=1, busy_timeout=5000 via PRAGMA query
│   │   ├── backup_test.dart                   # copy-then-verify-rowcount
│   │   ├── schema_sanity_test.dart            # hard-fail on row count drop
│   │   └── migration_v1_to_v2_test.dart       # uses SchemaVerifier + seeded data
│   └── stores/
│       ├── session_store_exclusivity_test.dart    # SESS-06 partial unique index
│       ├── revealed_tile_store_idempotence_test.dart  # MIRK-03 OR-monotone
│       ├── marker_store_test.dart
│       ├── marker_category_store_cascade_test.dart    # non-cascade + reassign in transaction
│       └── ...
└── ...existing Phase 01/02 tests

drift_schemas/                                  # (at repo root) — source of truth for schema snapshots
├── drift_schema_v1.json                        # produced by drift_dev schema dump
└── drift_schema_v2.json
```

### Pattern 1: Injectable `AppDatabase(QueryExecutor)` for test-runner split

**What:** `AppDatabase` ne prend pas sa connexion en interne, elle la reçoit. Un seul constructor, un seul flot de tests.
**When to use:** Toujours. C'est le pattern recommandé par Drift pour testing ([Source: drift.simonbinder.eu/testing](https://drift.simonbinder.eu/testing/)).

```dart
// Source: https://drift.simonbinder.eu/testing/ (verified 2026-04-18)
@DriftDatabase(
  tables: [Sessions, Markers, RevealedTiles, MarkerCategories, MirkStyles, Photos],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2; // V1 baseline + V1→V2 fictive (notes column)

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async => V1ToV2Notes.apply(m, from, to),
    beforeOpen: (details) async {
      // Applied on every open (not only migrations).
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA busy_timeout = ${kDbBusyTimeoutMs}');
      await customStatement('PRAGMA foreign_keys = ON'); // CRITICAL — default is OFF
    },
  );
}

// Prod wiring (lib/infrastructure/db/app_database_provider.dart)
@riverpod
AppDatabase appDatabase(AppDatabaseRef ref) {
  final supportDir = getApplicationSupportDirectorySync(); // cached
  final dbPath = p.join(supportDir.path, kDbFilename);
  final executor = NativeDatabase.createInBackground(
    File(dbPath),
    setup: (raw) {
      // Fallback: some PRAGMAs prefer to run before the drift MigrationStrategy.beforeOpen
      // to pin journal_mode as early as possible on a fresh file.
      raw.execute('PRAGMA journal_mode = WAL');
    },
  );
  final db = AppDatabase(executor);
  ref.onDispose(() => db.close());
  return db;
}

// Test wiring
setUp(() {
  db = AppDatabase(DatabaseConnection(
    NativeDatabase.memory(setup: (raw) {
      raw.execute('PRAGMA journal_mode = WAL');
      raw.execute('PRAGMA foreign_keys = ON');
    }),
    closeStreamsSynchronously: true,
  ));
});
tearDown(() async => db.close());
```

### Pattern 2: Partial unique index for SESS-06

**What:** SQLite `CREATE UNIQUE INDEX ... WHERE ...` enforces uniqueness over a subset of rows — "at most one session with status='active'" is a textbook use case.
**When to use:** Whenever business rule is "at most one row matching predicate X".
**Source:** [sqlite.org/partialindex.html](https://www.sqlite.org/partialindex.html) (HIGH), [drift `@TableIndex.sql()`](https://drift.simonbinder.eu/dart_api/tables/) (HIGH).

```dart
// lib/infrastructure/db/app_database.dart
@TableIndex.sql('''
  CREATE UNIQUE INDEX idx_t_sessions_status_active
    ON t_sessions(status)
    WHERE status = 'active';
''')
class Sessions extends Table {
  @override String get tableName => 't_sessions';
  TextColumn get id => text()();                      // sess_<ULID>
  TextColumn get displayName => text()();
  TextColumn get status => text()();                  // 'active' | 'stopped'
  IntColumn get startedAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  IntColumn get startedAtOffsetMinutes => integer().check(
    startedAtOffsetMinutes.isBetweenValues(-720, 840),
  )();
  // stoppedAtUtc + offset (nullable) — omitted for brevity
  @override Set<Column> get primaryKey => {id};
}

// Violation handling in DriftSessionStore
Future<void> activate(SessionId id) async {
  try {
    await (db.update(db.sessions)..where((s) => s.id.equals(id.value)))
      .write(const SessionsCompanion(status: Value('active')));
  } on SqliteException catch (e) {
    if (e.extendedResultCode == 2067 /* SQLITE_CONSTRAINT_UNIQUE */) {
      throw ConcurrentActivationException(attemptedId: id);
    }
    rethrow;
  }
}
```

### Pattern 3: Freezed sealed class with UnknownConfig fallback

**What:** Freezed 3.x `sealed class` + multiple factories + `@Freezed(fallback: ...)` enables graceful handling of unknown discriminator values at JSON boundary.
**When to use:** Any polymorphic config where forward-compat matters (user imports a future-version style in today's build).
**Source:** [pub.dev/packages/freezed](https://pub.dev/packages/freezed) changelog Freezed 3.x (HIGH).

```dart
@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')
sealed class MirkStyleConfig with _$MirkStyleConfig {
  const factory MirkStyleConfig.atmospheric({
    required int baseColorArgb,       // Phase 09 fills fields
    required double noiseScale,
  }) = AtmosphericConfig;

  const factory MirkStyleConfig.shader({
    required String shaderAssetPath,
  }) = ShaderConfig;

  const factory MirkStyleConfig.unknown({
    required Map<String, Object?> raw,
  }) = UnknownConfig;

  factory MirkStyleConfig.fromJson(Map<String, Object?> json) =>
    _$MirkStyleConfigFromJson(json);
}

// Exhaustive pattern match at render call site (Phase 09) — compiler enforces all cases
Widget render(MirkStyleConfig cfg) => switch (cfg) {
  AtmosphericConfig(:final baseColorArgb) => AtmosphericRenderer(baseColorArgb),
  ShaderConfig(:final shaderAssetPath)    => ShaderRenderer(shaderAssetPath),
  UnknownConfig()                         => const UnknownRendererPlaceholder(),
};
```

### Pattern 4: Extension-type ID with prefix — type-safe, zero-cost

**What:** Dart 3 `extension type` provides compile-time type safety with runtime erasure (no wrapper object allocated).
**Source:** [dart.dev language features](https://dart.dev/language/extension-types) — standard since Dart 3.3.

```dart
// lib/domain/ids/session_id.dart
extension type const SessionId(String value) {
  static const String prefix = 'sess_';
  bool get isValid => value.startsWith(prefix) && value.length == prefix.length + 26;
}
```

Compile error if caller passes `MarkerId` where `SessionId` expected. Zero heap cost at runtime. `.value` exposes raw String for Drift. ID copied from SQL inspector is instantly identifiable.

### Pattern 5: Schema-step migration test with seeded data

**What:** Drift's `SchemaVerifier` lets you load a v1 schema, seed rows via generated `DatabaseAtV1`, run migration, verify via `DatabaseAtV2`.
**Source:** [drift.simonbinder.eu/migrations/tests/](https://drift.simonbinder.eu/migrations/tests/) (HIGH).

```dart
// test/infrastructure/db/migration_v1_to_v2_test.dart
import 'package:drift_dev/api/migrations_native.dart';
import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;
import '../../generated_migrations/schema_v2.dart' as v2;

void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1→v2: adds notes column + existing session rows preserved', () async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.into(oldDb.tSessions).insert(
      v1.TSessionsCompanion.insert(
        id: 'sess_01HRSESSIONID',
        displayName: 'Paris trip',
        status: 'stopped',
        // ...
      ),
    );
    await oldDb.close();

    final prod = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(prod, 2);
    await prod.close();

    final v2Db = v2.DatabaseAtV2(schema.newConnection());
    final row = await v2Db.select(v2Db.tSessions).getSingle();
    expect(row.id, 'sess_01HRSESSIONID');
    expect(row.notes, isNull); // new column defaults to NULL
    await v2Db.close();
  });
}
```

### Anti-Patterns to Avoid

- **`DateTime` as `DATETIME` text column** — Drift best practice is `IntColumn + UnixMsToDateTimeConverter` (faster ORDER BY, timezone-neutral, 8 bytes).
- **Referring to an enum as `TextColumn`** without a converter — use `IntColumn.map(EnumIndexConverter<SessionStatus>(SessionStatus.values))` or string-literal with explicit CHECK constraint. Here we chose string literal for readability in SQL inspector.
- **Globals + `AppDatabase.instance`** — violates CLAUDE.md §Dependency Injection. Always inject via constructor, expose via Riverpod provider.
- **`flutter_test` for DB tests** — Phase 03 unifies under `dart test` via `NativeDatabase.memory()`. Mixing runners split CI + doubles wall-clock.
- **Wide `Exception` catch** — always catch `SqliteException` specifically, check `extendedResultCode`, wrap in typed domain exception. Rethrow unknowns.
- **`PRAGMA foreign_keys = ON` forgotten** — SQLite defaults to OFF. Omitting this makes the CASCADE declarations no-ops silently. Must be in `beforeOpen`.
- **Updating `bitmap` column without transaction** — a concurrent write between SELECT and UPDATE loses the OR operation. Always wrap read-modify-write in `db.transaction(() async {...})`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UUID/ULID generation | Hand-roll full UUIDv4 with `Random` | ULID in-house 30-line Crockford base32 (accepted user decision) OR package `ulid 3.x` if user changes mind | User chose hand-roll (zero-dep, auditable in 30s). MIT alternatives exist but audit-entry cost outweighs for 30 lines. |
| Schema migration framework | Hand-roll version comparison + ALTER TABLE | Drift `MigrationStrategy.onUpgrade` + `drift_dev schema {dump,generate,steps}` + `SchemaVerifier` | Drift's migration tooling is battle-tested (one of its flagship features). Hand-rolling loses `SchemaMismatch` detection, `migrateAndValidate`, step-by-step helpers. |
| JSON versioned migration chain | Hand-roll per-field rename logic | Envelope `{schemaVersion, type, payload}` + chain-of-functions migrator: `List<JsonMigration>` from v1→v2→v3 applied sequentially (the framework) | This IS the hand-roll — but it's trivial (one function per step, identity for v1). Don't reach for libs like `json_schema_migration`; they're heavyweight. |
| SQLite pragma management | Forget pragmas, discover locks at 10k-tile fixture | `MigrationStrategy.beforeOpen` with 4-pragma checklist (WAL, synchronous=NORMAL, busy_timeout=5000, foreign_keys=ON) | Pragmas applied-once-per-connection is the only reliable contract. Tested by `PRAGMA journal_mode;` → `wal` query in `app_database_pragma_test.dart`. |
| Bitmap bitwise ops | Write custom C FFI for bitset OR | `Uint8List` bytewise OR loop in pure Dart (~6 lines) | 512 bytes × 50k tiles = 25 MB upper bound, bytewise OR in pure Dart is sub-ms. FFI adds build complexity and kills pure-Dart testability. |
| SQLite backup | Re-invent file locking during backup | **VACUUM INTO** for the debug "Backup DB now" button (optional Claude's discretion) + File.copy() for pre-migration | VACUUM INTO is SQLite native, handles live DB, atomic. For pre-migration the DB is closed first → simple File.copy suffices. Online backup API is overkill for this use case. |
| DateTime serialization | `DateTime.parse()` without offset | ISO 8601 with offset (`2026-06-10T08:00:00+02:00`) via Dart's built-in `DateTime.parse` + explicit `timeZoneOffset` reconstruction | Built-in parse respects offsets. Reconstruct `(utc, offsetMinutes)` on import by `DateTime.parse(s).toUtc()` + `parsed.timeZoneOffset.inMinutes`. |

**Key insight:** Drift + its satellite tooling (`drift_dev`, `SchemaVerifier`) covers 90 % of Phase 03's persistence surface. The remaining 10 % is genuinely project-specific (bitmap semantic, ULID hand-roll, JsonMigrator chain, PhotoStore port stub). Keep custom work focused on those four — delegate everything else to Drift's abstractions.

## Common Pitfalls

### Pitfall 1: `PRAGMA foreign_keys = ON` silently omitted

**What goes wrong:** Default SQLite setting is `foreign_keys = OFF`. Declaring `KeyAction.cascade` on a `.references()` column has **zero** runtime effect if this pragma isn't set. Tests pass against in-memory DB if tests don't happen to verify cascade; prod corrupts via orphan rows.
**Why it happens:** Nobody reads pragma docs end-to-end. Drift docs mention it in `beforeOpen` examples but it's easy to miss.
**How to avoid:** Mandatory pragma test: `app_database_pragma_test.dart` asserts `PRAGMA foreign_keys;` returns `1` after `.open()`. Add a cascade test: insert session + marker, delete session, assert marker count == 0. Both must pass.
**Warning signs:** Orphan rows appearing after parent deletes. Integration tests failing after unrelated schema changes.

### Pitfall 2: WAL mode unset on first open, set on subsequent opens

**What goes wrong:** SQLite records the journal mode on disk in `.db-journal`. If the very first open is in DELETE mode (default) and subsequent opens try to `PRAGMA journal_mode = WAL`, the transition succeeds but leaves a `-wal` and `-shm` file. On iOS, backup excludes these by default — DB corruption on restore.
**Why it happens:** `MigrationStrategy.beforeOpen` runs AFTER the first connection is established and after `onCreate`.
**How to avoid:** Use the `setup:` parameter on `NativeDatabase.createInBackground` which runs truly first on the raw sqlite3 handle. Apply `PRAGMA journal_mode = WAL` there; apply the remaining three in `MigrationStrategy.beforeOpen` for consistency per connection.
**Source:** [Drift Platforms/vm docs](https://drift.simonbinder.eu/Platforms/vm/) example explicitly shows `setup: (database) { database.execute('pragma journal_mode = WAL;'); }`.

### Pitfall 3: `NativeDatabase.memory()` missing sqlite3 on Ubuntu CI

**What goes wrong:** `dart test` on ubuntu-latest fails with `Invalid argument(s): Failed to load dynamic library 'libsqlite3.so'`.
**Why it happens:** `sqlite3_flutter_libs` only ships native blob for Flutter builds, not `dart test`. Pure-Dart sqlite3 v2.x+ bundles via code assets but v1.x (which Phase 01 may have pinned transitively) needs system sqlite.
**How to avoid:** Add `sudo apt-get install -y libsqlite3-0 libsqlite3-dev` to CI gates step BEFORE `dart test`. Or alternatively declare direct dev_dependency `sqlite3: 2.x+` pinned (transitive already via `drift` but verify).
**Source:** [pub.dev/packages/sqlite3](https://pub.dev/packages/sqlite3), [drift testing docs](https://drift.simonbinder.eu/testing/).
**Warning signs:** CI green locally (developer has sqlite3 installed) → red in CI on first push.

### Pitfall 4: `SqliteException.extendedResultCode` vs `resultCode`

**What goes wrong:** Catching `SqliteException` and checking `e.resultCode == 19` (SQLITE_CONSTRAINT) catches all constraint violations, not just UNIQUE. The store wraps everything in `ConcurrentActivationException`, hiding FK violations or CHECK failures.
**Why it happens:** The basic `resultCode` is a generic bucket (19). The `extendedResultCode` distinguishes (`2067 = UNIQUE`, `1299 = NOT NULL`, `787 = FOREIGN_KEY`, etc.).
**How to avoid:** Always check `extendedResultCode`. Document the specific code in the catch block. Have a fallback `rethrow` for unknown codes.
**Source:** [SQLite result codes](https://www.sqlite.org/rescode.html) (HIGH), [drift issue threads](https://github.com/simolus3/drift/issues) (HIGH for the Dart side).

### Pitfall 5: Freezed `@Assert` compiled away in release mode

**What goes wrong:** `@Assert('name.isNotEmpty', 'name cannot be empty')` generates an `assert()` statement. Dart strips `assert` in release builds by default. A malformed `Session` built from disk (corrupted row) is constructed silently in prod, crashes later at an unrelated call site.
**Why it happens:** Default Dart release mode is `--enable-asserts=false`.
**How to avoid:** Acknowledge that `@Assert` is a dev/test guard, not a runtime guard. For runtime validation, use the `MirkStyleConfig.fromJson` boundary validator pattern (throw `ImportValidationException` on malformed input explicitly). CLAUDE.md §Error Handling explicitly enumerates this: bugs de programmation (asserts) vs erreurs externes attendues (exceptions).
**Warning signs:** Happy-path tests pass, hand-crafted malformed fixtures don't trigger expected failures under `flutter run --release`.

### Pitfall 6: `drift_dev schema dump` / `generate` output not committed

**What goes wrong:** Developer A changes schema, runs codegen, commits. Developer B pulls, doesn't run codegen, tests pass locally. CI runs codegen, produces different output, test fails.
**Why it happens:** `drift_schemas/` and `test/generated_migrations/` are committed files, not build artifacts. They MUST stay in sync with `app_database.dart`.
**How to avoid:** CI script verifies: `dart run drift_dev schema dump lib/.../app_database.dart drift_schemas/` → `git diff --exit-code drift_schemas/`. Fails if schema drifted.
**Source:** Drift docs explicitly recommend this CI gate. [drift.simonbinder.eu/migrations/exports](https://drift.simonbinder.eu/migrations/exports/).

### Pitfall 7: `VerifyMigration` passes but data was lost

**What goes wrong:** `migrateAndValidate` only validates **structural** schema equivalence (same tables, columns, indices, triggers). It doesn't check that your rows survived.
**Why it happens:** That's by design — it's a schema verifier, not a data verifier.
**How to avoid:** The sanity row-count hook (decision D4) must run **independently** of `migrateAndValidate`: before migration, capture `Map<String, int> rowCounts = {for (t in tables) t.tableName: SELECT COUNT(*)}`. After migration, compare. If any count decreased, throw `MigrationFailureException`. This is what covers success criterion #6 of Phase 03.

### Pitfall 8: `custom_lint` + `riverpod_lint` + analyzer version lock-in

**What goes wrong:** Re-adding `custom_lint` + `riverpod_lint` pulls an analyzer constraint that conflicts with `lints 6.1.0` (transitive via `flutter_lints 6.0.0`). `pub get` fails or downgrades silently.
**Why it happens:** Phase 01 deliberately held analyzer <9 and deferred these packages. The ecosystem has been drifting since.
**How to avoid:** Before pinning, run `dart pub add --dev custom_lint` + `riverpod_lint` in a scratch branch, read `pubspec.lock` for the resolved analyzer version, confirm no downgrades on `flutter_lints` / `lints`. If conflict persists, prefer holding `flutter_lints` and upgrading the Phase 03 lint tooling to whatever version resolves against analyzer <9.
**Warning signs:** `flutter analyze` reports errors on previously-clean files after `pub get`.

### Pitfall 9: Dart `Uint8List` equality via `==`

**What goes wrong:** Freezed generates `==` via field-by-field equality. `Uint8List` doesn't override `==` → uses `Object.==` (reference equality). Tests comparing bitmap bytes fail silently in equality assertions.
**Why it happens:** Dart's standard library doesn't override collection equality.
**How to avoid:** When comparing `Uint8List` in tests, use `expect(actual.bitmap, orderedEquals(expected.bitmap))` or `ListEquality<int>().equals(a, b)`. Consider overriding `==` via custom `base class` or using `@Freezed(equal: false)` + manual `==`. For `RevealedTile` in particular, the bitmap isn't something you typically compare whole-entity anyway; compare via `setBitCount` + explicit bitmap check.

### Pitfall 10: Timezone offset invariants unchecked at DB level

**What goes wrong:** Domain `@Assert` enforces `-720 <= offset <= 840` but that's dev/test-only. A corrupted row with `offset=9999` loads fine in prod, Freezed constructor doesn't re-assert (it's a factory, not a field-receiving constructor in the generated code).
**Why it happens:** Row-to-entity hydration bypasses the factory in most Drift codegen patterns.
**How to avoid:** Add a SQLite-level `CHECK (started_at_offset_minutes BETWEEN -720 AND 840)` constraint on the column itself. Double-guard: `@Assert` at construction + `CHECK` at insert. A corrupted file can't even load with an out-of-range offset.

## Code Examples

Verified patterns from official sources:

### Opening AppDatabase with pragmas (prod + test)

```dart
// Source: drift.simonbinder.eu/Platforms/vm/ + drift.simonbinder.eu/testing/
QueryExecutor openProduction(String dbPath) {
  return NativeDatabase.createInBackground(
    File(dbPath),
    setup: (raw) {
      raw.execute('PRAGMA journal_mode = WAL');
    },
  );
}

QueryExecutor openMemoryForTest() {
  return NativeDatabase.memory(
    setup: (raw) {
      raw.execute('PRAGMA journal_mode = WAL');
      raw.execute('PRAGMA foreign_keys = ON');
    },
  );
}
```

### Partial unique index declaration

```dart
// Source: sqlite.org/partialindex.html + drift.simonbinder.eu (@TableIndex.sql)
@TableIndex.sql('''
  CREATE UNIQUE INDEX idx_t_sessions_status_active
    ON t_sessions(status)
    WHERE status = 'active';
''')
class Sessions extends Table {
  // columns...
}
```

### Bitwise OR bitmap merge (pure Dart)

```dart
// No external source — straightforward Dart; testable offline.
Uint8List mergeBitmap(Uint8List current, Uint8List mask) {
  if (current.length != mask.length) {
    throw ArgumentError.value(mask, 'mask', 'length mismatch with current bitmap');
  }
  final result = Uint8List(current.length);
  for (var i = 0; i < current.length; i++) {
    result[i] = current[i] | mask[i];
  }
  return result;
}

int popcount(Uint8List bytes) {
  var count = 0;
  for (final b in bytes) {
    var v = b;
    v = v - ((v >> 1) & 0x55);
    v = (v & 0x33) + ((v >> 2) & 0x33);
    count += (v + (v >> 4)) & 0x0F;
  }
  return count;
}
```

### JsonMigrator chain

```dart
// Source: adapted from standard versioned-migration pattern
abstract class JsonMigration {
  int get fromVersion;
  Map<String, Object?> apply(Map<String, Object?> payload);
}

class JsonMigrator {
  JsonMigrator(this._migrations);
  final List<JsonMigration> _migrations; // ordered v1→v2, v2→v3, ...

  Map<String, Object?> migrate(int fromVersion, int toVersion, Map<String, Object?> payload) {
    var current = payload;
    var v = fromVersion;
    while (v < toVersion) {
      final step = _migrations.firstWhere(
        (m) => m.fromVersion == v,
        orElse: () => throw MigrationFailureException('No migrator for v$v→v${v + 1}'),
      );
      current = step.apply(current);
      v++;
    }
    return current;
  }
}

// Identity v1 (no-op)
class IdentityMigrationV1 extends JsonMigration {
  @override int get fromVersion => 1;
  @override Map<String, Object?> apply(Map<String, Object?> payload) => payload;
}

// V1→V2 fictive (rename mirk_radius_m → reveal_radius_m)
class V1ToV2RenameRadius extends JsonMigration {
  @override int get fromVersion => 1;
  @override Map<String, Object?> apply(Map<String, Object?> payload) {
    final clone = Map<String, Object?>.from(payload);
    if (clone.containsKey('mirk_radius_m')) {
      clone['reveal_radius_m'] = clone.remove('mirk_radius_m');
    }
    return clone;
  }
}
```

### ULID in-house (Crockford base32)

```dart
// Source: ulid/spec github (reference) — hand-rolled, audited visually.
// ~30 lines, exactly as promised in CONTEXT.md §ULID in-house.
class Ulid {
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // 32 chars, no I/L/O/U

  static String generate({required DateTime now, required Random rng}) {
    final timestampMs = now.millisecondsSinceEpoch;
    final timePart = _encodeTime(timestampMs, 10);      // 10 chars
    final randomBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final randomPart = _encodeRandom(randomBytes, 16);  // 16 chars
    return timePart + randomPart;                        // 26 chars total
  }

  static String _encodeTime(int ms, int length) {
    final buffer = StringBuffer();
    for (var i = length - 1; i >= 0; i--) {
      final shift = i * 5;
      final index = (ms >> shift) & 0x1F;
      buffer.write(_alphabet[index]);
    }
    return buffer.toString();
  }

  static String _encodeRandom(List<int> bytes, int length) {
    // Pack 16 bytes = 128 bits into 16 base32 chars (80 bits of entropy used;
    // remaining 48 bits = spillover, safe since bytes are pure-random).
    final buffer = StringBuffer();
    var bits = 0;
    var value = 0;
    for (final byte in bytes.take(10)) {  // 80 bits of randomness
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        buffer.write(_alphabet[(value >> bits) & 0x1F]);
      }
    }
    if (bits > 0) {
      buffer.write(_alphabet[(value << (5 - bits)) & 0x1F]);
    }
    return buffer.toString().padRight(length, '0').substring(0, length);
  }
}

class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator([Random? rng]) : _rng = rng ?? Random.secure();
  final Random _rng;

  @override
  String newId(String prefix) => '$prefix${Ulid.generate(now: DateTime.now().toUtc(), rng: _rng)}';
}
```

### Pre-migration backup with rotation

```dart
// lib/infrastructure/db/backup.dart
class DbBackupService {
  DbBackupService({required this.dbFilename, required this.backupsDir, required this.maxBackups});
  final String dbFilename;
  final Directory backupsDir;
  final int maxBackups;

  Future<File> takeBackup({required int fromVersion, required int toVersion}) async {
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    final timestampUtc = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backupBasename = 'mirkfall.db.backup-v$fromVersion-to-v$toVersion-$timestampUtc';
    final backupFilename = p.join(backupsDir.path, backupBasename);
    await File(dbFilename).copy(backupFilename);
    await _rotate();
    return File(backupFilename);
  }

  Future<void> _rotate() async {
    final entries = await backupsDir.list().where((e) => e is File).cast<File>().toList();
    entries.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (final file in entries.skip(maxBackups)) {
      await file.delete();
    }
  }
}
```

### Sanity row-count post-migration

```dart
// lib/infrastructure/db/schema_sanity.dart
class SchemaSanityChecker {
  SchemaSanityChecker(this._db);
  final AppDatabase _db;

  Future<Map<String, int>> captureRowCounts() async {
    final tables = ['t_sessions', 't_markers', 't_revealed_tiles',
                    't_marker_categories', 't_mirk_styles', 't_photos'];
    final result = <String, int>{};
    for (final table in tables) {
      final count = await _db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
      result[table] = count.read<int>('c');
    }
    return result;
  }

  void assertNoLoss(Map<String, int> before, Map<String, int> after) {
    for (final entry in before.entries) {
      final afterCount = after[entry.key] ?? 0;
      if (afterCount < entry.value) {
        throw MigrationFailureException(
          'Row count decreased on ${entry.key}: ${entry.value} → $afterCount',
        );
      }
    }
  }
}
```

### tile_math.dart (pure Dart)

```dart
// Source: wiki.openstreetmap.org/wiki/Slippy_map_tilenames
// Pure Dart — no Flutter, no I/O. Testable under `dart test`.
import 'dart:math';

class TilePosition {
  const TilePosition({required this.x, required this.y, required this.zoom});
  final int x;
  final int y;
  final int zoom;
}

class TileMath {
  static const int revealedTileZoom = 14;

  /// Web-Mercator clamp per OSM — poles undefined beyond ±85.0511°.
  static const double _maxLatMercator = 85.05112878;

  static TilePosition latLonToTile({required double lat, required double lon, required int zoom}) {
    final clampedLat = lat.clamp(-_maxLatMercator, _maxLatMercator);
    final n = pow(2.0, zoom).toDouble();
    final latRad = clampedLat * pi / 180.0;
    final x = ((lon + 180.0) / 360.0 * n).floor();
    final y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n).floor();
    return TilePosition(x: x, y: y, zoom: zoom);
  }

  /// Returns the NW corner of a tile.
  static ({double lat, double lon}) tileToLatLon({required int x, required int y, required int zoom}) {
    final n = pow(2.0, zoom).toDouble();
    final lon = x / n * 360.0 - 180.0;
    final latRad = atan(_sinh(pi * (1.0 - 2.0 * y / n)));
    return (lat: latRad * 180.0 / pi, lon: lon);
  }

  static double _sinh(double x) => (exp(x) - exp(-x)) / 2.0;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@freezed class Foo with _$Foo` + private-named factory `_Foo` | `@freezed abstract class Foo with _$Foo` (single type) OR `@freezed sealed class Foo` (union) | Freezed 3.0 (April 2025) | Single-constructor classes MUST declare `abstract`. Union types MUST declare `sealed`. Old syntax rejected. Phase 03 targets 3.2.3 → all models follow new syntax. |
| `runtimeType` as default discriminator key | `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` | Freezed 3.x | Supports custom keys + fallback for unknown values. Directly enables MirkStyleConfig `UnknownConfig` pattern. |
| Manual `sqflite` SQL strings | Drift DSL + `drift_dev` codegen | Drift 2.x stable (2023+) | Type-safe queries, automatic migrations, schema dumps, test helpers. The whole project rests on this. |
| Copying `.db` file OS-level during live DB | `VACUUM INTO 'backup.db'` | SQLite 3.27 (Feb 2019) | Doesn't require exclusive lock, preserves pragmas/indices, generally smaller output. Phase 03 uses File.copy for pre-migration (DB closed) and optionally VACUUM INTO for debug-menu button. |
| `DateTime` stored as ISO 8601 TEXT | INT Unix ms via `UnixMsToDateTimeConverter` | Drift long-standing recommendation | Faster ORDER BY, 8 bytes vs ~25, timezone-neutral. Offset stored separately for timezone preservation. |

**Deprecated/outdated:**
- **Drift 1.x `moor` namespace** — fully migrated to `drift`. No concern since Phase 01 pinned 2.32.1.
- **Freezed 2.x `@Freezed(...)` with regular classes** — 3.x requires `abstract` or `sealed`.
- **`json_serializable` without `explicitToJson: true`** — modern usage prefers explicit for nested classes. Freezed's generated toJson is explicit by default.
- **`isar` / `hive` for versioned DB** — both are valid NoSQL options but harder to evolve schemas with strong migration story. Drift chosen for exactly this reason.

## Open Questions

1. **`custom_lint` + `riverpod_lint` exact versions compatible with current analyzer**
   - What we know: Phase 01 held analyzer <9 deliberately. The `lints` transitive via `flutter_lints 6.0.0` is 6.1.0. `custom_lint 0.8.1` → analyzer ^8.0.0 ; `custom_lint 0.7.5` → analyzer ^6.7.0.
   - What's unclear: At the moment of Phase 03 execution, has `riverpod_lint` published a version paired with `custom_lint 0.8.x` + analyzer ^8.x? This changes every few weeks.
   - Recommendation: **First task of Phase 03** = scratch branch, `dart pub add --dev custom_lint riverpod_lint`, inspect `pubspec.lock`, pin in real pubspec once the trio resolves cleanly. If not resolvable, **hold another phase** — don't force upgrade `flutter_lints`.

2. **Exact shape of V1→V2 Drift fictive migration**
   - What we know: CONTEXT.md says "add nullable `notes TEXT` column on `t_sessions`". SC#1 says V1→V1 identity must also pass a fixture test (implicit before migration framework bootstrapped).
   - What's unclear: Do we really want V1→V1 identity AS a test, or is it simply "V1 boot from scratch works"? The Drift framework doesn't need an identity migration in its chain (`onCreate` handles fresh). V1→V1 "identity" reads in this context as "V1 fixture loads, is re-serialized, identical bytes out".
   - Recommendation: Interpret SC#1 as: "V1 fixture (seed.sql with 10 sessions, 50 markers, 5 tiles) loads cleanly after `m.createAll()`; re-dumping the DB produces schema identical to `drift_schema_v1.json`". Not a formal "V1→V1 migration step". V1→V2 is the first real migration.

3. **`setBitCount` cached column vs trigger vs runtime**
   - What we know: CONTEXT.md marks this as Claude's discretion.
   - What's unclear: Which approach best balances simplicity, test-ability, and future "% world revealed" feature (STAT-*).
   - Recommendation: **Cached column updated in the same transaction as bitmap write**. Simplest. Trigger SQL would fire after commit on the same row → slower. Runtime compute means scanning all 50k tiles every stat refresh. Chosen in code example above.

4. **Does `drift_flutter 0.3.0` support `getApplicationSupportDirectory()` as easily as documents?**
   - What we know: Default `driftDatabase(name:)` uses `getApplicationDocumentsDirectory()`. `DriftNativeOptions.databasePath` allows override.
   - What's unclear: Is there a one-liner override, or do we end up writing our own `NativeDatabase.createInBackground(File(path))` provider?
   - Recommendation: Write the custom provider directly (see Pattern 1 code). `drift_flutter` is convenience; we need control over path_provider choice, pragma order, and `readPool` anyway. One extra file vs fighting the helper.

5. **Freezed `@Freezed(fallbackUnion: 'unknown')` syntax in 3.2.3 exactly**
   - What we know: Feature exists in Freezed 3.x per changelog and gist.
   - What's unclear: Exact annotation form in 3.2.3 (could be `fallback` or `fallbackUnion` depending on minor version).
   - Recommendation: Verify by attempting build_runner at plan time. If neither works, fall back to custom `fromJson` factory that catches `CheckedFromJsonException` on unknown `rendererType` and constructs `UnknownConfig(raw)` manually. Both paths viable.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `package:test` 1.30.0 (already pinned Phase 02 dev_dependency) + Drift test utilities (`NativeDatabase.memory()`, `SchemaVerifier`) |
| Config file | None required — `dart test` picks up `test/**/*_test.dart` by default. Optionally a `dart_test.yaml` can set concurrency, tags (no Wave 0 gap here — picks up existing conventions). |
| Quick run command | `dart test test/domain/tile_math_test.dart -r compact` (single file, seconds) |
| Full suite command | `dart test test/` (entire suite, runs under ~30s given in-memory DB) |

**Ubuntu CI system dependency:** `sudo apt-get install -y libsqlite3-0 libsqlite3-dev` added to `gates` job BEFORE `dart test` step.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SESS-06 | Double-activation fails with DB constraint, not caller assertion | unit | `dart test test/infrastructure/stores/session_store_exclusivity_test.dart` | Wave 0 |
| SESS-06 | Partial unique index `idx_t_sessions_status_active` exists in schema | schema | `dart test test/infrastructure/db/app_database_schema_test.dart` (queries `sqlite_master`) | Wave 0 |
| MIRK-03 | Setting a bit cannot unset it (OR-monotone) | unit | `dart test test/infrastructure/stores/revealed_tile_store_idempotence_test.dart` | Wave 0 |
| MIRK-03 | `Uint8List | Uint8List` merge is idempotent and commutative (pure) | unit | `dart test test/domain/reveal_calculator_test.dart` | Wave 0 |
| SC#1 (WAL + pragmas) | `PRAGMA journal_mode` = `wal`, `synchronous` = 1 (NORMAL), `busy_timeout` = 5000 | integration | `dart test test/infrastructure/db/app_database_pragma_test.dart` | Wave 0 |
| SC#1 (V1→V1 identity fixture) | V1 seed.sql loads, schema dump matches canonical | migration | `dart test test/infrastructure/db/v1_identity_fixture_test.dart` | Wave 0 |
| SC#4 (domain purity) | `lib/domain/` contains zero `import 'package:flutter/...'` and zero `import 'package:drift/...'` | static | Tool script `tool/check_domain_purity.dart` + unit test — or grep-based test under `dart test` | Wave 0 (new tool) |
| SC#5 (`tile_math` + `reveal_calculator` pure + `dart test`) | Tests run under `dart test` with no Flutter in import graph | unit | `dart test test/domain/tile_math_test.dart test/domain/reveal_calculator_test.dart` | Wave 0 |
| SC#5 (`JsonMigrator` identity v1 + slot v2) | v1 payload identity-returns, v2 applies rename | unit | `dart test test/domain/json_migrator_test.dart` | Wave 0 |
| SC#6 (pre-migration backup + row-count hard-fail) | Backup file created before onUpgrade; row-count regression throws `MigrationFailureException` | integration | `dart test test/infrastructure/db/backup_test.dart` + `test/infrastructure/db/schema_sanity_test.dart` | Wave 0 |
| ULID spec compliance | 26 chars, Crockford base32 alphabet, timestamp monotonic, k-sortable | unit | `dart test test/infrastructure/ids/ulid_test.dart` | Wave 0 |
| Seeded IdGenerator | Reproducible IDs given fixed seed | unit | `dart test test/infrastructure/ids/seeded_id_generator_test.dart` | Wave 0 |
| Cascade delete (sessions) | Delete session → markers + revealed_tiles gone | integration | `dart test test/infrastructure/stores/drift_session_store_cascade_test.dart` | Wave 0 |
| Non-cascade delete (category) | Delete category → markers reassigned to `cat_default`, no orphan | integration | `dart test test/infrastructure/stores/marker_category_store_cascade_test.dart` | Wave 0 |
| MirkStyleConfig UnknownConfig fallback | Unknown rendererType JSON → `UnknownConfig(raw)` | unit | `dart test test/domain/mirk_style_config_fromjson_test.dart` | Wave 0 |
| `@Assert` invariants | Empty displayName → `AssertionError` at construct | unit | `dart test test/domain/session_invariants_test.dart` | Wave 0 |
| DateTime offset stored + exported | UTC + offset round-trip survive; ISO 8601 export with `+HH:MM` | unit | `dart test test/domain/session_timezone_test.dart` | Wave 0 |
| V1→V2 migration (notes column) | Existing rows preserved, new column NULL default, writeable after migration | migration | `dart test test/infrastructure/db/migration_v1_to_v2_test.dart` (via SchemaVerifier) | Wave 0 |
| JsonMigrator V1→V2 (rename radius) | `mirk_radius_m` → `reveal_radius_m` | unit | `dart test test/domain/json_migrator_v1_to_v2_test.dart` | Wave 0 |

### Sampling Rate

- **Per task commit:** `dart test test/<lens>` (domain-only, infra-only, or migration-only depending on task focus — sub-30s)
- **Per wave merge:** `dart test test/` full suite (~30-60s locally)
- **Phase gate:** Full suite green in CI (ubuntu-latest, gates job) before `/gsd:verify-work`

### Wave 0 Gaps

All test files listed in the Requirements→Test Map are **new** — the project has no Phase 03 tests yet. Wave 0 of the plan MUST include:

- [ ] `test/fixtures/drift_schemas/drift_schema_v1.json` — produced by `dart run drift_dev schema dump`, committed
- [ ] `test/fixtures/drift_schemas/drift_schema_v2.json` — idem after V1→V2 fictive is added
- [ ] `test/generated_migrations/` directory — produced by `dart run drift_dev schema generate ... --data-classes --companions`, committed
- [ ] `test/fixtures/db_seed/v1_baseline.sql` — hand-written INSERT statements (10 sessions, 50 markers, 5 tiles, 3 categories, 2 styles) for the V1 identity test
- [ ] `test/fixtures/json/session_v1.json` — sample session envelope for JsonMigrator
- [ ] `test/fixtures/json/mirk_style_unknown_renderer.json` — malformed-rendererType sample for UnknownConfig
- [ ] `tool/check_domain_purity.dart` — grep-based script, unit-tested in `tool/test/`
- [ ] `dart_test.yaml` (optional) — tag "migration" for slower tests; NOT strictly required
- [ ] CI `gates` step addition: `sudo apt-get install -y libsqlite3-0 libsqlite3-dev` BEFORE `dart test`
- [ ] CI `gates` step addition: `dart run drift_dev schema dump lib/.../app_database.dart drift_schemas/ && git diff --exit-code drift_schemas/` — guard against forgotten regen
- [ ] Framework install: `sudo apt-get install -y libsqlite3-0 libsqlite3-dev` on Ubuntu CI (above)
- [ ] Dev-dep additions: `custom_lint` + `riverpod_lint` at compatible versions (see Open Question #1)

**Coverage Matrix — SESS-06 and MIRK-03 (required by output spec):**

| Requirement | Layer tested | Test type | Test command | Covers angle |
|-------------|--------------|-----------|--------------|-------------|
| **SESS-06** | Domain (invariants) | unit | `dart test test/domain/session_invariants_test.dart` | Dart-level `@Assert` for obvious caller misuse |
| **SESS-06** | DB schema shape | schema | `dart test test/infrastructure/db/app_database_schema_test.dart` | Partial unique index exists + is on `status`, with `WHERE status='active'` |
| **SESS-06** | DB enforcement at runtime | integration | `dart test test/infrastructure/stores/session_store_exclusivity_test.dart` | Two concurrent activation paths → one wins, the other gets `ConcurrentActivationException` (wrapped from `SqliteException 2067`) |
| **SESS-06** | Store error mapping | unit | `dart test test/infrastructure/stores/session_store_error_mapping_test.dart` | `SqliteException 2067` → `ConcurrentActivationException` + other codes rethrow |
| **MIRK-03** | Pure bitmap algebra | unit | `dart test test/domain/reveal_calculator_test.dart` | `a | b ≥ a` bitwise; `(a | b) | a == a | b`; idempotence |
| **MIRK-03** | Store idempotence | integration | `dart test test/infrastructure/stores/revealed_tile_store_idempotence_test.dart` | Apply same mask twice → row unchanged; apply additive mask → bits OR-merged; no existing bit ever turns off |
| **MIRK-03** | Concurrent writes | integration | `dart test test/infrastructure/stores/revealed_tile_store_concurrent_test.dart` | Two write paths via Future.wait → final bitmap is OR of both masks; `setBitCount` matches popcount |
| **MIRK-03** | Schema contract | schema | `dart test test/infrastructure/db/app_database_schema_test.dart` | `t_revealed_tiles` has `bitmap BLOB NOT NULL` + unique (session_id, parent_x, parent_y, parent_zoom) |

## Sources

### Primary (HIGH confidence)

- [Drift official docs — Getting Started / Migrations / Testing / Platforms](https://drift.simonbinder.eu/) — WAL setup, SchemaVerifier, NativeDatabase.memory, MigrationStrategy, beforeOpen vs setup parameter, partial index via `@TableIndex.sql`, TypeConverter patterns
- [Drift pub.dev package page](https://pub.dev/packages/drift) — version 2.32.1, MIT, platform support
- [Drift test migrations docs](https://drift.simonbinder.eu/migrations/tests/) — `drift_dev schema dump/generate/steps` flow, SchemaVerifier.migrateAndValidate, data seeding
- [Drift migrations exports](https://drift.simonbinder.eu/migrations/exports/) — how to commit schema JSONs, CI verification
- [Drift Platforms/vm](https://drift.simonbinder.eu/Platforms/vm/) — NativeDatabase.createInBackground with `setup:` callback for pragmas
- [SQLite Partial Indexes](https://www.sqlite.org/partialindex.html) — exact syntax + semantics of `CREATE UNIQUE INDEX ... WHERE`
- [SQLite Result Codes](https://www.sqlite.org/rescode.html) — SQLITE_CONSTRAINT_UNIQUE = 2067
- [SQLite Online Backup API](https://sqlite.org/backup.html) — for reference; not used (File.copy suffices for pre-migration)
- [SQLite INSERT OR IGNORE / conflict resolution](https://www.sqlite.org/lang_insert.html) — idempotence semantics
- [SQLite Pragmas](https://sqlite.org/pragma.html) — journal_mode, synchronous, busy_timeout, foreign_keys
- [OSM Slippy Map Tilenames](https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames) — authoritative lat/lon ↔ tile x/y formulas, Web Mercator latitude clamp
- [Freezed pub.dev](https://pub.dev/packages/freezed) — 3.x sealed class + abstract requirement, @Assert decorator, fromJson unionKey
- [ULID spec](https://github.com/ulid/spec) — 26-char format, Crockford base32 alphabet (no I/L/O/U), k-sortability contract
- [Phase 03 CONTEXT.md](.planning/phases/03-persistence-domain-models/03-CONTEXT.md) — user decisions
- [MirkFall CLAUDE.md](CLAUDE.md) — naming, error handling, logging, pinned versions, DI, test runner policy
- [Phase 03 ROADMAP.md entry](.planning/ROADMAP.md) — 6 success criteria verbatim
- [Project STATE.md](.planning/STATE.md) — accumulated decisions, Phase 01/02 history

### Secondary (MEDIUM confidence — web search cross-verified with official docs)

- [Drift changelog on pub.dev](https://pub.dev/packages/drift/changelog) — recent 2.32.x notes
- [Drift issue #3031 "database is locked error with WAL journal mode"](https://github.com/simolus3/drift/issues/3031) — confirms WAL + busy_timeout combo is the canonical escape, consistent with docs
- [bertub.eu "What to do about SQLITE_BUSY errors despite setting a timeout"](https://berthub.eu/articles/posts/a-brief-post-on-sqlite3-database-locked-despite-timeout/) — corroborates busy_timeout semantics
- [Freezed v3 migration gist](https://gist.github.com/bear2u/c6023bdfe40ab028cddba59b09a1f155) — 2.x→3.x breaking changes summary (abstract/sealed)
- [InvertAse "Assertions in Dart and Flutter tests"](https://invertase.io/blog/assertions-in-dart-and-flutter-tests-an-ultimate-cheat-sheet) — `throwsAssertionError` matcher, release-mode strip caveat
- [sqlite3.dart pub.dev](https://pub.dev/packages/sqlite3) — 2.x bundles via code assets, 1.x needs system libsqlite3

### Tertiary (LOW confidence — flagged for confirmation at plan time)

- **Exact compatible versions for `custom_lint` + `riverpod_lint` + analyzer as of 2026-04** — WebSearch results were dated and contradictory. Must be re-verified by `pub get` in scratch branch (see Open Question #1).
- **Freezed 3.2.3 exact annotation key for fallback union** — `fallback` vs `fallbackUnion` — must be verified by running codegen (see Open Question #5).
- **`drift_flutter` 0.3.0 ability to seamlessly swap to `getApplicationSupportDirectory()`** — docs mention `DriftNativeOptions.databasePath` but no complete example; simpler to write own provider.

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — all core libs pinned Phase 01, versions verified via pub.dev and official docs. Dev deps (`custom_lint` + `riverpod_lint`) are MEDIUM because ecosystem is still converging.
- **Architecture patterns:** HIGH — Drift + SQLite patterns are authoritative (official docs), bitmap storage approach aligned with user decisions and verified via SQLite semantics.
- **SESS-06 enforcement strategy:** HIGH — partial unique index is the SQLite textbook pattern, drift supports it via `@TableIndex.sql`, extended result code 2067 is documented.
- **MIRK-03 monotonicity strategy:** HIGH — bitwise OR idempotence is algebraically provable, Uint8List is stock Dart, no hidden runtime dependencies.
- **Migration framework strategy:** HIGH — Drift's `SchemaVerifier` + `schema dump/generate/steps` is official and mature; V1→V2 fictive is a minor `ALTER TABLE ADD COLUMN` well within the framework's comfort zone.
- **Pitfalls:** HIGH — all 10 pitfalls documented have official docs or Drift issue thread backing.
- **Validation architecture:** HIGH — test strategy directly maps success criteria to test files, matches test-runner decision (all `dart test`), no Flutter-test surface.

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — stable domain, low rate of change for Drift/SQLite/Freezed at this point).

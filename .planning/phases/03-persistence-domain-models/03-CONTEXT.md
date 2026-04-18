# Phase 03: Persistence & Domain Models - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Figer les deux décisions architecturales les plus coûteuses à changer rétroactivement avant qu'une seule ligne de GPS ou d'export ne les consomme :

1. **Modèle de stockage du mirk révélé** — parent tile zoom-14 + bitmap 64×64 par parent (décision D3, verrouillée en research).
2. **Format d'échange JSON versionné** — envelope `{schemaVersion, type, payload}` (décision D9, verrouillée en research).

**Livrables Phase 03 (pure data + pure utilities, aucune UI, aucun GPS) :**
- Schéma Drift complet (`t_sessions`, `t_markers`, `t_revealed_tiles`, `t_marker_categories`, `t_mirk_styles`, `t_photos`) en WAL + partial unique index d'exclusivité session + FK CASCADE.
- Modèles Freezed : `Session`, `Marker`, `MarkerCategory`, `MirkStyle` (avec sealed `MirkStyleConfig`), `RevealedTile`, `PhotoRef`, `Envelope`.
- Stores ports + implémentations Drift : `SessionStateStore`, `MarkerStore`, `RevealedTileStore`, `MarkerCategoryStore`, `MirkStyleStore`, `PhotoStore` (port seul, pas de photos sur disque en Phase 03).
- Utilités pures : `tile_math.dart`, `reveal_calculator.dart`.
- Framework `JsonMigrator` avec chaîne identity v1 + **V1→V2 fictive livrée** (preuve framework).
- Migration Drift **V1→V2 fictive livrée** (ajout colonne `notes TEXT` nullable sur `t_sessions` + test preservation).
- Backup DB pré-migration + sanity row-count post-migration.
- Tests sous `dart test` via `NativeDatabase.memory()`.
- Re-adoption `custom_lint` + `riverpod_lint` (deferred de Phase 01).

**Hors scope (autres phases) :**
- `ActiveSessionController` + lifecycle tracking → Phase 05.
- Rendu fog + `MirkRenderer` interface + styles visuels → Phase 09.
- UI marker CRUD + pipeline photos (capture, EXIF strip, downscale, storage filesystem) → Phase 11.
- `ImportExportController` + ZIP archive + `SCHEMA.md` + prévisualisation import → Phase 13.
- Écran options global (rayon, sélecteur style, gestionnaire catégories) → Phase 13.
- `tool/check_licenses.dart` amélioration MPL heuristic → fix Phase 02 review-gate backlog.

</domain>

<decisions>
## Implementation Decisions

### Stockage DB + backup

- **Fichier DB** : `<app_support>/mirkfall.db` via `getApplicationSupportDirectory()` — invisible utilisateur, jamais iCloud-backupé, séparation propre Documents (exports partageables) vs AppSupport (base interne).
- **Dossier backups** : `<app_support>/db_backups/` — même racine que la DB (copy atomique garantie, même partition, invisible utilisateur).
- **Rétention backups** : **3 derniers, rolling** — nommés `mirkfall.db.backup-v{N}-to-v{M}-<timestamp>`. Protège contre un bug sémantique post-migration (row-count OK mais corruption logique).
- **Timing backups** : **pré-migration automatique** (via `MigrationStrategy.beforeOpen` avant `onUpgrade`) + **bouton "Backup DB now"** dans le debug menu `/debug` pour snapshots manuels pendant développement.
- **WAL mode** : `PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA busy_timeout = 5000;` appliqué en `MigrationStrategy.beforeOpen`. Documenté dans `lib/infrastructure/db/app_database.dart`.

### Schéma d'ID

- **Format** : **ULID in-house** (zero dep). ~30-40 lignes dans `lib/infrastructure/ids/ulid.dart` (encoder base32 Crockford + generator) + ~30 lignes tests. 48 bits timestamp ms + 80 bits random, 26 chars. K-sortable → `ORDER BY id` = ordre de création sans index dédié sur `createdAt`.
- **Wrapper domaine** : `extension type SessionId(String value)` (Dart 3). Zero-cost runtime, type-safe compile-time (impossible de passer un `MarkerId` où un `SessionId` est attendu). `.value` quand il faut le String brut côté Drift.
- **Seam génération** : interface `IdGenerator` dans `lib/domain/ids/` + implémentations `RandomIdGenerator` (prod, `Random.secure()`) et `SeededIdGenerator` (tests, seed fixe). Injection via provider Riverpod `idGeneratorProvider`. Tests déterministes gratuits.
- **Préfixe typé** : `sess_`, `mrk_`, `cat_`, `mst_`, `phr_`, `rvt_` pour les 6 ID types. **Préfixe stocké dans la valeur wrappée** (ex: `SessionId('sess_01HR3K5M8T0FKTVW9QWZPH7SRB')`). DB stocke avec, JSON exporte avec, copy-paste identifiable partout. Coût ~5 chars/row négligeable.

### Framework migration (Drift + JsonMigrator)

- **Drift V1→V2 fictive livrée en Phase 03** : V2 = V1 + colonne `notes TEXT NULLABLE` sur `t_sessions`. `MigrationStrategy.onUpgrade` implémenté + test intégré (crée session en V1, run migration, relit en V2, vérifie `notes IS NULL` par défaut + écriture possible).
- **JsonMigrator V1→V2 fictive livrée en Phase 03** : migration symbolique (ex: rename `mirk_radius_m` → `reveal_radius_m` dans le payload session). Fixture v1 + v2 attendue commitées dans `test/fixtures/json/`.
- **Test strategy hybride** :
  - **Schema canonique** via `dart run drift_dev schema dump` — produit `drift_schemas/drift_schema_v1.json` + `_v2.json`, commités. Les tests utilisent `VerifyMigration` pour valider `onUpgrade`.
  - **Data de test** via fichiers `.sql` hand-written d'`INSERT` (ou Dart helpers selon préférence implémentateur) — lisibles, un LLM peut les écrire, évite la duplication du schema.
- **Pre-migration backup** : exécuté avant chaque `onUpgrade`, fichier survit jusqu'à sanity check row-count OK post-migration, puis rotation (3 rolling).
- **Sanity row-count** : après `onUpgrade`, comparer `COUNT(*)` par table entre backup et nouvelle DB. Échec hard (throw) si row-count a diminué — ne jamais perdre une row silencieusement.

### Shape config MirkStyle

- **Sealed class `MirkStyleConfig` + `UnknownConfig` catch-all** :
  ```dart
  @freezed sealed class MirkStyleConfig with _$MirkStyleConfig {
    const factory MirkStyleConfig.atmospheric({...}) = AtmosphericConfig;
    const factory MirkStyleConfig.shader({...}) = ShaderConfig;
    const factory MirkStyleConfig.unknown(Map<String, Object?> raw) = UnknownConfig;
  }
  ```
  Exhaustivité pattern match sur les renderers connus + dégradé gracieux sur les inconnus.
- **Validation au boundary** : `MirkStyleConfig.fromJson` effectue la dispatch selon `rendererType`. Si `rendererType` inconnu → construit `UnknownConfig(raw)`. Les renderers ne reçoivent que des configs validés pour leur type.
- **Import d'un `rendererType` inconnu** : style persisté en DB sous forme `UnknownConfig`. Dans l'écran options (Phase 13), il apparaît grisé avec note « renderer inconnu de cette version ». Activation impossible, données survivent un futur upgrade.
- **Storage Drift** : `TextColumn get config => text().map(MirkStyleConfigJsonConverter())();`. JSON lisible dans SQL inspector. Le TypeConverter encapsule `jsonEncode`/`jsonDecode` + dispatch vers la factory Freezed.

### Politique cascade DELETE

- **`t_sessions.delete(id)`** : FK `ON DELETE CASCADE` sur `t_markers.session_id`, `t_revealed_tiles.session_id`, `t_photos.marker_id` (via cascade transitive through `t_markers`). Atomique côté SQLite, un seul appel DB.
- **`t_marker_categories.delete(id)`** : **PAS de CASCADE**. Au lieu de ça, `MarkerCategoryStore.delete` effectue dans une transaction : `UPDATE t_markers SET category_id = 'cat_default' WHERE category_id = ?; DELETE FROM t_marker_categories WHERE id = ?;`. Aucun marker orphelin, aucune perte de data. Catégorie `cat_default` seed en Phase 11 mais son ID est réservé dans les constantes Phase 03 (`lib/domain/markers/default_ids.dart`).
- **Hard-delete uniquement** : pas de flag `deletedAt`. Pas de corbeille / undo (pas demandé V1.0, dette technique inutile).
- **Table `t_photos` déclarée en Phase 03** : `PhotoRef` est déjà dans les modèles Phase 03 (SC#4). Table schema + FK CASCADE vers `t_markers` livrée ici. Phase 11 remplira avec le pipeline file-système, pas besoin de migration V2 juste pour créer la table.

### DateTime + timezone strategy

- **Stockage domaine** : **UTC + offset original préservé**. Deux champs par timestamp logique :
  - `startedAtUtc: DateTime` (toujours `DateTime.toUtc()`)
  - `startedAtOffsetMinutes: int` (ex: `+120` pour CEST, `-480` pour PST)
  - Idem pour `createdAtUtc` / `createdAtOffsetMinutes` sur toutes les entités avec timestamp.
- **Drift column types** :
  - Timestamp UTC : `IntColumn get startedAtUtc => integer().map(const UnixMsToDateTimeConverter())();` — INT unix ms, 8 bytes, ordre SQL trivial.
  - Offset : `IntColumn get startedAtOffsetMinutes => integer()();` — int brut, validation `CHECK (offset BETWEEN -720 AND 840)` en SQL.
- **JSON export format** : **ISO 8601 avec offset explicite**. Un seul champ par timestamp logique :
  - `"startedAt": "2026-06-10T08:00:00+02:00"` — self-describing, lisible humain, parsable tous langages. PORT-02 satisfait.
  - Parsing à l'import reconstruit les deux fields `startedAtUtc` + `startedAtOffsetMinutes`.
- **Validation import** : timestamp malformé (offset absent, offset invalide, format non-ISO) → **import annulé** avec message clair (ex: `"session 3: champ startedAt invalide: attendu ISO 8601 avec offset explicite"`). Aligné PORT-09 tout-ou-rien.

### Stratégie erreurs domain

- **Style d'erreurs** : **exceptions typées** (pas de `Result<T, E>`). Classes dans `lib/domain/errors/` :
  - `SessionNotFoundException`, `InvalidSessionTransition`, `ConcurrentActivationException`, `MarkerNotFoundException`, `CategoryInUseException` (guard avant reassign), `MirkStyleConfigException`, `ImportValidationException`, `MigrationFailureException`.
  - Toutes `implements Exception` (pas `Error` — Error = programming bug non-recoverable).
  - Application layer catch + wrap en `AsyncValue.error` pour Riverpod.
- **Invariants domain** : **assertions dans constructor Freezed**. Exemple :
  ```dart
  @freezed class Session with _$Session {
    @Assert('displayName.trim().isNotEmpty', 'Session.displayName must be non-empty')
    @Assert('startedAtOffsetMinutes >= -720 && startedAtOffsetMinutes <= 840', 'timezone offset out of range')
    const factory Session({...}) = _Session;
  }
  ```
  Échec = `AssertionError` propagé au top-level handler (bug programmation). Activé en dev + tests ; silencieux en release (sauf `--enable-asserts` pour debug).
- **find vs require** : deux méthodes distinctes sur tout store :
  - `Future<Session?> findById(SessionId id)` — null = absent (cas normal).
  - `Future<Session> requireById(SessionId id)` — throw `SessionNotFoundException` si absent.
  - Call site choisit son niveau de strictness. Pas de `!` implicite.
- **Violations DB (unique index, FK constraint)** : catch dans le store, wrap en exception domain. Drift lève `SqliteException(extendedCode: SQLITE_CONSTRAINT_UNIQUE)` → store catch + throw `ConcurrentActivationException` (ou équivalent). Pas de fuite Drift dans les couches supérieures (respect domain purity CLAUDE.md).

### Test runner split + fixtures

- **Tout sous `dart test`** : pure utils (`TileMath`, `RevealCalculator`, `JsonMigrator`) + stores Drift (via `NativeDatabase.memory()`) + migrations tests. Zero Flutter dep. CI : un seul job Ubuntu, ~10× plus rapide que `flutter test`.
- **`AppDatabase(QueryExecutor executor)` injectable** :
  ```dart
  class AppDatabase extends _$AppDatabase {
    AppDatabase(QueryExecutor executor) : super(executor);
  }
  ```
  - Wiring prod (dans `lib/infrastructure/db/app_database_provider.dart`) : `AppDatabase(driftDatabase(name: 'mirkfall', ...))` après avoir configuré le path_provider pour `<app_support>/mirkfall.db`.
  - Wiring test : `AppDatabase(NativeDatabase.memory())` — DB éphémère par test, zero pollution inter-tests.
- **Fixtures** : `test/fixtures/` partagé (plat). Sous-structure :
  - `test/fixtures/drift_schemas/` — schema dumps drift_dev (`drift_schema_v1.json`, `drift_schema_v2.json`).
  - `test/fixtures/json/` — samples JSON versionnés (`session_v1.json`, `session_v2.json`, `markers_only_v1.json`, etc.).
  - `test/fixtures/db_seed/` — scripts `.sql` d'INSERT pour peupler `NativeDatabase.memory()` dans les tests.
  Tout commité, reproductibilité intégrale.
- **CI** : tests ajoutés au job `gates` existant (`dart test` après les checks licence/headers/deps). Un seul runner Ubuntu. Pas de nouveau job.

### Nommage tables, colonnes, indices

- **Tables au pluriel, préfixe `t_`** : `t_sessions`, `t_markers`, `t_revealed_tiles`, `t_marker_categories`, `t_mirk_styles`, `t_photos`.
- **Mapping Dart ↔ SQL** :
  ```dart
  @DataClassName('Session')
  class Sessions extends Table {
    @override String get tableName => 't_sessions';
    TextColumn get id => text()();
    TextColumn get displayName => text()();
    // ...
  }
  ```
  Classe Dart reste PascalCase idiomatique, override explicite du `tableName`.
- **Colonnes** : snake_case (défaut Drift, `displayName` → `display_name`). Pas d'override nécessaire.
- **Indices** : **`idx_t_<table>_<column>[_<qualifier>]`**. Exemples :
  - `idx_t_sessions_status_active` — partial unique sur status='active' (D13 SC#2).
  - `idx_t_markers_session_id` — index sur FK.
  - `idx_t_revealed_tiles_session_id_parent_key` — composite pour lookup par session + parent tile.
- **Foreign keys (colonnes)** : `<table_référencée_singulier>_id`. Exemples : `t_markers.session_id`, `t_markers.category_id`, `t_revealed_tiles.session_id`, `t_photos.marker_id`.

### Entités vs DTOs

- **Pas de DTO 1:1** : `Session`, `Marker`, `MarkerCategory`, `MirkStyle` sont **les** entités domain ET les modèles d'export JSON. Une seule source de vérité Freezed. Drift reçoit des TypeConverter pour sérialiser depuis/vers la DB.
- **DTOs justifiés** (sémantique distincte, documentés par docstring) :
  - `SessionBundleExport` — agrégat de plusieurs sessions + archive photos partagée (aggregation semantic).
  - `MarkersOnlyImport` — markers sans session attachée (shape sessionless, pour pré-import voyage).
  - `RevealedTileExport` — bitmap encodé base64 (représentation de transport JSON, distincte de `Uint8List` runtime).

### Lint ecosystem

- **`custom_lint` + `riverpod_lint` ajoutés en Phase 03** — deferred de Phase 01 explicitement noté dans le `pubspec.yaml`. Phase 03 introduit les premiers `@riverpod` providers (pour `idGeneratorProvider` + `appDatabaseProvider`), donc les lints deviennent productifs. Re-pinner les versions compatibles avec le reste du stack analyzer existant.

### Claude's Discretion

- Valeur exacte de `busy_timeout` (5000 ms par D4, à confirmer via test charge).
- Placement exact des files `lib/infrastructure/ids/ulid.dart` vs `lib/domain/ids/id_generator.dart` (interface dans domain, impl dans infrastructure).
- Choix exact des champs Freezed des `AtmosphericConfig` / `ShaderConfig` V1.0 (Phase 09 décidera les paramètres visuels ; Phase 03 peut sealed class + 1 champ placeholder, Phase 09 étendra).
- Nommage exact des colonnes `display_name` vs `name` selon entité (à arbitrer lors du plan, priorité à la lisibilité dans les requêtes SQL).
- Format exact du fichier `backup-v{N}-to-v{M}-<timestamp>` (timestamp ISO vs unix ms vs compact).
- Implementation exacte du bouton "Backup DB now" du debug menu (copier vs `VACUUM INTO`).
- Liste exacte des default categories IDs réservés (`cat_default` certain ; `cat_house`, `cat_treasure`, etc. décidés en Phase 11 mais si on a envie de pré-réserver les slots ID ici c'est OK).
- Stratégie pour la compute de `setBitCount` (colonne cached vs trigger SQL vs compute runtime).

</decisions>

<specifics>
## Specific Ideas

- **ULID in-house plutôt que package externe** : dans une app sous GOSL avec audit obligatoire de chaque dep, 30 lignes de code auditables d'un coup d'œil valent mieux qu'une entrée de plus dans `DEPENDENCIES.md`. Même argument s'applique à UUIDv4 — si on devait changer d'avis, c'est 15 lignes. Philosophie confirmée par l'utilisateur.
- **K-sortabilité ULID** : gain concret = `ORDER BY id` = ordre de création. Pour les listes de sessions / markers de l'utilisateur, pas besoin d'index dédié sur `createdAt`. Gain cohérent avec la volonté de minimiser les indices.
- **Préfixe typé stocké dans la valeur (pas juste à la sérialisation)** : un ID copié-collé en debug / support reste immédiatement identifiable. Vaut le coût de 5 chars/row.
- **`idx_t_<table>_<column>`** : la convention inclut le `t_` littéralement, pas de règle spéciale. Mécanique, mémoire facile.
- **V1→V2 fictive livrée en Phase 03, pas Phase 04** : si le framework a un trou d'API, on le découvre en l'utilisant. Phase 04 review-gate devient un audit d'évidence existante au lieu d'un travail d'écriture — bénéfice net sur le risque.
- **Hybride drift_dev schema dump + `.sql` INSERT data** : le schema vient de Drift (source de vérité), les données de test restent lisibles humainement. Évite le piège classique « fixture SQL qui drifte silencieusement du schema prod ».
- **UTC + offset préservé plutôt que UTC-only** : MirkFall est un journal de voyage. Savoir que « j'ai démarré à 8h du matin heure de Paris » est une info qu'on veut garder quand l'utilisateur rouvre son export à Tokyo. Coût : 1 colonne INT supplémentaire par timestamp logique.
- **AppSupport plutôt que Documents pour la DB** : philosophie local-first strict = on n'expose pas la DB à iCloud, on ne la met pas dans Files.app. L'export JSON est le canal officiel de portabilité, pas une copie iCloud sneaky.
- **DTOs uniquement si sémantique distincte** : principe explicite partagé avec l'utilisateur + CLAUDE.md §DTO. Si un DTO ressemble à 1:1 d'une entité, c'est un doublon — utiliser l'entité directement.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phase 01)

- **`pubspec.yaml` pré-pinné** : `drift 2.32.1`, `drift_flutter 0.3.0`, `sqlite3_flutter_libs 0.6.0+eol`, `freezed_annotation 3.1.0`, `json_annotation 4.9.0`, `collection 1.19.1`, `path 1.9.1`, `path_provider 2.1.5`, `flutter_riverpod 3.1.0`, `riverpod_annotation 4.0.0`, `build_runner 2.9.0`, `freezed 3.2.3`, `json_serializable 6.11.2`, `riverpod_generator 4.0.0+1` — toutes les deps pour Phase 03 sont déjà auditées et pinnées.
- **`lib/config/constants.dart`** : déjà créé avec `kAppName`, `kBundleId`, slot documenté pour `kDefaultRevealRadiusMeters` (Phase 09) et `kHttpTimeout` (Phase 07). Phase 03 ajoutera : `kDbFilename = 'mirkfall.db'`, `kDbBackupDirName = 'db_backups'`, `kMaxDbBackups = 3`, `kDbBusyTimeoutMs = 5000`.
- **Layer `lib/domain/` + README** : règle « pas d'import flutter/drift » déjà posée. Phase 03 respecte (entités Freezed pures + interfaces stores).
- **Layer `lib/infrastructure/` + README** : déjà présent, `lib/infrastructure/logging/file_logger.dart` en exemple. Phase 03 ajoute `lib/infrastructure/db/`, `lib/infrastructure/ids/`, `lib/infrastructure/stores/`.
- **Layer `lib/application/` + README** : prêt à recevoir les providers Riverpod (mais Phase 03 ne livre que `idGeneratorProvider` + `appDatabaseProvider`, le reste vient avec les controllers des phases suivantes).
- **`runZonedGuarded` + `FlutterError.onError`** (lib/main.dart) : déjà armés pour catch les `AssertionError` et les `MigrationFailureException` non catchées et les logger via `FileLogger` niveau SHOUT.
- **`FileLogger`** : consommable directement par les stores Phase 03 pour logger les opérations (ex: `Logger('infrastructure.db').info('migration v1→v2 OK, 42 rows preserved')`).
- **`.github/workflows/ci.yml` job `gates`** : Phase 03 y ajoute `dart test` en fin de step, pas de nouveau job.

### Established Patterns

- **CLAUDE.md règles strictes** appliquées Phase 01, à continuer Phase 03 :
  - Naming `xxxFilename` (absolu), `xxxFileName` (sans ext), `xxxBasename` (avec ext), `xxxDir`.
  - `p.join()` toujours, jamais de `/` ou `\` manuel.
  - Pas de magic number hors `constants.dart`.
  - Pas d'`is`-chain → sealed class + pattern match (exactement le cas `MirkStyleConfig` + `SessionStatus`).
  - Pas de singleton global caché → injection constructor + Riverpod.
  - Type hints stricts, pas de `dynamic`, `Object?` si vraiment inconnu.
- **Exit codes CI 0/1/2** (gate scripts) : Phase 03 tests échouent avec exit code ≠ 0 standard, `dart test` gère nativement.
- **Commits atomiques** : `feat(03-XX):`, `test(03-XX):`, `refactor(03-XX):` selon nature, un per task.
- **Layer READMEs comme contrat** : si Phase 03 introduit un sous-dossier (`lib/domain/ids/`, `lib/infrastructure/db/`), y ajouter un README court qui rappelle ce qui est autorisé / interdit.

### Integration Points

- **`pubspec.yaml`** : ajout `custom_lint` + `riverpod_lint` (versions compatibles à re-pinner, NOTE actuelle en commentaire) en dev_dependencies.
- **`analysis_options.yaml`** : activer `custom_lint` une fois la dep ajoutée (`analyzer.plugins: [custom_lint]`).
- **`lib/main.dart`** : wiring `AppDatabase` à injecter dans `ProviderScope` via un override, DB ouverte avant `runApp`. Seeding des catégories `cat_default` slot réservé (seed effectif en Phase 11).
- **`lib/domain/`** : nouveau sous-arbre : `ids/`, `sessions/`, `markers/`, `mirk/`, `revealed/`, `photos/`, `envelope/`, `errors/`, `ports/`. Chaque sous-dossier = un bounded context Phase 03.
- **`lib/infrastructure/db/app_database.dart`** : entité centrale Phase 03, définit les tables Drift, les FK, les indices, les migrations. Constructor prend `QueryExecutor`.
- **`lib/infrastructure/db/migrations/v1_to_v2_notes.dart`** : migration fictive livrée Phase 03.
- **`lib/infrastructure/ids/ulid.dart`** + **`random_id_generator.dart`** + **`seeded_id_generator.dart`** : implémentations de `IdGenerator`.
- **`lib/infrastructure/stores/drift_*_store.dart`** : implémentations Drift des ports domain. Chacune catch les SqliteException et wrap en exception domain.
- **`lib/application/providers/`** : `idGeneratorProvider`, `appDatabaseProvider`, `sessionStoreProvider`, etc. (un par store).
- **`test/fixtures/drift_schemas/`** : dumps Drift commités (v1.json, v2.json).
- **`test/fixtures/json/`** : samples JSON versionnés pour tests JsonMigrator.
- **`test/fixtures/db_seed/`** : INSERT SQL hand-written pour peupler in-memory DB dans les tests.
- **`drift_schemas/`** (racine) : dumps drift_dev managés via `dart run drift_dev schema dump`. Script CI vérifie qu'ils sont à jour (fail si un dev a oublié de regenerate).
- **`.github/workflows/ci.yml` job `gates`** : ajout step `dart test` en fin.

</code_context>

<deferred>
## Deferred Ideas

- **Rotation backups par âge** — 3 rolling suffit V1.0. Si besoin d'une politique plus fine plus tard, ajouter en Phase 15 polish.
- **Soft-delete / corbeille / undo** — pas demandé V1.0, pas de dette technique inutile. Si un utilisateur demande post-V1, c'est une phase dédiée.
- **`VACUUM INTO` vs copy brute** pour backups — Claude's discretion Phase 03, pas de débat architectural.
- **Champs visuels exacts de `AtmosphericConfig` / `ShaderConfig`** — Phase 09 (fog rendering) décidera. Phase 03 pose la sealed class shape avec placeholder fields (ex: `Color baseColor`, `double noiseScale`) mais l'ensemble final est Phase 09.
- **Seed effectif des default categories (`cat_default` + RPG set)** — Phase 11 (Markers). Phase 03 réserve l'ID `cat_default` dans une constante domain mais n'insert aucune row.
- **Pipeline photos (capture, EXIF strip, downscale, filesystem storage)** — Phase 11. Phase 03 n'a que le modèle `PhotoRef` + la table `t_photos` + le port `PhotoStore` (implementation `FilesystemPhotoStore` Phase 11).
- **`ImportExportController` + ZIP archive + SCHEMA.md** — Phase 13. Phase 03 livre les briques (envelope, JsonMigrator, modèles) mais aucun orchestrateur import/export.
- **Matrice tests cross-version V1↔V2↔V3** — PORT-13, Phase 13. Phase 03 a juste la V1→V2 fictive pour prouver le framework.
- **`setBitCount` cached vs trigger vs runtime compute** — Claude's discretion Phase 03 (cached column + update au merge est le plus simple ; triggers sont plus exotiques).
- **Stats « % du monde révélé »** — feature V1.x (STAT-*). La colonne `setBitCount` est maintenue dès V1.0 pour l'avoir le jour où la feature arrive, mais aucune UI en V1.0.
- **Update paths à chaque changement de `path_provider`** — Phase 15 stabilité (la DB vit dans `app_support`, qui est stable entre versions OS, mais documenter le fallback si Apple change ça un jour).
- **`custom_lint` règles custom enforcement imports inter-layers** — déjà deferred Phase 01 → Phase 03. Si re-adoption `custom_lint` + `riverpod_lint` révèle que les lints stock couvrent, on reste sur stock. Si pas, une règle custom est une tâche Phase 03 ou Phase 04 review-gate.
- **POC MPL-unreachable heuristic fix pour `tool/check_licenses.dart`** — Phase 02 backlog. Pas mélangé avec Phase 03.

</deferred>

---

*Phase: 03-persistence-domain-models*
*Context gathered: 2026-04-18*

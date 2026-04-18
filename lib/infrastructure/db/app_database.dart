// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
// Re-exported through `part 'app_database.g.dart'` — the generated code
// references `MirkStyleConfig` directly, so the enclosing library must
// import it even though the converters file already does. The session-
// status import (finding #9 / Batch G) is no longer needed: generated
// code has zero references, confirmed by grep of app_database.g.dart.
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'migrations/v1_to_v2_notes.dart';
import 'pragma_setup.dart';
import 'type_converters.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// `t_sessions` — one row per tracking session.
///
/// SESS-06 invariant: at most one row with `status='active'`. Enforced by
/// the partial unique index `idx_t_sessions_status_active` (declared via
/// `@TableIndex.sql` below — Drift emits the exact `WHERE status='active'`
/// partial-index syntax since 2.30.x).
@DataClassName('SessionRow')
@TableIndex.sql('''
  CREATE UNIQUE INDEX idx_t_sessions_status_active
    ON t_sessions(status)
    WHERE status = 'active';
''')
class Sessions extends Table {
  @override
  String get tableName => 't_sessions';

  TextColumn get id => text()();
  TextColumn get displayName => text()();
  // DB-level CHECK constraint (finding #10, Batch B) — defense-in-depth on
  // top of the `SessionStatusStringConverter` contract. Raw SQL inserts that
  // bypass the converter will now be refused by SQLite itself.
  // ignore: recursive_getters
  TextColumn get status => text().check(status.isIn(const <String>['active', 'stopped']))();
  IntColumn get startedAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  // Drift's `check()` takes an `Expression<bool>` that references the column
  // itself — the self-reference is the documented pattern (see
  // https://drift.simonbinder.eu/docs/getting-started/advanced_dart_tables/
  // and the package doc example). `recursive_getters` is a false positive
  // here because the body is rewritten by the build_runner builder; the
  // actual runtime path never enters the getter recursively.
  // ignore: recursive_getters
  IntColumn get startedAtOffsetMinutes =>
      // ignore: recursive_getters
      integer().check(startedAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();
  IntColumn get stoppedAtUtc => integer().nullable().map(const UnixMsToDateTimeConverter())();
  // Finding #12 (Batch B) — offset-CHECK asymmetry: extend `[-720, 840]`
  // bound to `stoppedAtOffsetMinutes` parity with `startedAtOffsetMinutes`.
  // SQLite CHECK evaluates to UNKNOWN on NULL and does NOT fail, so null
  // rows (in-flight sessions) remain allowed; only out-of-range non-null
  // values are rejected.
  // ignore: recursive_getters
  IntColumn get stoppedAtOffsetMinutes =>
      integer().nullable()
      // ignore: recursive_getters
      .check(stoppedAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  // V2: fictive notes column — see migrations/v1_to_v2_notes.dart for
  // rationale. Ships nullable to match the V1->V2 `ALTER TABLE ... ADD
  // COLUMN` semantics (SQLite defaults new columns to NULL).
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `t_marker_categories` — user-defined marker taxonomies. Includes the
/// reserved `cat_default` sentinel row seeded by [AppDatabase] `onCreate`
/// (04-rev Batch F fix for finding #2); that row is the reassignment target
/// for markers whose category gets deleted (CONTEXT.md §cascade —
/// marker_category deletion does NOT cascade).
///
/// Pre-existing V1 databases get the same row via `v1_baseline.sql`
/// fixture; no V1→V2 backfill migration is needed because the production
/// V1→V2 migration (`v1_to_v2_notes.dart`) predates this seed and any V1
/// database in the wild is the fixture itself — the fixture already carries
/// the row.
@DataClassName('MarkerCategoryRow')
class MarkerCategories extends Table {
  @override
  String get tableName => 't_marker_categories';

  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get iconName => text()();
  IntColumn get createdAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  // Finding #12 (Batch B) — offset-CHECK asymmetry: extend UTC-offset bound.
  // ignore: recursive_getters
  IntColumn get createdAtOffsetMinutes =>
      // ignore: recursive_getters
      integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `t_markers` — points of interest captured during a session.
///
/// FK policy:
/// - `session_id` references `t_sessions.id` with ON DELETE CASCADE — deleting
///   a session drops its markers (CONTEXT.md §cascade).
/// - `category_id` references `t_marker_categories.id` WITHOUT cascade. The
///   `MarkerCategoryStore.delete` impl (03-06) reassigns markers to
///   `kCategoryDefaultId` inside a transaction before deleting the category.
@DataClassName('MarkerRow')
@TableIndex.sql('CREATE INDEX idx_t_markers_session_id ON t_markers(session_id);')
@TableIndex.sql('CREATE INDEX idx_t_markers_category_id ON t_markers(category_id);')
class Markers extends Table {
  @override
  String get tableName => 't_markers';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().references(MarkerCategories, #id)();
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  // Finding #12 (Batch B) — offset-CHECK asymmetry: extend UTC-offset bound.
  // ignore: recursive_getters
  IntColumn get createdAtOffsetMinutes =>
      // ignore: recursive_getters
      integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `t_revealed_tiles` — MIRK-03 storage unit: a 512-byte (64x64 bit) bitmap
/// per parent tile. Composite unique key `(session_id, parent_x, parent_y,
/// parent_zoom)` ensures per-session idempotence (re-reveal merges into the
/// existing row via `mergeBitmap`).
@DataClassName('RevealedTileRow')
@TableIndex.sql(
  'CREATE INDEX idx_t_revealed_tiles_session_id_parent_key '
  'ON t_revealed_tiles(session_id, parent_x, parent_y);',
)
class RevealedTiles extends Table {
  @override
  String get tableName => 't_revealed_tiles';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get parentX => integer()();
  IntColumn get parentY => integer()();
  // Finding #5/#13 (Batch C) — replace the magic `14` with
  // `kRevealedTileParentZoom` (source of truth in `lib/config/constants.dart`).
  IntColumn get parentZoom => integer().withDefault(const Constant(kRevealedTileParentZoom))();
  // Finding #14 (Batch B) — DB-level defense on the 512-byte bitmap
  // invariant already guarded by the store. `length(bitmap) = 512` refuses
  // any SQL-level write that bypasses the store path.
  //
  // Drift's `BlobColumn` does not expose a `.length` getter (that is a
  // `StringExpressionOperators` method only). We compose the CHECK through
  // a raw `CustomExpression<bool>` that references the unqualified column
  // name `bitmap` — the expression is emitted as the literal SQL
  // `CHECK (length(bitmap) = 512)` inside the `t_revealed_tiles` CREATE
  // TABLE statement, which is exactly the SQLite form we want.
  //
  // `kRevealedTileBitmapBytes` cannot be referenced inside a Drift `check()`
  // generator (the expression is emitted as literal SQL at build time), so
  // the literal 512 is paired with a unit-test-level guard referencing the
  // constant.
  BlobColumn get bitmap => blob().check(const CustomExpression<bool>('length(bitmap) = 512'))();
  IntColumn get setBitCount => integer().withDefault(const Constant(0))();
  IntColumn get updatedAtUtc => integer().map(const UnixMsToDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sessionId, parentX, parentY, parentZoom},
  ];
}

/// `t_mirk_styles` — renderer configurations. `renderer_type` is a denormalized
/// top-level copy of `config.rendererType` for fast SELECT-WHERE without a
/// JSON scan.
@DataClassName('MirkStyleRow')
class MirkStyles extends Table {
  @override
  String get tableName => 't_mirk_styles';

  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get rendererType => text()();
  TextColumn get config => text().map(const MirkStyleConfigJsonConverter())();
  IntColumn get createdAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  // Finding #12 (Batch B) — offset-CHECK asymmetry: extend UTC-offset bound.
  // ignore: recursive_getters
  IntColumn get createdAtOffsetMinutes =>
      // ignore: recursive_getters
      integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `t_photos` — photo attachments for markers. Deleting the parent marker
/// cascades here (CONTEXT.md §cascade — marker deletion drops attached
/// photos; orphan file cleanup on disk is the PhotoService's job, Phase 11).
@DataClassName('PhotoRow')
@TableIndex.sql('CREATE INDEX idx_t_photos_marker_id ON t_photos(marker_id);')
class Photos extends Table {
  @override
  String get tableName => 't_photos';

  TextColumn get id => text()();
  TextColumn get markerId => text().references(Markers, #id, onDelete: KeyAction.cascade)();
  TextColumn get relativeBasename => text()();
  IntColumn get widthPx => integer()();
  IntColumn get heightPx => integer()();
  IntColumn get fileSizeBytes => integer()();
  IntColumn get createdAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  // Finding #12 (Batch B) — offset-CHECK asymmetry: extend UTC-offset bound.
  // ignore: recursive_getters
  IntColumn get createdAtOffsetMinutes =>
      // ignore: recursive_getters
      integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// MirkFall's single SQLite store (CONTEXT.md §Stockage DB, decision D4).
///
/// Construction: `AppDatabase(executor, onBeforeUpgrade: hook)` — the
/// optional `onBeforeUpgrade` fires inside `MigrationStrategy.beforeOpen`
/// when `details.hadUpgrade == true`, BEFORE `onUpgrade` runs. 03-05 wires
/// `DbBackupService.takeBackup` into it so a pre-migration snapshot exists
/// if the upgrade corrupts data.
///
/// Pragma application order (RESEARCH §Pattern 1):
/// 1. `NativeDatabase.memory(setup:)` / `createInBackground(setup:)` applies
///    `PRAGMA journal_mode = WAL` to the raw sqlite3 handle BEFORE Drift's
///    first query (pitfall #2 — journal_mode read after open freezes the
///    journal mode).
/// 2. `MigrationStrategy.beforeOpen` calls [applyRuntimePragmas] to set the
///    other three pragmas (synchronous, busy_timeout, foreign_keys) on every
///    cold + warm open.
@DriftDatabase(tables: [Sessions, MarkerCategories, Markers, RevealedTiles, MirkStyles, Photos])
class AppDatabase extends _$AppDatabase {
  /// Creates an [AppDatabase] backed by [executor].
  ///
  /// [onBeforeUpgrade] fires from `beforeOpen` when `details.hadUpgrade ==
  /// true`, BEFORE `onUpgrade` runs. Kept nullable so tests + first-open
  /// (`onCreate`) paths don't need to provide one. 03-05 injects the real
  /// backup hook at the factory level.
  AppDatabase(super.executor, {this.onBeforeUpgrade});

  /// Pre-upgrade hook — see constructor docstring.
  final Future<void> Function(OpeningDetails details)? onBeforeUpgrade;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Finding #2 (Batch F) — seed the reserved `cat_default` row so
      // `MarkerCategoryStore.delete`'s reassign-target invariant holds on
      // every fresh database. The delete path reassigns markers to this id
      // inside a transaction before dropping the source category, which
      // assumes the target already exists.
      //
      // The 2026-04-18 timestamp is the Phase 03 persistence landing date —
      // stable across test reproductions (no wall-clock dependency) and
      // self-identifying in logs. Offset 0 (UTC) is correct: the row is a
      // schema sentinel, not a user-timezone event.
      await into(markerCategories).insert(
        MarkerCategoriesCompanion.insert(
          id: 'cat_default',
          displayName: 'Default',
          iconName: 'pin',
          createdAtUtc: DateTime.utc(2026, 4, 18),
          createdAtOffsetMinutes: 0,
        ),
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      await V1ToV2Notes.apply(m, from, to);
    },
    beforeOpen: (OpeningDetails details) async {
      if (details.hadUpgrade && onBeforeUpgrade != null) {
        await onBeforeUpgrade!(details);
      }
      await applyRuntimePragmas(this);
    },
  );
}

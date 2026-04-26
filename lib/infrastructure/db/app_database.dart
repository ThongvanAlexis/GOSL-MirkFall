// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: recursive_getters
// Drift's `.check()` builder takes an `Expression<bool>` that references
// the column getter itself. The self-reference is the documented Drift
// pattern (https://drift.simonbinder.eu/docs/getting-started/advanced_dart_tables/)
// — the build_runner rewrites the getter body, so the runtime path never
// enters the getter recursively. Hoisting the `ignore` to file scope
// keeps the column declarations readable after `dart format` reflows the
// `check(...)` expression across multiple lines (which moves the
// diagnostic origin line away from any narrow `// ignore:` placement).

import 'package:drift/drift.dart';
// Re-exported through `part 'app_database.g.dart'` — the generated code
// references `MirkStyleConfig` directly, so the enclosing library must
// import it even though the converters file already does. The session-
// status import (finding #9 / Batch G) is no longer needed: generated
// code has zero references, confirmed by grep of app_database.g.dart.
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'migrations/v1_to_v2_notes.dart';
import 'migrations/v2_to_v3_fixes.dart';
import 'migrations/v3_to_v4_session_mirk_style.dart';
import 'migrations/v4_to_v5_revealed_disc.dart';
import 'migrations/v5_to_v6_drop_revealed_tiles.dart';
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
  TextColumn get status => text().check(status.isIn(const <String>['active', 'stopped']))();
  IntColumn get startedAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  IntColumn get startedAtOffsetMinutes => integer().check(startedAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();
  IntColumn get stoppedAtUtc => integer().nullable().map(const UnixMsToDateTimeConverter())();
  // Finding #12 (Batch B) — offset-CHECK asymmetry: extend `[-720, 840]`
  // bound to `stoppedAtOffsetMinutes` parity with `startedAtOffsetMinutes`.
  // SQLite CHECK evaluates to UNKNOWN on NULL and does NOT fail, so null
  // rows (in-flight sessions) remain allowed; only out-of-range non-null
  // values are rejected.
  IntColumn get stoppedAtOffsetMinutes => integer().nullable().check(stoppedAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  // V2: fictive notes column — see migrations/v1_to_v2_notes.dart for
  // rationale. Ships nullable to match the V1->V2 `ALTER TABLE ... ADD
  // COLUMN` semantics (SQLite defaults new columns to NULL).
  TextColumn get notes => text().nullable()();

  // V4 (Phase 09 plan 09-05): per-session mirk-style selection (MIRK-07
  // wire-up). FK with `ON DELETE SET NULL` — deleting a user-imported
  // style degrades the session to the renderer-side default
  // (atmospheric) without orphaning the row. See
  // `migrations/v3_to_v4_session_mirk_style.dart`.
  TextColumn get mirkStyleId => text().nullable().references(MirkStyles, #id, onDelete: KeyAction.setNull)();

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
  IntColumn get createdAtOffsetMinutes => integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

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
  IntColumn get createdAtOffsetMinutes => integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `t_revealed_disc` — BUG-010 Option B continuous-geometry reveal storage.
///
/// One row per reveal disc: an immutable `(lat, lon, radius_m)` triple
/// timestamped at the originating GPS fix. Replaces the V4 cell-bitmap
/// model (`t_revealed_tiles`) for the SDF builder; the bitmap path is
/// kept untouched in this commit and dropped in BUG-010 Commit 5.
///
/// FK `session_id` references `t_sessions.id` with `ON DELETE CASCADE`
/// — deleting a session drops every disc it owns in the same transaction
/// (CONTEXT.md §cascade).
///
/// Indexes:
/// - `idx_t_revealed_disc_session` — cheap lookup when listing all discs
///   for a session (the access path for `discsForSession` and the FK
///   cascade scan).
/// - `idx_t_revealed_disc_session_latlon` — composite, prefilters the
///   bbox-query path on `(session_id, lat, lon)`. The current Dart-side
///   filter does not exploit the index yet; the future-perf SQL bbox
///   filter (see `DriftRevealedDiscStore.discsInBbox`) will.
@DataClassName('RevealedDiscRow')
@TableIndex.sql('CREATE INDEX idx_t_revealed_disc_session ON t_revealed_disc(session_id);')
@TableIndex.sql(
  'CREATE INDEX idx_t_revealed_disc_session_latlon '
  'ON t_revealed_disc(session_id, lat, lon);',
)
class RevealedDiscs extends Table {
  @override
  String get tableName => 't_revealed_disc';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  // DB-level guard mirroring the `RevealDisc` constructor's `radiusMeters > 0`
  // contract — defense-in-depth so a raw SQL insert that bypasses the store
  // path cannot land a degenerate row.
  //
  // SQL column name `radius_m` (override) rather than the auto-derived
  // `radius_meters`: keeps the storage column short and matches the
  // BUG-010 plan deliverable schema. The Dart accessor stays
  // `radiusMeters` for symmetry with `RevealDisc.radiusMeters`.
  RealColumn get radiusMeters => real().named('radius_m').check(radiusMeters.isBiggerThanValue(0.0))();
  // SQL column name `fixed_at_utc` matches the auto-derived snake_case;
  // override is unnecessary, but the converter is mandatory — UnixMs ↔
  // DateTime, same as every other timestamp in the schema.
  IntColumn get fixedAtUtc => integer().map(const UnixMsToDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
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
  IntColumn get createdAtOffsetMinutes => integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `t_fixes` — one row per GPS fix recorded during an active session
/// (Phase 05, SESS-07). FK `session_id` references `t_sessions.id` with
/// ON DELETE CASCADE — deleting a session drops every fix it owns in the
/// same transaction (CONTEXT.md §cascade).
///
/// CHECK constraints mirror the domain `@Assert` invariants on `Fix`
/// (lat in [-90, 90], lon in [-180, 180], accuracy >= 0, offset range).
/// Recursive-getter false-positives from the `column.check(column.expr)`
/// self-reference are suppressed at file scope — see the top-of-file
/// `ignore_for_file: recursive_getters` directive.
///
/// Indexes:
/// - `idx_t_fixes_session_id` — cheap lookup when deleting all fixes for
///   a session (also the access path for `countBySession`).
/// - `idx_t_fixes_session_recorded_at` — composite, supports the
///   `listBySession ORDER BY recorded_at_utc ASC` access pattern that
///   dominates session-detail reads.
@DataClassName('FixRow')
@TableIndex.sql('CREATE INDEX idx_t_fixes_session_id ON t_fixes(session_id);')
@TableIndex.sql(
  'CREATE INDEX idx_t_fixes_session_recorded_at '
  'ON t_fixes(session_id, recorded_at_utc);',
)
class Fixes extends Table {
  @override
  String get tableName => 't_fixes';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get recordedAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  IntColumn get recordedAtOffsetMinutes => integer().check(recordedAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();
  RealColumn get latitude => real().check(latitude.isBetweenValues(-90.0, 90.0))();
  RealColumn get longitude => real().check(longitude.isBetweenValues(-180.0, 180.0))();
  RealColumn get accuracyMeters => real().check(accuracyMeters.isBiggerOrEqualValue(0.0))();
  RealColumn get altitudeMeters => real().nullable()();
  RealColumn get speedMps => real().nullable()();
  RealColumn get headingDegrees => real().nullable()();

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
  IntColumn get createdAtOffsetMinutes => integer().check(createdAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();

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
@DriftDatabase(tables: [Sessions, MarkerCategories, Markers, RevealedDiscs, MirkStyles, Photos, Fixes])
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
  int get schemaVersion => 6;

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
      await V2ToV3Fixes.apply(m, from, to);
      await V3ToV4SessionMirkStyle.apply(m, from, to);
      await V4ToV5RevealedDisc.apply(m, from, to);
      await V5ToV6DropRevealedTiles.apply(m, from, to);
    },
    beforeOpen: (OpeningDetails details) async {
      if (details.hadUpgrade && onBeforeUpgrade != null) {
        await onBeforeUpgrade!(details);
      }
      await applyRuntimePragmas(this);
    },
  );
}

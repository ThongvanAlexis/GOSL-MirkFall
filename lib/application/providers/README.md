# lib/application/providers/

Riverpod providers bridging `lib/infrastructure/` implementations to
Dart callers above. Every store implementation shipped in Phase 03 has
exactly one provider here. First productive use of the
`riverpod_annotation` / `riverpod_generator` toolchain in the project
(Phase 01 deferred its activation until `custom_lint` ecosystem
convergence; Phase 03 re-introduced it via `analyzer ^10` override).

## Provider graph (Phase 03)

```
idGeneratorProvider (sync, keepAlive)
└── RandomIdGenerator

appDatabaseProvider (Future, keepAlive)
└── buildAppDatabase(<app_support>/mirkfall.db, backupDir, maxBackups=3)
    ├── NativeDatabase(File, setup: PRAGMA journal_mode = WAL)
    ├── AppDatabase(onBeforeUpgrade: DbBackupService.takeBackup)
    └── ref.onDispose(db.close)

sessionStoreProvider (Future, keepAlive)        ─┐
markerStoreProvider (Future, keepAlive)         ─┤
markerCategoryStoreProvider (Future, keepAlive) ─┼── ref.watch(appDatabaseProvider.future)
mirkStyleStoreProvider (Future, keepAlive)      ─┤
revealedTileStoreProvider (Future, keepAlive)   ─┘   (+ idGeneratorProvider for
                                                       session + revealed_tile)
```

## Provider style — `@Riverpod` generator

All seven providers are declared with `@Riverpod(keepAlive: true)` and
backed by `part '*.g.dart'` codegen. `keepAlive` is non-negotiable for
the DB leg: re-opening `mirkfall.db` on every consumer subscription
would thrash WAL and invalidate any active transactions. Stores are
cheap handles over the DB but keep the `keepAlive` flag for symmetry —
re-creating a `DriftSessionStore` instance is free, but re-creating the
graph root on every read would needlessly trigger the AppDatabase
future again.

## Test overrides

Phase 03 unit tests build stores directly (`DriftSessionStore(db,
idGen)` with `AppDatabase(NativeDatabase.memory(...))`) — they do not
go through the provider graph. Provider overrides land with the first
widget test in Phase 07 onward; the pattern is:

```dart
ProviderScope(overrides: [
  appDatabaseProvider.overrideWith((ref) async => testDb),
  idGeneratorProvider.overrideWithValue(SeededIdGenerator(seed: 1)),
]);
```

Dependent store providers pick up the overrides automatically via their
`ref.watch` wiring — no need to override every leaf.

## Generated files

`*.g.dart` files committed per CLAUDE.md build-determinism policy. Do
not edit by hand — run `dart run build_runner build
--delete-conflicting-outputs` when the annotated source changes.

## `main.dart` wiring — NOT in Phase 03

CONTEXT.md §Riverpod bootstrap defers `ProviderScope` + first provider
read to Phase 05 (where `ActiveSessionController` becomes the first
consumer). Phase 03 ships the providers but does NOT invoke them.
`lib/main.dart` stays unchanged in this plan.

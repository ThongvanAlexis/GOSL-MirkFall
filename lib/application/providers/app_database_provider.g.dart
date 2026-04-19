// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [AppDatabase] — async-resolved because `path_provider`
/// yields the app-support directory via a platform channel.
///
/// Wiring:
/// 1. `getApplicationSupportDirectory()` resolves `<app_support>/`.
/// 2. `buildAppDatabase(...)` (03-05) composes the `NativeDatabase`
///    executor, the `DbBackupService` (rolling 3-wide), and the
///    `AppDatabase.onBeforeUpgrade` hook in one call. Runtime pragmas
///    (synchronous, busy_timeout, foreign_keys) are applied by
///    `AppDatabase`'s `beforeOpen`; WAL is pinned by the executor's
///    `setup:` hook (file-backed → reports 'wal', unlike in-memory).
/// 3. `ref.onDispose(db.close)` wires the lifecycle — a provider
///    invalidate closes the underlying DB cleanly before reopen.
///
/// Tests override with a fresh in-memory `AppDatabase` via
/// `ProviderScope(overrides: [appDatabaseProvider.overrideWith(...)])`.
/// Phase 03 unit tests skip this path entirely and instantiate
/// `AppDatabase(NativeDatabase.memory(...))` directly.
///
/// `keepAlive: true` — the database is a process singleton; re-opening
/// on every consumer subscription would both thrash the WAL and
/// invalidate any active transactions.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Production [AppDatabase] — async-resolved because `path_provider`
/// yields the app-support directory via a platform channel.
///
/// Wiring:
/// 1. `getApplicationSupportDirectory()` resolves `<app_support>/`.
/// 2. `buildAppDatabase(...)` (03-05) composes the `NativeDatabase`
///    executor, the `DbBackupService` (rolling 3-wide), and the
///    `AppDatabase.onBeforeUpgrade` hook in one call. Runtime pragmas
///    (synchronous, busy_timeout, foreign_keys) are applied by
///    `AppDatabase`'s `beforeOpen`; WAL is pinned by the executor's
///    `setup:` hook (file-backed → reports 'wal', unlike in-memory).
/// 3. `ref.onDispose(db.close)` wires the lifecycle — a provider
///    invalidate closes the underlying DB cleanly before reopen.
///
/// Tests override with a fresh in-memory `AppDatabase` via
/// `ProviderScope(overrides: [appDatabaseProvider.overrideWith(...)])`.
/// Phase 03 unit tests skip this path entirely and instantiate
/// `AppDatabase(NativeDatabase.memory(...))` directly.
///
/// `keepAlive: true` — the database is a process singleton; re-opening
/// on every consumer subscription would both thrash the WAL and
/// invalidate any active transactions.

final class AppDatabaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppDatabase>,
          AppDatabase,
          FutureOr<AppDatabase>
        >
    with $FutureModifier<AppDatabase>, $FutureProvider<AppDatabase> {
  /// Production [AppDatabase] — async-resolved because `path_provider`
  /// yields the app-support directory via a platform channel.
  ///
  /// Wiring:
  /// 1. `getApplicationSupportDirectory()` resolves `<app_support>/`.
  /// 2. `buildAppDatabase(...)` (03-05) composes the `NativeDatabase`
  ///    executor, the `DbBackupService` (rolling 3-wide), and the
  ///    `AppDatabase.onBeforeUpgrade` hook in one call. Runtime pragmas
  ///    (synchronous, busy_timeout, foreign_keys) are applied by
  ///    `AppDatabase`'s `beforeOpen`; WAL is pinned by the executor's
  ///    `setup:` hook (file-backed → reports 'wal', unlike in-memory).
  /// 3. `ref.onDispose(db.close)` wires the lifecycle — a provider
  ///    invalidate closes the underlying DB cleanly before reopen.
  ///
  /// Tests override with a fresh in-memory `AppDatabase` via
  /// `ProviderScope(overrides: [appDatabaseProvider.overrideWith(...)])`.
  /// Phase 03 unit tests skip this path entirely and instantiate
  /// `AppDatabase(NativeDatabase.memory(...))` directly.
  ///
  /// `keepAlive: true` — the database is a process singleton; re-opening
  /// on every consumer subscription would both thrash the WAL and
  /// invalidate any active transactions.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<AppDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppDatabase> create(Ref ref) {
    return appDatabase(ref);
  }
}

String _$appDatabaseHash() => r'08ed38f7f68114dab09ffcdd65f8a540da652259';

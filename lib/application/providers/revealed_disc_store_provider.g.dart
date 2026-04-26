// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revealed_disc_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [RevealedDiscStore] — wraps [DriftRevealedDiscStore] around
/// the app database. No id generator dependency: every reveal disc id is
/// minted at the call site (typically the GPS pipeline, BUG-010 Commit 4)
/// and passed into [RevealedDiscStore.addDisc] verbatim — the store does
/// not allocate ids on the insert branch (unlike `DriftRevealedTileStore`,
/// which mints `rvt_` ids when a parent tile is first written).
///
/// `keepAlive: true` matches `revealedTileStoreProvider` — the store is a
/// process singleton riding on top of the singleton `appDatabaseProvider`.

@ProviderFor(revealedDiscStore)
final revealedDiscStoreProvider = RevealedDiscStoreProvider._();

/// Production [RevealedDiscStore] — wraps [DriftRevealedDiscStore] around
/// the app database. No id generator dependency: every reveal disc id is
/// minted at the call site (typically the GPS pipeline, BUG-010 Commit 4)
/// and passed into [RevealedDiscStore.addDisc] verbatim — the store does
/// not allocate ids on the insert branch (unlike `DriftRevealedTileStore`,
/// which mints `rvt_` ids when a parent tile is first written).
///
/// `keepAlive: true` matches `revealedTileStoreProvider` — the store is a
/// process singleton riding on top of the singleton `appDatabaseProvider`.

final class RevealedDiscStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<RevealedDiscStore>,
          RevealedDiscStore,
          FutureOr<RevealedDiscStore>
        >
    with
        $FutureModifier<RevealedDiscStore>,
        $FutureProvider<RevealedDiscStore> {
  /// Production [RevealedDiscStore] — wraps [DriftRevealedDiscStore] around
  /// the app database. No id generator dependency: every reveal disc id is
  /// minted at the call site (typically the GPS pipeline, BUG-010 Commit 4)
  /// and passed into [RevealedDiscStore.addDisc] verbatim — the store does
  /// not allocate ids on the insert branch (unlike `DriftRevealedTileStore`,
  /// which mints `rvt_` ids when a parent tile is first written).
  ///
  /// `keepAlive: true` matches `revealedTileStoreProvider` — the store is a
  /// process singleton riding on top of the singleton `appDatabaseProvider`.
  RevealedDiscStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'revealedDiscStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$revealedDiscStoreHash();

  @$internal
  @override
  $FutureProviderElement<RevealedDiscStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RevealedDiscStore> create(Ref ref) {
    return revealedDiscStore(ref);
  }
}

String _$revealedDiscStoreHash() => r'f061ae41aec8e677be7c1f6f0b1a2526f2b0f3a4';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revealed_tile_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [RevealedTileStore] — wraps [`DriftRevealedTileStore`]
/// around the app database + production id generator. The id generator
/// is required at this layer: `mergeMask`'s insert branch mints a new
/// revealed-tile row id (`rvt_` prefix) when the parent tile has not
/// been written yet in the current session.

@ProviderFor(revealedTileStore)
final revealedTileStoreProvider = RevealedTileStoreProvider._();

/// Production [RevealedTileStore] — wraps [`DriftRevealedTileStore`]
/// around the app database + production id generator. The id generator
/// is required at this layer: `mergeMask`'s insert branch mints a new
/// revealed-tile row id (`rvt_` prefix) when the parent tile has not
/// been written yet in the current session.

final class RevealedTileStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<RevealedTileStore>,
          RevealedTileStore,
          FutureOr<RevealedTileStore>
        >
    with
        $FutureModifier<RevealedTileStore>,
        $FutureProvider<RevealedTileStore> {
  /// Production [RevealedTileStore] — wraps [`DriftRevealedTileStore`]
  /// around the app database + production id generator. The id generator
  /// is required at this layer: `mergeMask`'s insert branch mints a new
  /// revealed-tile row id (`rvt_` prefix) when the parent tile has not
  /// been written yet in the current session.
  RevealedTileStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'revealedTileStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$revealedTileStoreHash();

  @$internal
  @override
  $FutureProviderElement<RevealedTileStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RevealedTileStore> create(Ref ref) {
    return revealedTileStore(ref);
  }
}

String _$revealedTileStoreHash() => r'a83d1954b485e6db9cf22bc234c757af210c7229';

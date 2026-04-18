// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marker_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [MarkerStore] — wraps [`DriftMarkerStore`] around the app
/// database. No id generator injection here: Phase 03 callers pass a
/// pre-allocated [MarkerId]; id-minting is a Phase 11 store extension
/// when the photo-capture flow starts minting markers on the fly.

@ProviderFor(markerStore)
final markerStoreProvider = MarkerStoreProvider._();

/// Production [MarkerStore] — wraps [`DriftMarkerStore`] around the app
/// database. No id generator injection here: Phase 03 callers pass a
/// pre-allocated [MarkerId]; id-minting is a Phase 11 store extension
/// when the photo-capture flow starts minting markers on the fly.

final class MarkerStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarkerStore>,
          MarkerStore,
          FutureOr<MarkerStore>
        >
    with $FutureModifier<MarkerStore>, $FutureProvider<MarkerStore> {
  /// Production [MarkerStore] — wraps [`DriftMarkerStore`] around the app
  /// database. No id generator injection here: Phase 03 callers pass a
  /// pre-allocated [MarkerId]; id-minting is a Phase 11 store extension
  /// when the photo-capture flow starts minting markers on the fly.
  MarkerStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'markerStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$markerStoreHash();

  @$internal
  @override
  $FutureProviderElement<MarkerStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarkerStore> create(Ref ref) {
    return markerStore(ref);
  }
}

String _$markerStoreHash() => r'2342ac7a9aff2ebb53238764f5047f922044e9fa';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marker_category_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [MarkerCategoryStore] — wraps
/// [`DriftMarkerCategoryStore`] around the app database. Carries the
/// non-CASCADE reassign-to-default transactional policy.

@ProviderFor(markerCategoryStore)
final markerCategoryStoreProvider = MarkerCategoryStoreProvider._();

/// Production [MarkerCategoryStore] — wraps
/// [`DriftMarkerCategoryStore`] around the app database. Carries the
/// non-CASCADE reassign-to-default transactional policy.

final class MarkerCategoryStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarkerCategoryStore>,
          MarkerCategoryStore,
          FutureOr<MarkerCategoryStore>
        >
    with
        $FutureModifier<MarkerCategoryStore>,
        $FutureProvider<MarkerCategoryStore> {
  /// Production [MarkerCategoryStore] — wraps
  /// [`DriftMarkerCategoryStore`] around the app database. Carries the
  /// non-CASCADE reassign-to-default transactional policy.
  MarkerCategoryStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'markerCategoryStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$markerCategoryStoreHash();

  @$internal
  @override
  $FutureProviderElement<MarkerCategoryStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarkerCategoryStore> create(Ref ref) {
    return markerCategoryStore(ref);
  }
}

String _$markerCategoryStoreHash() =>
    r'94ca7d9c8d399a22e79689d1c32442fc84e67120';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirk_style_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [MirkStyleStore] — wraps [`DriftMirkStyleStore`] around
/// the app database. Phase 09 adds the first consumer (`MirkRenderer`
/// seam); Phase 03 only wires persistence.

@ProviderFor(mirkStyleStore)
final mirkStyleStoreProvider = MirkStyleStoreProvider._();

/// Production [MirkStyleStore] — wraps [`DriftMirkStyleStore`] around
/// the app database. Phase 09 adds the first consumer (`MirkRenderer`
/// seam); Phase 03 only wires persistence.

final class MirkStyleStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<MirkStyleStore>,
          MirkStyleStore,
          FutureOr<MirkStyleStore>
        >
    with $FutureModifier<MirkStyleStore>, $FutureProvider<MirkStyleStore> {
  /// Production [MirkStyleStore] — wraps [`DriftMirkStyleStore`] around
  /// the app database. Phase 09 adds the first consumer (`MirkRenderer`
  /// seam); Phase 03 only wires persistence.
  MirkStyleStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mirkStyleStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mirkStyleStoreHash();

  @$internal
  @override
  $FutureProviderElement<MirkStyleStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MirkStyleStore> create(Ref ref) {
    return mirkStyleStore(ref);
  }
}

String _$mirkStyleStoreHash() => r'18841c52045bc95f1b870368dd0af1076e0b1e96';

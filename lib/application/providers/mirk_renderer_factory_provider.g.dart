// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirk_renderer_factory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [MirkRendererFactory] — pure singleton (no DB / no IO).
///
/// `keepAlive: true` matches the rest of the Phase 03/05 provider
/// graph: the factory has zero state and replacing it on widget-tree
/// changes would needlessly churn `activeMirkRendererProvider` (which
/// watches it). Tests override with a stub by passing
/// `mirkRendererFactoryProvider.overrideWithValue(otherFactory)`.

@ProviderFor(mirkRendererFactory)
final mirkRendererFactoryProvider = MirkRendererFactoryProvider._();

/// Production [MirkRendererFactory] — pure singleton (no DB / no IO).
///
/// `keepAlive: true` matches the rest of the Phase 03/05 provider
/// graph: the factory has zero state and replacing it on widget-tree
/// changes would needlessly churn `activeMirkRendererProvider` (which
/// watches it). Tests override with a stub by passing
/// `mirkRendererFactoryProvider.overrideWithValue(otherFactory)`.

final class MirkRendererFactoryProvider
    extends
        $FunctionalProvider<
          MirkRendererFactory,
          MirkRendererFactory,
          MirkRendererFactory
        >
    with $Provider<MirkRendererFactory> {
  /// Production [MirkRendererFactory] — pure singleton (no DB / no IO).
  ///
  /// `keepAlive: true` matches the rest of the Phase 03/05 provider
  /// graph: the factory has zero state and replacing it on widget-tree
  /// changes would needlessly churn `activeMirkRendererProvider` (which
  /// watches it). Tests override with a stub by passing
  /// `mirkRendererFactoryProvider.overrideWithValue(otherFactory)`.
  MirkRendererFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mirkRendererFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mirkRendererFactoryHash();

  @$internal
  @override
  $ProviderElement<MirkRendererFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MirkRendererFactory create(Ref ref) {
    return mirkRendererFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MirkRendererFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MirkRendererFactory>(value),
    );
  }
}

String _$mirkRendererFactoryHash() =>
    r'46f2c78e7ba055d2640e00553a734939e8cc52b9';

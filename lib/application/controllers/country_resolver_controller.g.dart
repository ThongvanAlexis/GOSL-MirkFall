// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'country_resolver_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orchestrates viewport → country hot-swap.
///
/// Subscribes to [MapView.viewportUpdates] (debounced 500 ms) and runs
/// each settled viewport through a [CountryResolver]. Behaviour:
///
/// - Result equals current active → no-op.
/// - Result is a DIFFERENT installed country → set activeCountry to the
///   new alpha3 + call `mapView.showMap(newAlpha3)` (the MapLibre adapter
///   reloads the style with the new PMTiles source).
/// - Result is a DIFFERENT country NOT installed → update
///   viewportCountry + viewportInInstalled=false (UI surfaces the banner);
///   activeCountry stays on whatever was last showing.
/// - Result is `null` (water / zoom<3) → set activeCountry=null +
///   `mapView.showMap(null)` switches to the world bundle.
///
/// Re-derivation trigger: the controller subscribes directly to the
/// installed-manifest repository's broadcast stream (see
/// [_attachManifestListenerIfNeeded]). Every manifest write (country
/// added / removed) triggers a rebuild of the internal [CountryResolver]
/// polygon map via [CountryPolygonLoader]. The controller re-runs the
/// resolve on the last-known viewport + emits the new active state.

@ProviderFor(CountryResolverController)
final countryResolverControllerProvider = CountryResolverControllerProvider._();

/// Orchestrates viewport → country hot-swap.
///
/// Subscribes to [MapView.viewportUpdates] (debounced 500 ms) and runs
/// each settled viewport through a [CountryResolver]. Behaviour:
///
/// - Result equals current active → no-op.
/// - Result is a DIFFERENT installed country → set activeCountry to the
///   new alpha3 + call `mapView.showMap(newAlpha3)` (the MapLibre adapter
///   reloads the style with the new PMTiles source).
/// - Result is a DIFFERENT country NOT installed → update
///   viewportCountry + viewportInInstalled=false (UI surfaces the banner);
///   activeCountry stays on whatever was last showing.
/// - Result is `null` (water / zoom<3) → set activeCountry=null +
///   `mapView.showMap(null)` switches to the world bundle.
///
/// Re-derivation trigger: the controller subscribes directly to the
/// installed-manifest repository's broadcast stream (see
/// [_attachManifestListenerIfNeeded]). Every manifest write (country
/// added / removed) triggers a rebuild of the internal [CountryResolver]
/// polygon map via [CountryPolygonLoader]. The controller re-runs the
/// resolve on the last-known viewport + emits the new active state.
final class CountryResolverControllerProvider extends $NotifierProvider<CountryResolverController, CountryResolverState> {
  /// Orchestrates viewport → country hot-swap.
  ///
  /// Subscribes to [MapView.viewportUpdates] (debounced 500 ms) and runs
  /// each settled viewport through a [CountryResolver]. Behaviour:
  ///
  /// - Result equals current active → no-op.
  /// - Result is a DIFFERENT installed country → set activeCountry to the
  ///   new alpha3 + call `mapView.showMap(newAlpha3)` (the MapLibre adapter
  ///   reloads the style with the new PMTiles source).
  /// - Result is a DIFFERENT country NOT installed → update
  ///   viewportCountry + viewportInInstalled=false (UI surfaces the banner);
  ///   activeCountry stays on whatever was last showing.
  /// - Result is `null` (water / zoom<3) → set activeCountry=null +
  ///   `mapView.showMap(null)` switches to the world bundle.
  ///
  /// Re-derivation trigger: the controller subscribes directly to the
  /// installed-manifest repository's broadcast stream (see
  /// [_attachManifestListenerIfNeeded]). Every manifest write (country
  /// added / removed) triggers a rebuild of the internal [CountryResolver]
  /// polygon map via [CountryPolygonLoader]. The controller re-runs the
  /// resolve on the last-known viewport + emits the new active state.
  CountryResolverControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countryResolverControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countryResolverControllerHash();

  @$internal
  @override
  CountryResolverController create() => CountryResolverController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CountryResolverState value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<CountryResolverState>(value));
  }
}

String _$countryResolverControllerHash() => r'5ad57721d1d4673856fd6939c6c402e849b12fc6';

/// Orchestrates viewport → country hot-swap.
///
/// Subscribes to [MapView.viewportUpdates] (debounced 500 ms) and runs
/// each settled viewport through a [CountryResolver]. Behaviour:
///
/// - Result equals current active → no-op.
/// - Result is a DIFFERENT installed country → set activeCountry to the
///   new alpha3 + call `mapView.showMap(newAlpha3)` (the MapLibre adapter
///   reloads the style with the new PMTiles source).
/// - Result is a DIFFERENT country NOT installed → update
///   viewportCountry + viewportInInstalled=false (UI surfaces the banner);
///   activeCountry stays on whatever was last showing.
/// - Result is `null` (water / zoom<3) → set activeCountry=null +
///   `mapView.showMap(null)` switches to the world bundle.
///
/// Re-derivation trigger: the controller subscribes directly to the
/// installed-manifest repository's broadcast stream (see
/// [_attachManifestListenerIfNeeded]). Every manifest write (country
/// added / removed) triggers a rebuild of the internal [CountryResolver]
/// polygon map via [CountryPolygonLoader]. The controller re-runs the
/// resolve on the last-known viewport + emits the new active state.

abstract class _$CountryResolverController extends $Notifier<CountryResolverState> {
  CountryResolverState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CountryResolverState, CountryResolverState>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<CountryResolverState, CountryResolverState>, CountryResolverState, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

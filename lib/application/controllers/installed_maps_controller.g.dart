// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_maps_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Presentation-facing view over the installed-maps manifest + catalog.
///
/// Watches [installedManifestProvider] + [countryCatalogProvider] and
/// projects the triple of `(installed map, updatesAvailable set,
/// totalDiskUsageBytes)`. Exposes a [deleteCountry] method that
/// delegates to the Plan 07-04 `CountryDeleteService` (which enforces
/// the `CountryCode.world` sentinel guard) + the repo's atomic write
/// triggers a manifest refresh via the broadcast stream.
///
/// The `updatesAvailable` set is a strict inequality check:
/// `installedCountry.pmtilesVersion != catalog.catalogVersion`. A
/// manifest entry with pmtilesVersion `"v20260419"` against a catalog
/// tagged `"v20260501"` flags the country as updatable; same tag means
/// no update needed. New countries in the catalog that aren't installed
/// are NOT in this set — they're handled by the Plan 07-06 "download"
/// flow instead.

@ProviderFor(InstalledMapsController)
final installedMapsControllerProvider = InstalledMapsControllerProvider._();

/// Presentation-facing view over the installed-maps manifest + catalog.
///
/// Watches [installedManifestProvider] + [countryCatalogProvider] and
/// projects the triple of `(installed map, updatesAvailable set,
/// totalDiskUsageBytes)`. Exposes a [deleteCountry] method that
/// delegates to the Plan 07-04 `CountryDeleteService` (which enforces
/// the `CountryCode.world` sentinel guard) + the repo's atomic write
/// triggers a manifest refresh via the broadcast stream.
///
/// The `updatesAvailable` set is a strict inequality check:
/// `installedCountry.pmtilesVersion != catalog.catalogVersion`. A
/// manifest entry with pmtilesVersion `"v20260419"` against a catalog
/// tagged `"v20260501"` flags the country as updatable; same tag means
/// no update needed. New countries in the catalog that aren't installed
/// are NOT in this set — they're handled by the Plan 07-06 "download"
/// flow instead.
final class InstalledMapsControllerProvider extends $NotifierProvider<InstalledMapsController, InstalledMapsState> {
  /// Presentation-facing view over the installed-maps manifest + catalog.
  ///
  /// Watches [installedManifestProvider] + [countryCatalogProvider] and
  /// projects the triple of `(installed map, updatesAvailable set,
  /// totalDiskUsageBytes)`. Exposes a [deleteCountry] method that
  /// delegates to the Plan 07-04 `CountryDeleteService` (which enforces
  /// the `CountryCode.world` sentinel guard) + the repo's atomic write
  /// triggers a manifest refresh via the broadcast stream.
  ///
  /// The `updatesAvailable` set is a strict inequality check:
  /// `installedCountry.pmtilesVersion != catalog.catalogVersion`. A
  /// manifest entry with pmtilesVersion `"v20260419"` against a catalog
  /// tagged `"v20260501"` flags the country as updatable; same tag means
  /// no update needed. New countries in the catalog that aren't installed
  /// are NOT in this set — they're handled by the Plan 07-06 "download"
  /// flow instead.
  InstalledMapsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedMapsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedMapsControllerHash();

  @$internal
  @override
  InstalledMapsController create() => InstalledMapsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstalledMapsState value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<InstalledMapsState>(value));
  }
}

String _$installedMapsControllerHash() => r'ed0a69331cdf23eee5ade9f2ae3e05c8459001b1';

/// Presentation-facing view over the installed-maps manifest + catalog.
///
/// Watches [installedManifestProvider] + [countryCatalogProvider] and
/// projects the triple of `(installed map, updatesAvailable set,
/// totalDiskUsageBytes)`. Exposes a [deleteCountry] method that
/// delegates to the Plan 07-04 `CountryDeleteService` (which enforces
/// the `CountryCode.world` sentinel guard) + the repo's atomic write
/// triggers a manifest refresh via the broadcast stream.
///
/// The `updatesAvailable` set is a strict inequality check:
/// `installedCountry.pmtilesVersion != catalog.catalogVersion`. A
/// manifest entry with pmtilesVersion `"v20260419"` against a catalog
/// tagged `"v20260501"` flags the country as updatable; same tag means
/// no update needed. New countries in the catalog that aren't installed
/// are NOT in this set — they're handled by the Plan 07-06 "download"
/// flow instead.

abstract class _$InstalledMapsController extends $Notifier<InstalledMapsState> {
  InstalledMapsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<InstalledMapsState, InstalledMapsState>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<InstalledMapsState, InstalledMapsState>, InstalledMapsState, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_stream_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [LocationStream] — wraps [`GeolocatorLocationStream`] around
/// the app's [`IdGenerator`] (the stream mints fresh `FixId`s on every
/// accepted `Position`).
///
/// `keepAlive: true` — the underlying geolocator foreground-service
/// subscription is expensive to (re-)start; the controller (Plan 05-03)
/// owns the actual `.positions(...)` subscription lifecycle. This provider
/// only holds the stateless factory.

@ProviderFor(locationStream)
final locationStreamProvider = LocationStreamProvider._();

/// Production [LocationStream] — wraps [`GeolocatorLocationStream`] around
/// the app's [`IdGenerator`] (the stream mints fresh `FixId`s on every
/// accepted `Position`).
///
/// `keepAlive: true` — the underlying geolocator foreground-service
/// subscription is expensive to (re-)start; the controller (Plan 05-03)
/// owns the actual `.positions(...)` subscription lifecycle. This provider
/// only holds the stateless factory.

final class LocationStreamProvider extends $FunctionalProvider<LocationStream, LocationStream, LocationStream> with $Provider<LocationStream> {
  /// Production [LocationStream] — wraps [`GeolocatorLocationStream`] around
  /// the app's [`IdGenerator`] (the stream mints fresh `FixId`s on every
  /// accepted `Position`).
  ///
  /// `keepAlive: true` — the underlying geolocator foreground-service
  /// subscription is expensive to (re-)start; the controller (Plan 05-03)
  /// owns the actual `.positions(...)` subscription lifecycle. This provider
  /// only holds the stateless factory.
  LocationStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationStreamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationStreamHash();

  @$internal
  @override
  $ProviderElement<LocationStream> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  LocationStream create(Ref ref) {
    return locationStream(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationStream value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<LocationStream>(value));
  }
}

String _$locationStreamHash() => r'cae6c9004c2c50f14f687581c19ac6103b532f96';

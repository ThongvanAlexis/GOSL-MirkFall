// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oem_detector_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [OemDetector] — wraps a fresh [`DeviceInfoPlugin`]. The
/// plugin is a stateless handle; re-constructing is ~free but
/// `keepAlive: true` keeps the detection result path consistent across
/// consumers (guidance screen + debug menu).

@ProviderFor(oemDetector)
final oemDetectorProvider = OemDetectorProvider._();

/// Production [OemDetector] — wraps a fresh [`DeviceInfoPlugin`]. The
/// plugin is a stateless handle; re-constructing is ~free but
/// `keepAlive: true` keeps the detection result path consistent across
/// consumers (guidance screen + debug menu).

final class OemDetectorProvider extends $FunctionalProvider<OemDetector, OemDetector, OemDetector> with $Provider<OemDetector> {
  /// Production [OemDetector] — wraps a fresh [`DeviceInfoPlugin`]. The
  /// plugin is a stateless handle; re-constructing is ~free but
  /// `keepAlive: true` keeps the detection result path consistent across
  /// consumers (guidance screen + debug menu).
  OemDetectorProvider._()
    : super(from: null, argument: null, retry: null, name: r'oemDetectorProvider', isAutoDispose: false, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$oemDetectorHash();

  @$internal
  @override
  $ProviderElement<OemDetector> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  OemDetector create(Ref ref) {
    return oemDetector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OemDetector value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<OemDetector>(value));
  }
}

String _$oemDetectorHash() => r'2c2ac64863fdbecb736d4b92a78c645a7d85ccd7';

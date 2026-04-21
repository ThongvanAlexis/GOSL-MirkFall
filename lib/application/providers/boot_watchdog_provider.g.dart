// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boot_watchdog_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Process-singleton [IosSignificantChangeWatchdog] wired over the
/// `app.gosl.mirkfall/boot_watchdog` MethodChannel.
///
/// `keepAlive: true` — the underlying channel handler on the iOS side is a
/// per-process resource; re-creating the Dart wrapper on every consumer
/// subscription would not reduce native work but would churn the Riverpod
/// graph.

@ProviderFor(iosSignificantChangeWatchdog)
final iosSignificantChangeWatchdogProvider = IosSignificantChangeWatchdogProvider._();

/// Process-singleton [IosSignificantChangeWatchdog] wired over the
/// `app.gosl.mirkfall/boot_watchdog` MethodChannel.
///
/// `keepAlive: true` — the underlying channel handler on the iOS side is a
/// per-process resource; re-creating the Dart wrapper on every consumer
/// subscription would not reduce native work but would churn the Riverpod
/// graph.

final class IosSignificantChangeWatchdogProvider
    extends $FunctionalProvider<IosSignificantChangeWatchdog, IosSignificantChangeWatchdog, IosSignificantChangeWatchdog>
    with $Provider<IosSignificantChangeWatchdog> {
  /// Process-singleton [IosSignificantChangeWatchdog] wired over the
  /// `app.gosl.mirkfall/boot_watchdog` MethodChannel.
  ///
  /// `keepAlive: true` — the underlying channel handler on the iOS side is a
  /// per-process resource; re-creating the Dart wrapper on every consumer
  /// subscription would not reduce native work but would churn the Riverpod
  /// graph.
  IosSignificantChangeWatchdogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'iosSignificantChangeWatchdogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$iosSignificantChangeWatchdogHash();

  @$internal
  @override
  $ProviderElement<IosSignificantChangeWatchdog> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  IosSignificantChangeWatchdog create(Ref ref) {
    return iosSignificantChangeWatchdog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IosSignificantChangeWatchdog value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<IosSignificantChangeWatchdog>(value));
  }
}

String _$iosSignificantChangeWatchdogHash() => r'e359cbf08d7ffdb19a857b0db4c6780b6e2e7f0c';

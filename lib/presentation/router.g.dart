// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 05 route map:
/// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
/// - `/sessions/:id` → [SessionDetailScreen]
/// - `/settings` → [SettingsScreen]
/// - `/permissions/rationale` → [PermissionRationaleScreen]
/// - `/permissions/denied` → [PermissionDeniedScreen]
/// - `/permissions/oem` → [OemGuidanceScreen]
/// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
/// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
///
/// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
/// top. [AppShell] decides — based on `currentLocation` — whether to
/// render the cross-route active-session banner (hidden on
/// `/sessions/:id`).

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 05 route map:
/// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
/// - `/sessions/:id` → [SessionDetailScreen]
/// - `/settings` → [SettingsScreen]
/// - `/permissions/rationale` → [PermissionRationaleScreen]
/// - `/permissions/denied` → [PermissionDeniedScreen]
/// - `/permissions/oem` → [OemGuidanceScreen]
/// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
/// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
///
/// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
/// top. [AppShell] decides — based on `currentLocation` — whether to
/// render the cross-route active-session banner (hidden on
/// `/sessions/:id`).

final class AppRouterProvider extends $FunctionalProvider<GoRouter, GoRouter, GoRouter> with $Provider<GoRouter> {
  /// Root GoRouter exposed via Riverpod so consumers get it through DI.
  ///
  /// Phase 05 route map:
  /// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
  /// - `/sessions/:id` → [SessionDetailScreen]
  /// - `/settings` → [SettingsScreen]
  /// - `/permissions/rationale` → [PermissionRationaleScreen]
  /// - `/permissions/denied` → [PermissionDeniedScreen]
  /// - `/permissions/oem` → [OemGuidanceScreen]
  /// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
  /// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
  ///
  /// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
  /// top. [AppShell] decides — based on `currentLocation` — whether to
  /// render the cross-route active-session banner (hidden on
  /// `/sessions/:id`).
  AppRouterProvider._()
    : super(from: null, argument: null, retry: null, name: r'appRouterProvider', isAutoDispose: true, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<GoRouter>(value));
  }
}

String _$appRouterHash() => r'9d0f761c2460974be07f50bebabf10776b173595';

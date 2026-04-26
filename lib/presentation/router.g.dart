// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 05 route map (extended by Phase 07):
/// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
/// - `/sessions/:id` → [SessionDetailScreen]
/// - `/settings` → [SettingsScreen]
/// - `/permissions/rationale` → [PermissionRationaleScreen]
/// - `/permissions/denied` → [PermissionDeniedScreen]
/// - `/permissions/oem` → [OemGuidanceScreen]
/// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
/// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
///
/// Phase 07 additions:
/// - `/map` → [MapScreen] (full-screen interactive map)
/// - `/maps/download` → [MapsDownloadScreen] (catalog browse + enqueue)
/// - `/maps/manage` → [MapsManageScreen] (installed list + delete)
/// - `/styles/import` → [StyleImportPlaceholderScreen] (Phase 13 stub)
/// - `/styles/export` → [StyleExportPlaceholderScreen] (Phase 13 stub)
///
/// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
/// top. [AppShell] decides — based on `currentLocation` — whether to
/// render the cross-route active-session banner (hidden on
/// `/sessions/:id` and `/map`).

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 05 route map (extended by Phase 07):
/// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
/// - `/sessions/:id` → [SessionDetailScreen]
/// - `/settings` → [SettingsScreen]
/// - `/permissions/rationale` → [PermissionRationaleScreen]
/// - `/permissions/denied` → [PermissionDeniedScreen]
/// - `/permissions/oem` → [OemGuidanceScreen]
/// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
/// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
///
/// Phase 07 additions:
/// - `/map` → [MapScreen] (full-screen interactive map)
/// - `/maps/download` → [MapsDownloadScreen] (catalog browse + enqueue)
/// - `/maps/manage` → [MapsManageScreen] (installed list + delete)
/// - `/styles/import` → [StyleImportPlaceholderScreen] (Phase 13 stub)
/// - `/styles/export` → [StyleExportPlaceholderScreen] (Phase 13 stub)
///
/// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
/// top. [AppShell] decides — based on `currentLocation` — whether to
/// render the cross-route active-session banner (hidden on
/// `/sessions/:id` and `/map`).

final class AppRouterProvider extends $FunctionalProvider<GoRouter, GoRouter, GoRouter> with $Provider<GoRouter> {
  /// Root GoRouter exposed via Riverpod so consumers get it through DI.
  ///
  /// Phase 05 route map (extended by Phase 07):
  /// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
  /// - `/sessions/:id` → [SessionDetailScreen]
  /// - `/settings` → [SettingsScreen]
  /// - `/permissions/rationale` → [PermissionRationaleScreen]
  /// - `/permissions/denied` → [PermissionDeniedScreen]
  /// - `/permissions/oem` → [OemGuidanceScreen]
  /// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
  /// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
  ///
  /// Phase 07 additions:
  /// - `/map` → [MapScreen] (full-screen interactive map)
  /// - `/maps/download` → [MapsDownloadScreen] (catalog browse + enqueue)
  /// - `/maps/manage` → [MapsManageScreen] (installed list + delete)
  /// - `/styles/import` → [StyleImportPlaceholderScreen] (Phase 13 stub)
  /// - `/styles/export` → [StyleExportPlaceholderScreen] (Phase 13 stub)
  ///
  /// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
  /// top. [AppShell] decides — based on `currentLocation` — whether to
  /// render the cross-route active-session banner (hidden on
  /// `/sessions/:id` and `/map`).
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

String _$appRouterHash() => r'78241509a2ce9932bfaa77a8e90c04c7e1dfb4d4';

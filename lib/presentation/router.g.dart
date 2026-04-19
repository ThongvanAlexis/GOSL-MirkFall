// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 01 ships three routes: `/` (home placeholder), `/about` (placeholder
/// with the 7-tap easter egg), `/debug` (debug menu). Later phases add the
/// real map / settings / marker routes.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 01 ships three routes: `/` (home placeholder), `/about` (placeholder
/// with the 7-tap easter egg), `/debug` (debug menu). Later phases add the
/// real map / settings / marker routes.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Root GoRouter exposed via Riverpod so consumers get it through DI.
  ///
  /// Phase 01 ships three routes: `/` (home placeholder), `/about` (placeholder
  /// with the 7-tap easter egg), `/debug` (debug menu). Later phases add the
  /// real map / settings / marker routes.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'd77143bbda21dd5b18cbe80ccb5a5fbda8c09c0c';

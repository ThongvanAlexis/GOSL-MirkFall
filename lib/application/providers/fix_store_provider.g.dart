// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fix_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [FixStore] — wraps [`DriftFixStore`] around the app database.
///
/// Returned as `Future<FixStore>` because [appDatabaseProvider] is async
/// (path_provider resolves `<app_support>/` off the UI thread). Consumers
/// (Plan 05-02 ActiveSessionController) await
/// `ref.watch(fixStoreProvider.future)` at construction time.
///
/// `keepAlive: true` — the store wraps a process-singleton database;
/// re-creating on every consumer subscription would not reduce DB load
/// (Drift holds the handle) but would churn the Riverpod graph.

@ProviderFor(fixStore)
final fixStoreProvider = FixStoreProvider._();

/// Production [FixStore] — wraps [`DriftFixStore`] around the app database.
///
/// Returned as `Future<FixStore>` because [appDatabaseProvider] is async
/// (path_provider resolves `<app_support>/` off the UI thread). Consumers
/// (Plan 05-02 ActiveSessionController) await
/// `ref.watch(fixStoreProvider.future)` at construction time.
///
/// `keepAlive: true` — the store wraps a process-singleton database;
/// re-creating on every consumer subscription would not reduce DB load
/// (Drift holds the handle) but would churn the Riverpod graph.

final class FixStoreProvider
    extends
        $FunctionalProvider<AsyncValue<FixStore>, FixStore, FutureOr<FixStore>>
    with $FutureModifier<FixStore>, $FutureProvider<FixStore> {
  /// Production [FixStore] — wraps [`DriftFixStore`] around the app database.
  ///
  /// Returned as `Future<FixStore>` because [appDatabaseProvider] is async
  /// (path_provider resolves `<app_support>/` off the UI thread). Consumers
  /// (Plan 05-02 ActiveSessionController) await
  /// `ref.watch(fixStoreProvider.future)` at construction time.
  ///
  /// `keepAlive: true` — the store wraps a process-singleton database;
  /// re-creating on every consumer subscription would not reduce DB load
  /// (Drift holds the handle) but would churn the Riverpod graph.
  FixStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fixStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fixStoreHash();

  @$internal
  @override
  $FutureProviderElement<FixStore> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FixStore> create(Ref ref) {
    return fixStore(ref);
  }
}

String _$fixStoreHash() => r'9b5c4886446e011102ddeca446dbb66979720931';

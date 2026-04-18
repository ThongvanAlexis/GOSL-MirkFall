// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [SessionStore] — wraps [`DriftSessionStore`] around the
/// app database + production id generator.
///
/// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
/// async (path_provider resolves `<app_support>/` off the UI thread).
/// Consumers that need the store synchronously (Phase 05 controllers)
/// await `ref.watch(sessionStoreProvider.future)` at construction time.

@ProviderFor(sessionStore)
final sessionStoreProvider = SessionStoreProvider._();

/// Production [SessionStore] — wraps [`DriftSessionStore`] around the
/// app database + production id generator.
///
/// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
/// async (path_provider resolves `<app_support>/` off the UI thread).
/// Consumers that need the store synchronously (Phase 05 controllers)
/// await `ref.watch(sessionStoreProvider.future)` at construction time.

final class SessionStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionStore>,
          SessionStore,
          FutureOr<SessionStore>
        >
    with $FutureModifier<SessionStore>, $FutureProvider<SessionStore> {
  /// Production [SessionStore] — wraps [`DriftSessionStore`] around the
  /// app database + production id generator.
  ///
  /// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
  /// async (path_provider resolves `<app_support>/` off the UI thread).
  /// Consumers that need the store synchronously (Phase 05 controllers)
  /// await `ref.watch(sessionStoreProvider.future)` at construction time.
  SessionStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionStoreHash();

  @$internal
  @override
  $FutureProviderElement<SessionStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionStore> create(Ref ref) {
    return sessionStore(ref);
  }
}

String _$sessionStoreHash() => r'a7772a3d19fde69d023b6739b6badc9a818de1b6';

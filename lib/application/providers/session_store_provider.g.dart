// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [SessionStore] — wraps [`DriftSessionStore`] around the
/// app database.
///
/// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
/// async (path_provider resolves `<app_support>/` off the UI thread).
/// Consumers that need the store synchronously (Phase 05 controllers)
/// await `ref.watch(sessionStoreProvider.future)` at construction time.
///
/// Finding #21 (Batch G) — dropped the IdGenerator injection: the store
/// never used it (all session ids are pre-allocated by the caller). If a
/// future insert-without-id path emerges, inject the generator then.

@ProviderFor(sessionStore)
final sessionStoreProvider = SessionStoreProvider._();

/// Production [SessionStore] — wraps [`DriftSessionStore`] around the
/// app database.
///
/// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
/// async (path_provider resolves `<app_support>/` off the UI thread).
/// Consumers that need the store synchronously (Phase 05 controllers)
/// await `ref.watch(sessionStoreProvider.future)` at construction time.
///
/// Finding #21 (Batch G) — dropped the IdGenerator injection: the store
/// never used it (all session ids are pre-allocated by the caller). If a
/// future insert-without-id path emerges, inject the generator then.

final class SessionStoreProvider extends $FunctionalProvider<AsyncValue<SessionStore>, SessionStore, FutureOr<SessionStore>>
    with $FutureModifier<SessionStore>, $FutureProvider<SessionStore> {
  /// Production [SessionStore] — wraps [`DriftSessionStore`] around the
  /// app database.
  ///
  /// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
  /// async (path_provider resolves `<app_support>/` off the UI thread).
  /// Consumers that need the store synchronously (Phase 05 controllers)
  /// await `ref.watch(sessionStoreProvider.future)` at construction time.
  ///
  /// Finding #21 (Batch G) — dropped the IdGenerator injection: the store
  /// never used it (all session ids are pre-allocated by the caller). If a
  /// future insert-without-id path emerges, inject the generator then.
  SessionStoreProvider._()
    : super(from: null, argument: null, retry: null, name: r'sessionStoreProvider', isAutoDispose: false, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$sessionStoreHash();

  @$internal
  @override
  $FutureProviderElement<SessionStore> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionStore> create(Ref ref) {
    return sessionStore(ref);
  }
}

String _$sessionStoreHash() => r'5d8d2fabfc2f87fb8ba9ebb8d8f45cfce312b0c4';

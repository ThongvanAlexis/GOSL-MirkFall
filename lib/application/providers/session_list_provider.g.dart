// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Derived stream provider that bridges [sessionStoreProvider] (a
/// `Future<SessionStore>`) to the widget layer.
///
/// Plan 05-04 `SessionListScreen` consumes this via
/// `ref.watch(sessionListProvider)` and renders three arms:
/// `AsyncLoading` → spinner, `AsyncError` → error card, `AsyncData` →
/// session tiles (or empty-state CTA).
///
/// The implementation `await`s the store future once then pipes through
/// `watchAll()` — first emission carries the current snapshot, subsequent
/// emissions fire on every `t_sessions` row change. Ordering matches the
/// store's `listAll` contract (`startedAtUtc` DESC).

@ProviderFor(sessionList)
final sessionListProvider = SessionListProvider._();

/// Derived stream provider that bridges [sessionStoreProvider] (a
/// `Future<SessionStore>`) to the widget layer.
///
/// Plan 05-04 `SessionListScreen` consumes this via
/// `ref.watch(sessionListProvider)` and renders three arms:
/// `AsyncLoading` → spinner, `AsyncError` → error card, `AsyncData` →
/// session tiles (or empty-state CTA).
///
/// The implementation `await`s the store future once then pipes through
/// `watchAll()` — first emission carries the current snapshot, subsequent
/// emissions fire on every `t_sessions` row change. Ordering matches the
/// store's `listAll` contract (`startedAtUtc` DESC).

final class SessionListProvider extends $FunctionalProvider<AsyncValue<List<Session>>, List<Session>, Stream<List<Session>>>
    with $FutureModifier<List<Session>>, $StreamProvider<List<Session>> {
  /// Derived stream provider that bridges [sessionStoreProvider] (a
  /// `Future<SessionStore>`) to the widget layer.
  ///
  /// Plan 05-04 `SessionListScreen` consumes this via
  /// `ref.watch(sessionListProvider)` and renders three arms:
  /// `AsyncLoading` → spinner, `AsyncError` → error card, `AsyncData` →
  /// session tiles (or empty-state CTA).
  ///
  /// The implementation `await`s the store future once then pipes through
  /// `watchAll()` — first emission carries the current snapshot, subsequent
  /// emissions fire on every `t_sessions` row change. Ordering matches the
  /// store's `listAll` contract (`startedAtUtc` DESC).
  SessionListProvider._()
    : super(from: null, argument: null, retry: null, name: r'sessionListProvider', isAutoDispose: false, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$sessionListHash();

  @$internal
  @override
  $StreamProviderElement<List<Session>> $createElement($ProviderPointer pointer) => $StreamProviderElement(pointer);

  @override
  Stream<List<Session>> create(Ref ref) {
    return sessionList(ref);
  }
}

String _$sessionListHash() => r'8bbdb0bab60ed477edf1f368a1d14fbdbaab008b';

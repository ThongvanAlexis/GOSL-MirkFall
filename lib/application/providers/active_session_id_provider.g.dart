// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_session_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Id of the session currently being tracked, or `null` while Idle / Starting / loading / error.
///
/// Narrow projection of `activeSessionControllerProvider`: the controller re-emits a NEW
/// `Tracking` on every accepted fix (`copyWith(fixCount:, lastFix:)`), so anything that must
/// live for the whole session — the mirk renderer above all — watches this provider instead of
/// the controller. A functional provider notifies its dependents only when `previous != next`
/// (riverpod `Provider.updateShouldNotify`) and `SessionId` compares by value, so a fix on the
/// same session never propagates. A provider rather than `.select(...)`: `riverpod_annotation`
/// does not re-export the `select` modifier and the application layer stays free of
/// `flutter_riverpod`.

@ProviderFor(activeSessionId)
final activeSessionIdProvider = ActiveSessionIdProvider._();

/// Id of the session currently being tracked, or `null` while Idle / Starting / loading / error.
///
/// Narrow projection of `activeSessionControllerProvider`: the controller re-emits a NEW
/// `Tracking` on every accepted fix (`copyWith(fixCount:, lastFix:)`), so anything that must
/// live for the whole session — the mirk renderer above all — watches this provider instead of
/// the controller. A functional provider notifies its dependents only when `previous != next`
/// (riverpod `Provider.updateShouldNotify`) and `SessionId` compares by value, so a fix on the
/// same session never propagates. A provider rather than `.select(...)`: `riverpod_annotation`
/// does not re-export the `select` modifier and the application layer stays free of
/// `flutter_riverpod`.

final class ActiveSessionIdProvider extends $FunctionalProvider<SessionId?, SessionId?, SessionId?> with $Provider<SessionId?> {
  /// Id of the session currently being tracked, or `null` while Idle / Starting / loading / error.
  ///
  /// Narrow projection of `activeSessionControllerProvider`: the controller re-emits a NEW
  /// `Tracking` on every accepted fix (`copyWith(fixCount:, lastFix:)`), so anything that must
  /// live for the whole session — the mirk renderer above all — watches this provider instead of
  /// the controller. A functional provider notifies its dependents only when `previous != next`
  /// (riverpod `Provider.updateShouldNotify`) and `SessionId` compares by value, so a fix on the
  /// same session never propagates. A provider rather than `.select(...)`: `riverpod_annotation`
  /// does not re-export the `select` modifier and the application layer stays free of
  /// `flutter_riverpod`.
  ActiveSessionIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSessionIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSessionIdHash();

  @$internal
  @override
  $ProviderElement<SessionId?> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  SessionId? create(Ref ref) {
    return activeSessionId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionId? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<SessionId?>(value));
  }
}

String _$activeSessionIdHash() => r'69a60dce26fba0edd39aaefd34acc4f9a6954dbe';

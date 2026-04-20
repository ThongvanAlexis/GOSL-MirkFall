// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod Notifier backing the SharedPreferences-persisted tracking
/// settings: distanceFilter + one-shot flags (permission flow completed,
/// OEM guidance seen).
///
/// `keepAlive: true` — SharedPreferences is a process-singleton handle;
/// recomputing on every consumer subscription would be wasted async
/// work with no observable benefit. The notifier itself is stateless
/// beyond what's in `state`.
///
/// Writes go through the notifier methods ([setDistanceFilterMeters],
/// [markPermissionFlowCompleted], [markOemGuidanceSeen]); every method
/// persists to SharedPreferences and updates `state` in the same
/// transaction so subscribers see the new value synchronously on the
/// next frame.

@ProviderFor(SessionSettings)
final sessionSettingsProvider = SessionSettingsProvider._();

/// Riverpod Notifier backing the SharedPreferences-persisted tracking
/// settings: distanceFilter + one-shot flags (permission flow completed,
/// OEM guidance seen).
///
/// `keepAlive: true` — SharedPreferences is a process-singleton handle;
/// recomputing on every consumer subscription would be wasted async
/// work with no observable benefit. The notifier itself is stateless
/// beyond what's in `state`.
///
/// Writes go through the notifier methods ([setDistanceFilterMeters],
/// [markPermissionFlowCompleted], [markOemGuidanceSeen]); every method
/// persists to SharedPreferences and updates `state` in the same
/// transaction so subscribers see the new value synchronously on the
/// next frame.
final class SessionSettingsProvider
    extends $AsyncNotifierProvider<SessionSettings, SessionSettingsSnapshot> {
  /// Riverpod Notifier backing the SharedPreferences-persisted tracking
  /// settings: distanceFilter + one-shot flags (permission flow completed,
  /// OEM guidance seen).
  ///
  /// `keepAlive: true` — SharedPreferences is a process-singleton handle;
  /// recomputing on every consumer subscription would be wasted async
  /// work with no observable benefit. The notifier itself is stateless
  /// beyond what's in `state`.
  ///
  /// Writes go through the notifier methods ([setDistanceFilterMeters],
  /// [markPermissionFlowCompleted], [markOemGuidanceSeen]); every method
  /// persists to SharedPreferences and updates `state` in the same
  /// transaction so subscribers see the new value synchronously on the
  /// next frame.
  SessionSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionSettingsHash();

  @$internal
  @override
  SessionSettings create() => SessionSettings();
}

String _$sessionSettingsHash() => r'19e1ef2c6275a26b1f7da8889d2d26cb98fa0ffd';

/// Riverpod Notifier backing the SharedPreferences-persisted tracking
/// settings: distanceFilter + one-shot flags (permission flow completed,
/// OEM guidance seen).
///
/// `keepAlive: true` — SharedPreferences is a process-singleton handle;
/// recomputing on every consumer subscription would be wasted async
/// work with no observable benefit. The notifier itself is stateless
/// beyond what's in `state`.
///
/// Writes go through the notifier methods ([setDistanceFilterMeters],
/// [markPermissionFlowCompleted], [markOemGuidanceSeen]); every method
/// persists to SharedPreferences and updates `state` in the same
/// transaction so subscribers see the new value synchronously on the
/// next frame.

abstract class _$SessionSettings
    extends $AsyncNotifier<SessionSettingsSnapshot> {
  FutureOr<SessionSettingsSnapshot> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SessionSettingsSnapshot>,
              SessionSettingsSnapshot
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SessionSettingsSnapshot>,
                SessionSettingsSnapshot
              >,
              AsyncValue<SessionSettingsSnapshot>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

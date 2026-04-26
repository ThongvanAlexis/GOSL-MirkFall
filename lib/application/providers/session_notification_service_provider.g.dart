// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_notification_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [SessionNotificationService] — wraps a
/// [`FlutterLocalNotificationsAdapter`] around the
/// [`FlutterLocalNotificationsPlugin`] singleton.
///
/// `keepAlive: true` — the Android notification channel is a
/// process-long singleton; re-creating the service on every consumer
/// subscription would be wasted work with no observable benefit.

@ProviderFor(sessionNotificationService)
final sessionNotificationServiceProvider = SessionNotificationServiceProvider._();

/// Production [SessionNotificationService] — wraps a
/// [`FlutterLocalNotificationsAdapter`] around the
/// [`FlutterLocalNotificationsPlugin`] singleton.
///
/// `keepAlive: true` — the Android notification channel is a
/// process-long singleton; re-creating the service on every consumer
/// subscription would be wasted work with no observable benefit.

final class SessionNotificationServiceProvider extends $FunctionalProvider<SessionNotificationService, SessionNotificationService, SessionNotificationService>
    with $Provider<SessionNotificationService> {
  /// Production [SessionNotificationService] — wraps a
  /// [`FlutterLocalNotificationsAdapter`] around the
  /// [`FlutterLocalNotificationsPlugin`] singleton.
  ///
  /// `keepAlive: true` — the Android notification channel is a
  /// process-long singleton; re-creating the service on every consumer
  /// subscription would be wasted work with no observable benefit.
  SessionNotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionNotificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionNotificationServiceHash();

  @$internal
  @override
  $ProviderElement<SessionNotificationService> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  SessionNotificationService create(Ref ref) {
    return sessionNotificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionNotificationService value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<SessionNotificationService>(value));
  }
}

String _$sessionNotificationServiceHash() => r'fa2ae76b5de9f57b9892608baef6c4a9aa073269';

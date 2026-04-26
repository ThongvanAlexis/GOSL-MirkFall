// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_queue_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// UI-layer wrapper around [PmtilesDownloadController].
///
/// The infrastructure controller is deliberately non-Riverpod
/// (07-04-SUMMARY decision: plain Dart class so unit tests drive it
/// without a `ProviderContainer`). This wrapper exposes a presentation-
/// friendly surface — `enqueue` / `pause` / `resume` / `cancelActive`
/// plus an `aggregateProgressFraction` getter for the AppBar chip in
/// Plan 07-06 — and hides the infrastructure module from screens (the
/// architectural invariant from Phase 07 §CONTEXT).
///
/// Lifecycle:
/// - `keepAlive: true` — downloads must survive screen navigation.
/// - On first use, `rehydrate()` on the underlying controller is
///   triggered so any queue persisted from a prior session resumes.
///
/// State stream: exposes the infra controller's broadcast stream
/// verbatim; consumers pattern-match over the 7 `DownloadState`
/// variants for UI rendering. `current` returns the latest snapshot.

@ProviderFor(DownloadQueueController)
final downloadQueueControllerProvider = DownloadQueueControllerProvider._();

/// UI-layer wrapper around [PmtilesDownloadController].
///
/// The infrastructure controller is deliberately non-Riverpod
/// (07-04-SUMMARY decision: plain Dart class so unit tests drive it
/// without a `ProviderContainer`). This wrapper exposes a presentation-
/// friendly surface — `enqueue` / `pause` / `resume` / `cancelActive`
/// plus an `aggregateProgressFraction` getter for the AppBar chip in
/// Plan 07-06 — and hides the infrastructure module from screens (the
/// architectural invariant from Phase 07 §CONTEXT).
///
/// Lifecycle:
/// - `keepAlive: true` — downloads must survive screen navigation.
/// - On first use, `rehydrate()` on the underlying controller is
///   triggered so any queue persisted from a prior session resumes.
///
/// State stream: exposes the infra controller's broadcast stream
/// verbatim; consumers pattern-match over the 7 `DownloadState`
/// variants for UI rendering. `current` returns the latest snapshot.
final class DownloadQueueControllerProvider extends $NotifierProvider<DownloadQueueController, DownloadState> {
  /// UI-layer wrapper around [PmtilesDownloadController].
  ///
  /// The infrastructure controller is deliberately non-Riverpod
  /// (07-04-SUMMARY decision: plain Dart class so unit tests drive it
  /// without a `ProviderContainer`). This wrapper exposes a presentation-
  /// friendly surface — `enqueue` / `pause` / `resume` / `cancelActive`
  /// plus an `aggregateProgressFraction` getter for the AppBar chip in
  /// Plan 07-06 — and hides the infrastructure module from screens (the
  /// architectural invariant from Phase 07 §CONTEXT).
  ///
  /// Lifecycle:
  /// - `keepAlive: true` — downloads must survive screen navigation.
  /// - On first use, `rehydrate()` on the underlying controller is
  ///   triggered so any queue persisted from a prior session resumes.
  ///
  /// State stream: exposes the infra controller's broadcast stream
  /// verbatim; consumers pattern-match over the 7 `DownloadState`
  /// variants for UI rendering. `current` returns the latest snapshot.
  DownloadQueueControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadQueueControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadQueueControllerHash();

  @$internal
  @override
  DownloadQueueController create() => DownloadQueueController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadState value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<DownloadState>(value));
  }
}

String _$downloadQueueControllerHash() => r'ac2d8284d9f89dc47046e6ba68169169a8374797';

/// UI-layer wrapper around [PmtilesDownloadController].
///
/// The infrastructure controller is deliberately non-Riverpod
/// (07-04-SUMMARY decision: plain Dart class so unit tests drive it
/// without a `ProviderContainer`). This wrapper exposes a presentation-
/// friendly surface — `enqueue` / `pause` / `resume` / `cancelActive`
/// plus an `aggregateProgressFraction` getter for the AppBar chip in
/// Plan 07-06 — and hides the infrastructure module from screens (the
/// architectural invariant from Phase 07 §CONTEXT).
///
/// Lifecycle:
/// - `keepAlive: true` — downloads must survive screen navigation.
/// - On first use, `rehydrate()` on the underlying controller is
///   triggered so any queue persisted from a prior session resumes.
///
/// State stream: exposes the infra controller's broadcast stream
/// verbatim; consumers pattern-match over the 7 `DownloadState`
/// variants for UI rendering. `current` returns the latest snapshot.

abstract class _$DownloadQueueController extends $Notifier<DownloadState> {
  DownloadState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DownloadState, DownloadState>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<DownloadState, DownloadState>, DownloadState, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

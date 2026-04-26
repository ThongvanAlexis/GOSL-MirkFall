// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discs_in_viewport_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Async provider returning the [RevealDisc]s of the currently active
/// session that intersect [viewport].
///
/// BUG-010 Option B (Commit 4) — replaces the consumer side of the
/// cell-bitmap pipeline. The renderers feed the returned list to
/// [RevealedSdfBuilder.buildFromDiscs] (continuous-geometry SDF) instead
/// of the per-tile bitmap rasterisation that fed [RevealedSdfBuilder.build].
///
/// Empty list returned when:
///   * No session is active (`Idle` / `Starting`).
///   * The active-session sealed-state matches no `Tracking` variant.
///
/// `keepAlive: false` mirrors the prior `visibleMirkTilesProvider` policy:
/// the result is only meaningful while the overlay is mounted; tearing
/// down the slot when the consumer goes away avoids stale state surviving
/// across screen pushes.

@ProviderFor(discsInViewport)
final discsInViewportProvider = DiscsInViewportFamily._();

/// Async provider returning the [RevealDisc]s of the currently active
/// session that intersect [viewport].
///
/// BUG-010 Option B (Commit 4) — replaces the consumer side of the
/// cell-bitmap pipeline. The renderers feed the returned list to
/// [RevealedSdfBuilder.buildFromDiscs] (continuous-geometry SDF) instead
/// of the per-tile bitmap rasterisation that fed [RevealedSdfBuilder.build].
///
/// Empty list returned when:
///   * No session is active (`Idle` / `Starting`).
///   * The active-session sealed-state matches no `Tracking` variant.
///
/// `keepAlive: false` mirrors the prior `visibleMirkTilesProvider` policy:
/// the result is only meaningful while the overlay is mounted; tearing
/// down the slot when the consumer goes away avoids stale state surviving
/// across screen pushes.

final class DiscsInViewportProvider extends $FunctionalProvider<AsyncValue<List<RevealDisc>>, List<RevealDisc>, FutureOr<List<RevealDisc>>>
    with $FutureModifier<List<RevealDisc>>, $FutureProvider<List<RevealDisc>> {
  /// Async provider returning the [RevealDisc]s of the currently active
  /// session that intersect [viewport].
  ///
  /// BUG-010 Option B (Commit 4) — replaces the consumer side of the
  /// cell-bitmap pipeline. The renderers feed the returned list to
  /// [RevealedSdfBuilder.buildFromDiscs] (continuous-geometry SDF) instead
  /// of the per-tile bitmap rasterisation that fed [RevealedSdfBuilder.build].
  ///
  /// Empty list returned when:
  ///   * No session is active (`Idle` / `Starting`).
  ///   * The active-session sealed-state matches no `Tracking` variant.
  ///
  /// `keepAlive: false` mirrors the prior `visibleMirkTilesProvider` policy:
  /// the result is only meaningful while the overlay is mounted; tearing
  /// down the slot when the consumer goes away avoids stale state surviving
  /// across screen pushes.
  DiscsInViewportProvider._({required DiscsInViewportFamily super.from, required MirkViewportBbox super.argument})
    : super(retry: null, name: r'discsInViewportProvider', isAutoDispose: true, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$discsInViewportHash();

  @override
  String toString() {
    return r'discsInViewportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RevealDisc>> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RevealDisc>> create(Ref ref) {
    final argument = this.argument as MirkViewportBbox;
    return discsInViewport(ref, viewport: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DiscsInViewportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$discsInViewportHash() => r'1b24d2f1b80699f6290c7dc8b1ac595709e21088';

/// Async provider returning the [RevealDisc]s of the currently active
/// session that intersect [viewport].
///
/// BUG-010 Option B (Commit 4) — replaces the consumer side of the
/// cell-bitmap pipeline. The renderers feed the returned list to
/// [RevealedSdfBuilder.buildFromDiscs] (continuous-geometry SDF) instead
/// of the per-tile bitmap rasterisation that fed [RevealedSdfBuilder.build].
///
/// Empty list returned when:
///   * No session is active (`Idle` / `Starting`).
///   * The active-session sealed-state matches no `Tracking` variant.
///
/// `keepAlive: false` mirrors the prior `visibleMirkTilesProvider` policy:
/// the result is only meaningful while the overlay is mounted; tearing
/// down the slot when the consumer goes away avoids stale state surviving
/// across screen pushes.

final class DiscsInViewportFamily extends $Family with $FunctionalFamilyOverride<FutureOr<List<RevealDisc>>, MirkViewportBbox> {
  DiscsInViewportFamily._() : super(retry: null, name: r'discsInViewportProvider', dependencies: null, $allTransitiveDependencies: null, isAutoDispose: true);

  /// Async provider returning the [RevealDisc]s of the currently active
  /// session that intersect [viewport].
  ///
  /// BUG-010 Option B (Commit 4) — replaces the consumer side of the
  /// cell-bitmap pipeline. The renderers feed the returned list to
  /// [RevealedSdfBuilder.buildFromDiscs] (continuous-geometry SDF) instead
  /// of the per-tile bitmap rasterisation that fed [RevealedSdfBuilder.build].
  ///
  /// Empty list returned when:
  ///   * No session is active (`Idle` / `Starting`).
  ///   * The active-session sealed-state matches no `Tracking` variant.
  ///
  /// `keepAlive: false` mirrors the prior `visibleMirkTilesProvider` policy:
  /// the result is only meaningful while the overlay is mounted; tearing
  /// down the slot when the consumer goes away avoids stale state surviving
  /// across screen pushes.

  DiscsInViewportProvider call({required MirkViewportBbox viewport}) => DiscsInViewportProvider._(argument: viewport, from: this);

  @override
  String toString() => r'discsInViewportProvider';
}

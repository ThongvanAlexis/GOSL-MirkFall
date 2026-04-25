// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'map_providers.dart';

part 'map_viewport_provider.g.dart';

/// Debounce window applied between a `viewportUpdates` emission and the
/// next [`MapView.queryViewportBounds`] call. The overlay's Ticker reads
/// `state` every paint pass, so a coarse publish cadence is enough — and
/// it avoids thrashing the MapLibre method channel during continuous
/// pinch / pan gestures.
const Duration _kViewportDebounce = Duration(milliseconds: 50);

/// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
/// until the MapView is ready and the first viewport bounds settle.
///
/// Subscribes to [MapView.viewportUpdates] and republishes the bounds
/// derived from [MapView.queryViewportBounds] on each settled camera
/// change. Debounced 50 ms — see [_kViewportDebounce].
///
/// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
/// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
///
/// `keepAlive: true` — bbox is a long-lived observable; tearing down the
/// subscription when the drawer closes would drop events during the gap
/// (same discipline as [`MapViewportZoom`]).
@Riverpod(keepAlive: true)
class MapViewport extends _$MapViewport {
  Timer? _debounce;
  StreamSubscription<({double latitude, double longitude, double zoom})>? _sub;

  @override
  MirkViewportBbox? build() {
    final MapView? view = ref.watch(mapViewProvider);
    if (view == null) return null;

    _sub = view.viewportUpdates.listen(
      (_) => _scheduleRefresh(view),
      onError: (Object _, StackTrace _) {
        // Phase 07 convention (mirrors [`MapViewportZoom`]): viewport
        // stream errors are transient MapLibre callback ordering glitches.
        // Silently drop; the next successful update rewrites state.
      },
    );
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
    });

    // Seed once on first build (mirror MapViewportZoom pattern). Async
    // read is safe: if the adapter is disposed before the future
    // completes, the `state =` assignment hits a disposed notifier and
    // Riverpod's own guard short-circuits — no exception surfaces.
    unawaited(_refreshNow(view));
    return null;
  }

  void _scheduleRefresh(MapView view) {
    _debounce?.cancel();
    _debounce = Timer(_kViewportDebounce, () => _refreshNow(view));
  }

  Future<void> _refreshNow(MapView view) async {
    try {
      final bbox = await view.queryViewportBounds();
      state = bbox;
    } on Object {
      // queryViewportBounds can throw before MapLibre's surface loads
      // (or on a disposed adapter). Benign — the next viewportUpdates
      // emission retries.
    }
  }
}

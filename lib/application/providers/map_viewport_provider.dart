// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'map_providers.dart';

part 'map_viewport_provider.g.dart';

/// Maximum cadence at which [`MapView.queryViewportBounds`] is invoked
/// during a continuous gesture. The provider runs a leading-edge throttle:
/// the first emission of a burst fires `queryViewportBounds` immediately,
/// subsequent emissions inside the window are coalesced into ONE trailing
/// refresh that fires once the window expires. This keeps the bbox in
/// near-realtime sync with pan / pinch / zoom gestures (BUG-005,
/// 2026-04-25) while still capping MapLibre method-channel pressure.
///
/// 50 ms = 20 Hz, comfortably below the overlay's 60 Hz Ticker so the
/// painter always reads a fresh-enough bbox without thrashing the
/// platform call.
const Duration _kViewportThrottleWindow = Duration(milliseconds: 50);

/// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
/// until the MapView is ready and the first viewport bounds settle.
///
/// Subscribes to [MapView.viewportUpdates] and republishes the bounds
/// derived from [MapView.queryViewportBounds] on each camera change.
///
/// ## Throttling — leading edge + trailing tail
///
/// `viewportUpdates` fires continuously during pan / pinch / zoom (every
/// `notifyListeners()` from the MapLibre controller). The naive shape
/// would call `queryViewportBounds` on every emission — too many
/// platform-channel round-trips. The earlier debounce shape (50 ms quiet
/// window before any refresh) had the opposite failure mode: during a
/// continuous gesture each emission RESET the timer, so the bbox was
/// only refreshed AFTER the gesture ended (the user observed the fog
/// snapping into place at gesture release rather than tracking the
/// pan in realtime — BUG-005, 2026-04-25).
///
/// The throttle here:
///  - **Leading edge** — first emission of a burst fires immediately. The
///    overlay sees the new bbox within one frame.
///  - **In-window emissions** — set a "trailing pending" flag. Do not
///    fire `queryViewportBounds`.
///  - **Window expiry** — if the trailing flag is set, fire a refresh
///    capturing whatever the camera state is now, and start a new
///    window. Otherwise idle.
///
/// Net effect: during continuous panning the bbox refreshes at ~20 Hz
/// (one leading + one trailing per window), and the LAST update of any
/// gesture is always captured.
///
/// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
/// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
///
/// `keepAlive: true` — bbox is a long-lived observable; tearing down the
/// subscription when the drawer closes would drop events during the gap
/// (same discipline as [`MapViewportZoom`]).
@Riverpod(keepAlive: true)
class MapViewport extends _$MapViewport {
  Timer? _throttleTimer;
  bool _trailingPending = false;
  StreamSubscription<({double latitude, double longitude, double zoom})>? _sub;

  @override
  MirkViewportBbox? build() {
    final MapView? view = ref.watch(mapViewProvider);
    if (view == null) return null;

    _sub = view.viewportUpdates.listen(
      (_) => _onEmission(view),
      onError: (Object _, StackTrace _) {
        // Phase 07 convention (mirrors [`MapViewportZoom`]): viewport
        // stream errors are transient MapLibre callback ordering glitches.
        // Silently drop; the next successful update rewrites state.
      },
    );
    ref.onDispose(() {
      _sub?.cancel();
      _throttleTimer?.cancel();
    });

    // Seed once on first build (mirror MapViewportZoom pattern). Async
    // read is safe: if the adapter is disposed before the future
    // completes, the `state =` assignment hits a disposed notifier and
    // Riverpod's own guard short-circuits — no exception surfaces.
    unawaited(_refreshNow(view));
    return null;
  }

  /// Handles one [`MapView.viewportUpdates`] emission. Implements the
  /// leading-edge + trailing-tail throttle described on the class
  /// docstring.
  void _onEmission(MapView view) {
    if (_throttleTimer == null) {
      // Leading edge — no window currently active. Refresh immediately
      // and open a new window during which subsequent emissions are
      // coalesced into one trailing refresh.
      unawaited(_refreshNow(view));
      _throttleTimer = Timer(_kViewportThrottleWindow, () => _onWindowExpired(view));
      return;
    }
    // Inside an active window — flag a trailing refresh; the timer will
    // fire it at window expiry.
    _trailingPending = true;
  }

  /// Called when the throttle window timer expires. Fires a trailing
  /// refresh if any emission happened during the window, then either
  /// closes the throttle (no trailing) or chains another window
  /// (trailing fired — open another window so a continuing gesture
  /// keeps refreshing at the throttle cadence rather than dropping back
  /// to the leading-edge path which would over-fire on the very next
  /// emission).
  void _onWindowExpired(MapView view) {
    _throttleTimer = null;
    if (!_trailingPending) return;
    _trailingPending = false;
    unawaited(_refreshNow(view));
    // Continuing gesture — open a fresh window so we cap the cadence at
    // 1 / window for the remainder of the burst.
    _throttleTimer = Timer(_kViewportThrottleWindow, () => _onWindowExpired(view));
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

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';

/// Fades the initial 20 m reveal from opacity 0 to 1 over
/// [`kInitialRevealFadeInMs`] (500 ms) at session start.
///
/// Uses a dedicated `AnimationController`, decoupled from the main
/// [`MirkOverlay`] Ticker — the fade is a one-shot session-open
/// animation tied to [`ActiveSessionController`] entering `Tracking`
/// (research §In-Session Style Swap Lifecycle). Coupling the fade
/// duration to the noise tick frequency would be the wrong abstraction.
///
/// Trigger:
/// * `activeSessionControllerProvider` state transitions from a
///   non-tracking state to `Tracking` → forward play.
/// * Session ends (state leaves `Tracking`) → reset opacity to 0 so
///   the next session re-fires the fade.
///
/// Idempotence: the fade runs at most once per session — guarded by
/// the [_hasFadedIn] bool which flips `false` again on the way out.
class MirkInitialRevealFade extends ConsumerStatefulWidget {
  const MirkInitialRevealFade({super.key, required this.child});

  /// Wrapped widget — typically the [`MirkOverlay`].
  final Widget child;

  @override
  ConsumerState<MirkInitialRevealFade> createState() =>
      _MirkInitialRevealFadeState();
}

class _MirkInitialRevealFadeState extends ConsumerState<MirkInitialRevealFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  /// Idempotence guard — set to true once the fade-in has fired for
  /// the current Tracking session, reset to false when the session
  /// ends. Without this guard a non-fix-related Tracking state update
  /// (e.g. `lastFix` arriving) would replay the fade every time.
  bool _hasFadedIn = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kInitialRevealFadeInMs),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    // Listen to provider via ref.listen — defers state mutations to a
    // safe phase (avoids "modified during build" Riverpod errors).
    ref.listenManual<AsyncValue<ActiveSessionState>>(
      activeSessionControllerProvider,
      (previous, next) => _onStateChange(next),
      fireImmediately: true,
    );
  }

  void _onStateChange(AsyncValue<ActiveSessionState> next) {
    final state = next.value;
    final isTracking = state is Tracking;
    if (isTracking && !_hasFadedIn) {
      _hasFadedIn = true;
      _controller.forward(from: 0.0);
      return;
    }
    if (!isTracking && _hasFadedIn) {
      _controller.value = 0.0;
      _hasFadedIn = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

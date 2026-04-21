// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_session_banner.dart';

/// Chrome that wraps every route so [ActiveSessionBanner] injects into
/// every screen consistently.
///
/// Route-level suppression is handled by [currentLocation] — when the
/// shell sits on top of `/sessions/:id`, the banner is hidden because
/// the detail screen already surfaces the full tracking dashboard.
/// Decoupling the predicate from the banner itself keeps the widget
/// reusable for any future route that also needs suppression (e.g. a
/// Phase 09 "tracking setup" flow).
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.currentLocation, super.key});

  /// Route body to display below the banner.
  final Widget child;

  /// Current location string, as reported by `go_router`'s
  /// `GoRouterState.uri.path`. Used to decide whether the banner should
  /// be shown — the detail screen (`/sessions/:id`) hides it.
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `/map` is full-screen by design — the burger menu + follow-me FAB
    // replace the cross-route banner's Stop affordance.
    final bool hideBanner = currentLocation.startsWith('/sessions/') || currentLocation == '/map';
    return Column(
      children: <Widget>[
        if (!hideBanner) const ActiveSessionBanner(),
        Expanded(child: child),
      ],
    );
  }
}

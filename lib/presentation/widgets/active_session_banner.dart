// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';

/// Cross-route active-session indicator.
///
/// Renders a slim 40dp bar at the top of every shell route EXCEPT
/// `/sessions/:id` (the detail screen already surfaces tracking status
/// dashboard-style). Shown only when
/// [`activeSessionControllerProvider`](../../application/controllers/active_session_controller.dart)
/// is in the [`Tracking`] state; all other states render
/// [`SizedBox.shrink()`] so the layout does not reserve visual space.
///
/// Tap-anywhere navigates to `/sessions/:id` for the active session.
/// The inline stop icon short-circuits the navigation and invokes
/// [`ActiveSessionController.stop`] directly — matches the user
/// expectation that a small Stop affordance in a banner lets you kill
/// tracking without a detour through the detail screen.
class ActiveSessionBanner extends ConsumerWidget {
  const ActiveSessionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(activeSessionControllerProvider);
    final state = asyncState.value;
    if (state is! Tracking) {
      return const SizedBox.shrink();
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: kSessionActiveBannerHeightDp,
      child: Material(
        color: colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: <Widget>[
              Expanded(
                // Tap area for the title portion navigates to the
                // detail route. Kept as an explicit inner InkWell
                // (not wrapping the whole Row) so the adjacent Stop
                // [IconButton] receives its own taps without
                // competing with an ancestor InkWell's gesture
                // handler. CLAUDE.md §is-checks / separation of
                // responsibilities: each widget owns one action.
                child: InkWell(
                  onTap: () => context.go('/sessions/${state.sessionId.value}'),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.gps_fixed, size: 18.0, color: colorScheme.onTertiaryContainer),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          'Session active',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Arrêter la session',
                icon: Icon(Icons.stop_circle_outlined, color: colorScheme.onTertiaryContainer),
                iconSize: 22.0,
                onPressed: () async {
                  await ref.read(activeSessionControllerProvider.notifier).stop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

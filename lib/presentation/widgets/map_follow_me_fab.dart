// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';

/// Material FAB that toggles the map's follow-me camera mode.
///
/// Colour tint reflects the current [MapCameraState]:
/// - [MapCameraFollowing] with a first fix → primary colour (follow-me active)
/// - Any other state → secondary colour (follow-me inactive / unavailable)
///
/// Tap delegates to [MapCameraController.toggleFollowMe] when follow-me
/// can actually toggle. When the state is [MapCameraIdle] (no session
/// active on /map) or [MapCameraFollowing] still waiting on the first
/// GPS fix (`hasFirstFix: false`), toggling silently no-ops at the
/// controller level — the FAB surfaces a snackbar instead so the user
/// gets immediate feedback that the button is recognised but inert.
class MapFollowMeFab extends ConsumerWidget {
  const MapFollowMeFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MapCameraState state = ref.watch(mapCameraControllerProvider);
    // "Actively following" = Following with a fix. The pre-first-fix
    // flavour (hasFirstFix: false) paints inactive so the user sees
    // the FAB is recognised but not yet auto-panning.
    final bool isActivelyFollowing = state is MapCameraFollowing && state.hasFirstFix;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      heroTag: 'map_follow_me_fab',
      tooltip: isActivelyFollowing ? 'Quitter le suivi' : 'Me suivre',
      backgroundColor: isActivelyFollowing ? cs.primary : cs.secondaryContainer,
      foregroundColor: isActivelyFollowing ? cs.onPrimary : cs.onSecondaryContainer,
      onPressed: () async {
        final MapCameraState currentState = ref.read(mapCameraControllerProvider);
        // Phase 08.1-REVIEW §3 row #10 (Could). Pattern-match on
        // `hasFirstFix` directly rather than the derived `isCentering`
        // getter; keeping the discrimination at the sealed-variant
        // field level scales cleanly if a third following-semantic
        // lands (e.g. "stale fix") — that future variant would add a
        // field, not a getter that has to be re-fanned-out here.
        final String? ineligibleReason = switch (currentState) {
          MapCameraIdle() => 'Démarre une session pour activer le centrage GPS',
          MapCameraFollowing(hasFirstFix: false) => 'En attente du premier fix GPS…',
          MapCameraFollowing() || MapCameraFreePan() => null,
        };
        if (ineligibleReason != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ineligibleReason), duration: const Duration(seconds: 2)));
          return;
        }
        await ref.read(mapCameraControllerProvider.notifier).toggleFollowMe();
      },
      child: Icon(isActivelyFollowing ? Icons.gps_fixed : Icons.gps_not_fixed),
    );
  }
}

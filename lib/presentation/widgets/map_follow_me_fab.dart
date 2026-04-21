// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';

/// Material FAB that toggles the map's follow-me camera mode.
///
/// Colour tint reflects the current [MapCameraState]:
/// - [MapCameraFollowing] → primary colour (follow-me active)
/// - Any other state → secondary colour (follow-me inactive / unavailable)
///
/// Tap delegates to [MapCameraController.toggleFollowMe] when the state
/// is [MapCameraFollowing] or [MapCameraFreePan]. When the state is
/// [MapCameraIdle] (no session active on /map) or [MapCameraCentering]
/// (awaiting the first GPS fix), toggling silently no-ops at the
/// controller level — the FAB surfaces a snackbar instead so the user
/// gets immediate feedback that the button is recognised but inert.
class MapFollowMeFab extends ConsumerWidget {
  const MapFollowMeFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MapCameraState state = ref.watch(mapCameraControllerProvider);
    final bool isFollowing = state is MapCameraFollowing;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      heroTag: 'map_follow_me_fab',
      tooltip: isFollowing ? 'Quitter le suivi' : 'Me suivre',
      backgroundColor: isFollowing ? cs.primary : cs.secondaryContainer,
      foregroundColor: isFollowing ? cs.onPrimary : cs.onSecondaryContainer,
      onPressed: () async {
        final MapCameraState currentState = ref.read(mapCameraControllerProvider);
        final String? ineligibleReason = switch (currentState) {
          MapCameraIdle() => 'Démarre une session pour activer le centrage GPS',
          MapCameraCentering() => 'En attente du premier fix GPS…',
          MapCameraFollowing() || MapCameraFreePan() => null,
        };
        if (ineligibleReason != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ineligibleReason), duration: const Duration(seconds: 2)));
          return;
        }
        await ref.read(mapCameraControllerProvider.notifier).toggleFollowMe();
      },
      child: Icon(isFollowing ? Icons.gps_fixed : Icons.gps_not_fixed),
    );
  }
}

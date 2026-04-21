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
/// Tap delegates to [MapCameraController.toggleFollowMe] — the controller
/// owns the echo-filtering + state transition logic; this widget is pure
/// UI.
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
        await ref.read(mapCameraControllerProvider.notifier).toggleFollowMe();
      },
      child: Icon(isFollowing ? Icons.gps_fixed : Icons.gps_not_fixed),
    );
  }
}

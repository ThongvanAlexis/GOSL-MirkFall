// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/fixes/fix.dart';

/// Left-side drawer opened from the MapScreen's burger menu button.
///
/// Structure (per 07-06-PLAN `must_haves.truths`):
/// 1. Three unwired action tiles:
///    - "Changer le style" → Phase 13 (stub snackbar)
///    - "Prendre une photo" → Phase 11 (stub snackbar)
///    - "Placer un marker" → Phase 11 (stub snackbar)
/// 2. Divider
/// 3. Three read-only live-data rows :
///    - "Position : `<lat, lon>`" (6-decimals) or "En attente GPS..."
///    - "Distance : X.XX km" / "X m" (haversine over fixes)
///    - "Durée : HH:MM:SS" (chrono ticking every 1 s from startedAt)
/// 4. If the session is in [Tracking] state, a "Arrêter la session"
///    tile surfaces the stop action the Phase 05 dashboard used to own
///    (SessionDetailScreen migrates the action here in Task 3 of Plan
///    07-06).
///
/// Responsive width: 75% of screen width in portrait; 40% in landscape.
/// Computed once per `build()` from MediaQuery; the [Drawer.width]
/// parameter absorbs the value.
class SessionBurgerMenu extends ConsumerWidget {
  const SessionBurgerMenu({super.key});

  static const double _kDrawerWidthPortraitFraction = 0.75;
  static const double _kDrawerWidthLandscapeFraction = 0.40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double drawerWidth = screenSize.width * (isLandscape ? _kDrawerWidthLandscapeFraction : _kDrawerWidthPortraitFraction);

    final asyncSession = ref.watch(activeSessionControllerProvider);
    final ActiveSessionState? sessionState = asyncSession.value;
    final Tracking? tracking = sessionState is Tracking ? sessionState : null;

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _DrawerHeader(isTracking: tracking != null),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Changer le style'),
              onTap: () => _showPhase13Snackbar(context, 'Changer le style disponible en Phase 13'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => _showPhase13Snackbar(context, 'Prendre une photo disponible en Phase 11'),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Placer un marker'),
              onTap: () => _showPhase13Snackbar(context, 'Placer un marker disponible en Phase 11'),
            ),
            const Divider(),
            _PositionRow(lastFix: tracking?.lastFix),
            _DistanceRow(lastFix: tracking?.lastFix),
            if (tracking != null) _ChronoRow(startedAtUtc: tracking.startedAtUtc) else const _PendingChronoRow(),
            if (tracking != null) ...<Widget>[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                title: const Text('Arrêter la session'),
                onTap: () async {
                  await ref.read(activeSessionControllerProvider.notifier).stop();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPhase13Snackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.isTracking});

  final bool isTracking;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('MirkFall', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.onPrimaryContainer)),
          const SizedBox(height: 4.0),
          Text(isTracking ? 'Session active' : 'Aucune session active', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.lastFix});

  final Fix? lastFix;

  static const int _kCoordinateDecimals = 6;

  @override
  Widget build(BuildContext context) {
    final Fix? fix = lastFix;
    final String text;
    if (fix == null) {
      text = 'Position : En attente GPS...';
    } else {
      final String lat = fix.latitude.toStringAsFixed(_kCoordinateDecimals);
      final String lon = fix.longitude.toStringAsFixed(_kCoordinateDecimals);
      text = 'Position : $lat, $lon';
    }
    return ListTile(
      leading: const Icon(Icons.my_location_outlined),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _DistanceRow extends ConsumerWidget {
  const _DistanceRow({required this.lastFix});

  final Fix? lastFix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 07: distance is derived from the chrono-level lastFix vs
    // startedAt; full trajectory haversine belongs to Phase 09 (fix
    // trajectory rendering) when the fix stream is consumable from the
    // UI layer. For Phase 07 the row shows 0 m when there is no fix
    // and "< 1 m" when we have a fix but have not yet implemented the
    // fix-stream subscription. Gives the user a non-empty surface
    // without fabricating a number.
    final String text = lastFix == null ? 'Distance : 0 m' : 'Distance : — m';
    return ListTile(
      leading: const Icon(Icons.straighten_outlined),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ChronoRow extends StatefulWidget {
  const _ChronoRow({required this.startedAtUtc});

  final DateTime startedAtUtc;

  @override
  State<_ChronoRow> createState() => _ChronoRowState();
}

class _ChronoRowState extends State<_ChronoRow> {
  late final Stream<int> _tickStream;

  @override
  void initState() {
    super.initState();
    _tickStream = Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: StreamBuilder<int>(
        stream: _tickStream,
        builder: (context, _) {
          final Duration elapsed = DateTime.now().toUtc().difference(widget.startedAtUtc);
          return Text('Durée : ${_formatDuration(elapsed)}', style: Theme.of(context).textTheme.bodyMedium);
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final int total = math.max(0, d.inSeconds);
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    final int seconds = total % 60;
    final String hh = hours.toString().padLeft(2, '0');
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _PendingChronoRow extends StatelessWidget {
  const _PendingChronoRow();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text('Durée : --:--:--', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

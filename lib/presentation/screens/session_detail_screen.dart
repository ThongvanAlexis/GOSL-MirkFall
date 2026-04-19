// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/fix_store_provider.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/errors/concurrent_errors.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';

/// `/sessions/:id` — detail view for a single [Session].
///
/// Rendering splits on the live
/// [`activeSessionControllerProvider`](../../application/controllers/active_session_controller.dart)
/// state:
///
/// - [`Tracking`] for THIS session → status dashboard (chrono, fix
///   count, last fix, distance filter) + Stop button.
/// - Any other state (idle, tracking another session, error) → summary
///   card (name, started-at, duration, recorded fix count) + Start
///   button + Delete button. Delete is blocked when this session is
///   currently [SessionStatus.active] regardless of the controller
///   state (belt-and-suspenders against DB/controller desync).
///
/// Rename goes through the overflow menu and updates the store via
/// [Session.copyWith].
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final SessionId sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Session? _session;
  bool _loading = true;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final store = await ref.read(sessionStoreProvider.future);
      final Session? session = await store.findById(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _inlineError = 'Erreur : $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
    }
    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session introuvable')),
        body: Center(child: Text(_inlineError ?? "Cette session n'existe pas.")),
      );
    }

    final asyncState = ref.watch(activeSessionControllerProvider);
    final ActiveSessionState? controllerState = asyncState.value;
    final bool isTrackingThis = controllerState is Tracking && controllerState.sessionId == session.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (value) => _onMenuSelected(value, session: session, isTrackingThis: isTrackingThis),
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'rename', child: Text('Renommer')),
              const PopupMenuItem<String>(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
      body: isTrackingThis
          ? _TrackingDashboard(session: session, tracking: controllerState)
          : _StoppedSummary(session: session, inlineError: _inlineError, onStart: () => _handleStart(session), onDelete: () => _handleDelete(session)),
    );
  }

  Future<void> _onMenuSelected(String value, {required Session session, required bool isTrackingThis}) async {
    if (value == 'rename') {
      await _handleRename(session);
    } else if (value == 'delete') {
      await _handleDelete(session);
    }
  }

  Future<void> _handleRename(Session session) async {
    final controller = TextEditingController(text: session.displayName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renommer la session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    // Defer dispose() to the next frame: the dialog's close animation
    // (AnimatedDefaultTextStyle / Material fade) still reads from the
    // TextField's controller during the out-transition. Disposing
    // immediately triggers "TextEditingController used after dispose"
    // assertions in widget tests. A single-frame deferral is enough —
    // the animation completes before the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (!mounted) return;
    if (newName == null || newName.isEmpty || newName == session.displayName) return;

    try {
      final store = await ref.read(sessionStoreProvider.future);
      if (!mounted) return;
      final updated = session.copyWith(displayName: newName);
      await store.update(updated);
      if (!mounted) return;
      setState(() => _session = updated);
    } catch (err) {
      if (!mounted) return;
      setState(() => _inlineError = 'Erreur au renommage : $err');
    }
  }

  Future<void> _handleDelete(Session session) async {
    if (session.status == SessionStatus.active) {
      setState(() => _inlineError = "Arrête la session d'abord avant de la supprimer.");
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la session ?'),
        content: const Text('Cette action est définitive — les fixes attachés seront supprimés.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm != true) return;

    try {
      final store = await ref.read(sessionStoreProvider.future);
      if (!mounted) return;
      await store.delete(session.id);
      if (!mounted) return;
      context.go('/');
    } catch (err) {
      if (!mounted) return;
      setState(() => _inlineError = 'Erreur à la suppression : $err');
    }
  }

  Future<void> _handleStart(Session session) async {
    setState(() => _inlineError = null);
    try {
      final settings = await ref.read(sessionSettingsProvider.future);
      if (!mounted) return;

      if (!settings.permissionFlowCompleted) {
        final result = await GoRouter.of(context).push<bool>('/permissions/rationale');
        if (!mounted) return;
        if (result != true) return;
      }

      try {
        await ref.read(activeSessionControllerProvider.notifier).start(session.id);
      } on ConcurrentActivationException {
        if (!mounted) return;
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Une session est déjà active'),
            content: const Text("Arrêter la session en cours et démarrer celle-ci à la place ?"),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Stop et Start')),
            ],
          ),
        );
        if (!mounted) return;
        if (confirm != true) return;
        await ref.read(activeSessionControllerProvider.notifier).stop();
        if (!mounted) return;
        await ref.read(activeSessionControllerProvider.notifier).start(session.id);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _inlineError = 'Erreur au démarrage : $err');
    }
  }
}

/// Live status dashboard for an active session — the render path taken
/// when [`Tracking`] state refers to THIS session.
class _TrackingDashboard extends ConsumerWidget {
  const _TrackingDashboard({required this.session, required this.tracking});

  final Session session;
  final Tracking tracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ChronoCard(startedAtUtc: tracking.startedAtUtc),
          const SizedBox(height: 12.0),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Filtre de distance : ${tracking.distanceFilterMeters} m', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8.0),
                  Text('Fixes enregistrés : ${tracking.fixCount}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12.0),
                  _LastFixBlock(lastFix: tracking.lastFix),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () async {
              await ref.read(activeSessionControllerProvider.notifier).stop();
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Arrêter'),
          ),
        ],
      ),
    );
  }
}

/// Chrono that ticks once per second based on `Stream.periodic`.
///
/// Extracted so rebuilds on the 1-Hz tick do NOT force the whole
/// dashboard back through `build()`.
class _ChronoCard extends StatefulWidget {
  const _ChronoCard({required this.startedAtUtc});

  final DateTime startedAtUtc;

  @override
  State<_ChronoCard> createState() => _ChronoCardState();
}

class _ChronoCardState extends State<_ChronoCard> {
  late final Stream<int> _tickStream;

  @override
  void initState() {
    super.initState();
    _tickStream = Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: StreamBuilder<int>(
          stream: _tickStream,
          builder: (context, _) {
            final Duration elapsed = DateTime.now().toUtc().difference(widget.startedAtUtc);
            return Column(
              children: <Widget>[
                Text('Durée', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4.0),
                Text(_formatDuration(elapsed), style: Theme.of(context).textTheme.displaySmall),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final int total = d.isNegative ? 0 : d.inSeconds;
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    final int seconds = total % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final String hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }
}

class _LastFixBlock extends StatelessWidget {
  const _LastFixBlock({required this.lastFix});

  final Fix? lastFix;

  @override
  Widget build(BuildContext context) {
    final fix = lastFix;
    if (fix == null) {
      return Text("En attente du premier fix…", style: Theme.of(context).textTheme.bodyMedium);
    }
    final String coords = '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}';
    final String acc = '± ${fix.accuracyMeters.toStringAsFixed(1)} m';
    final DateTime ts = fix.recordedAtUtc.toUtc();
    final String hms = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')} UTC';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Dernier fix', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4.0),
        Text(coords, style: Theme.of(context).textTheme.bodyMedium),
        Text('$acc · $hms', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Summary + Start/Delete controls for a stopped session.
class _StoppedSummary extends ConsumerWidget {
  const _StoppedSummary({required this.session, required this.onStart, required this.onDelete, this.inlineError});

  final Session session;
  final Future<void> Function() onStart;
  final Future<void> Function() onDelete;
  final String? inlineError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFixCount = ref.watch(_sessionFixCountProvider(session.id));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(session.displayName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8.0),
                  Text('Commencée : ${session.startedAtUtc.toUtc()}', style: Theme.of(context).textTheme.bodyMedium),
                  if (session.stoppedAtUtc != null) Text('Arrêtée : ${session.stoppedAtUtc!.toUtc()}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12.0),
                  asyncFixCount.when(
                    loading: () => const Text('Fixes : …'),
                    error: (err, st) => Text('Fixes : erreur ($err)'),
                    data: (count) => Text('Fixes : $count'),
                  ),
                ],
              ),
            ),
          ),
          if (inlineError != null) ...<Widget>[const SizedBox(height: 12.0), Text(inlineError!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          const Spacer(),
          FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow_outlined), label: const Text('Démarrer')),
          const SizedBox(height: 8.0),
          OutlinedButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Supprimer')),
        ],
      ),
    );
  }
}

/// Per-session fix count — bridges [fixStoreProvider] to
/// [FixStore.countBySession] as a family-keyed FutureProvider so the
/// summary card hydrates without blocking the initial frame.
final _sessionFixCountProvider = FutureProvider.autoDispose.family<int, SessionId>((ref, sessionId) async {
  final store = await ref.watch(fixStoreProvider.future);
  return store.countBySession(sessionId);
});

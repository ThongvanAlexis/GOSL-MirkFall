// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/providers/id_generator_provider.dart';
import 'package:mirkfall/application/providers/session_list_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';

/// Home route (`/`) — lists every existing [Session] in DESC order of
/// [Session.startedAtUtc] and exposes two entry points:
///
/// 1. The `+` FAB opens the create-session dialog (name input + choice
///    between "Créer" and "Créer et démarrer").
/// 2. Tapping a row navigates to `/sessions/:id`.
///
/// The list emits on every row change via [sessionListProvider] which
/// wraps `SessionStore.watchAll()` (SESS-08 live-refresh requirement).
/// Empty state surfaces a CTA "Créer ma première session" routed
/// through the same create flow.
class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes sessions'),
        actions: <Widget>[
          // Phase 07 (map-integration): open the map directly when the
          // user has at least one session. The button is conditional on
          // the AsyncValue data — when the list is empty (or loading),
          // the map entry is hidden to keep the first-run funnel focused
          // on creating the first session.
          if (asyncSessions.value?.isNotEmpty ?? false)
            IconButton(tooltip: 'Ouvrir la carte', icon: const Icon(Icons.map_outlined), onPressed: () => context.push('/map')),
          IconButton(tooltip: 'Paramètres', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      floatingActionButton: FloatingActionButton(tooltip: 'Créer une session', onPressed: () => _openCreateDialog(context, ref), child: const Icon(Icons.add)),
      body: asyncSessions.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Erreur lors du chargement des sessions : $err', textAlign: TextAlign.center),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return _EmptyState(onCreate: () => _openCreateDialog(context, ref));
          }
          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const Divider(height: 1.0),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionTile(session: session);
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    // Dialog returns its intent (newly-created session id + whether the
    // user tapped "Créer et démarrer"). The post-dialog flow (navigate
    // to detail, optionally auto-start) happens AFTER the dialog has
    // popped, so that the permission rationale / OS permission dialogs
    // do not fire under the modal barrier of a still-open dialog (the
    // bug this refactor fixes: showDialog uses the app Overlay which
    // renders ABOVE the Navigator, so any route pushed during the
    // dialog was invisible and the user had to dismiss the dialog by
    // tapping the barrier before anything else could surface).
    final _CreateDialogResult? result = await showDialog<_CreateDialogResult>(context: context, builder: (dialogContext) => const _CreateSessionDialog());
    if (result == null) return;
    if (!context.mounted) return;
    final String path = '/sessions/${result.sessionId.value}';
    context.push(result.startImmediately ? '$path?start=true' : path);
  }
}

/// What the create dialog returns when the user submits. The dialog
/// itself is a pure form: it creates the DB row and hands this intent
/// back to the caller. Navigation and session start happen in the
/// caller's context AFTER the dialog has popped.
class _CreateDialogResult {
  const _CreateDialogResult({required this.sessionId, required this.startImmediately});

  final SessionId sessionId;
  final bool startImmediately;
}

/// Empty-state body shown when [sessionListProvider] returns an empty
/// list. Hoisted as a private widget so `SessionListScreen.build` stays
/// a single AsyncValue.when arm per CLAUDE.md §build < ~50 lines guidance.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.explore_off_outlined, size: 64.0, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 16.0),
            const Text(
              "Aucune session pour l'instant",
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              'Crée ta première session pour commencer à révéler le brouillard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24.0),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Créer ma première session')),
          ],
        ),
      ),
    );
  }
}

/// Row representation of a [Session] in the list. Shows `displayName`,
/// the start timestamp, and an "active" badge when the status is
/// [SessionStatus.active]. Tap navigates to `/sessions/:id`.
class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final bool isActive = session.status == SessionStatus.active;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String subtitle = _formatSubtitle(session, isActive: isActive);

    return ListTile(
      leading: Icon(isActive ? Icons.radio_button_checked : Icons.radio_button_off, color: isActive ? cs.primary : cs.onSurfaceVariant),
      title: Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/sessions/${session.id.value}'),
    );
  }

  /// Format `startedAtUtc` as `YYYY-MM-DD HH:MM` plus an inline `• active`
  /// marker when relevant. Kept as a pure helper so the widget's `build`
  /// body is rebuild-cheap.
  String _formatSubtitle(Session session, {required bool isActive}) {
    final DateTime started = session.startedAtUtc.toUtc();
    final String ymd =
        '${started.year.toString().padLeft(4, '0')}-'
        '${started.month.toString().padLeft(2, '0')}-'
        '${started.day.toString().padLeft(2, '0')}';
    final String hms =
        '${started.hour.toString().padLeft(2, '0')}:'
        '${started.minute.toString().padLeft(2, '0')}';
    final String base = '$ymd $hms UTC';
    return isActive ? '$base • active' : base;
  }
}

/// Dialog used by both the FAB and the empty-state CTA. Two distinct
/// confirmation buttons:
/// - "Créer" — insert the session row as `stopped`, user starts it
///   later from the detail screen.
/// - "Créer et démarrer" — insert + immediately kick off the
///   permission-flow-gated start. Any permission deviation bounces to
///   `/permissions/rationale`; a `ConcurrentActivationException` falls
///   back to a confirm dialog handled in the detail screen (SESS-06).
///
/// The dialog stays a local `StatefulWidget` so the [TextField]
/// controller can live with it rather than polluting the list screen.
class _CreateSessionDialog extends ConsumerStatefulWidget {
  const _CreateSessionDialog();

  @override
  ConsumerState<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<_CreateSessionDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Nom de la session', errorText: _errorText, hintText: 'Ex. Balade dimanche'),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _errorText = null),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        TextButton(onPressed: _busy ? null : () => _submit(startImmediately: false), child: const Text('Créer')),
        FilledButton(onPressed: _busy ? null : () => _submit(startImmediately: true), child: const Text('Créer et démarrer')),
      ],
    );
  }

  Future<void> _submit({required bool startImmediately}) async {
    final String name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Le nom ne peut pas être vide');
      return;
    }

    setState(() => _busy = true);

    try {
      final SessionId newId = await _createSession(name);
      if (!mounted) return;
      // Pop with the intent; caller (`_openCreateDialog`) handles
      // navigation + auto-start. Keeping the dialog open across the
      // permission flow leaves it floating in the Overlay above any
      // pushed route — see the comment in `_openCreateDialog`.
      Navigator.of(context).pop(_CreateDialogResult(sessionId: newId, startImmediately: startImmediately));
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = 'Erreur : $err';
      });
    }
  }

  Future<SessionId> _createSession(String displayName) async {
    final store = await ref.read(sessionStoreProvider.future);
    // Phase 06 Should #20 (Agent #3 #5) — route session-id minting
    // through the domain-layer IdGenerator (same generator used for
    // Fix ids). CLAUDE.md §Structure: logique métier stays out of
    // widgets; tests can now override idGeneratorProvider with a
    // seeded generator for deterministic dialog creation.
    final idGenerator = ref.read(idGeneratorProvider);
    final sessionId = SessionId(idGenerator.newId(SessionId.prefix));
    final now = DateTime.now().toUtc();
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final session = Session(id: sessionId, displayName: displayName, status: SessionStatus.stopped, startedAtUtc: now, startedAtOffsetMinutes: offsetMinutes);
    await store.insert(session);
    return sessionId;
  }
}

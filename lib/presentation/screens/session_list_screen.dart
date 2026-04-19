// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/session_list_provider.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/domain/errors/concurrent_errors.dart';
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
        actions: <Widget>[IconButton(tooltip: 'Paramètres', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings'))],
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
    await showDialog<void>(context: context, builder: (dialogContext) => const _CreateSessionDialog());
  }
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
      if (startImmediately) {
        await _startWithPermissionFlow(newId);
        if (!mounted) return;
      }
      Navigator.of(context).pop();
      if (!mounted) return;
      // Navigate to the detail screen so the user sees the status
      // dashboard when the session was started, or the summary when
      // it was only created.
      context.push('/sessions/${newId.value}');
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
    // Mint a local ULID-ish id at creation time. The domain `SessionId`
    // prefix + 26-char tail shape is required; we use
    // `DateTime.now()` milliseconds + a random suffix just for this
    // dialog — the production `IdGenerator` is already wired elsewhere
    // for Fix ids, and Session rows are user-facing so a short
    // monotonic string is fine in this single call site.
    final String id = 'sess_${_mintSessionIdBody()}';
    final sessionId = SessionId(id);
    final now = DateTime.now().toUtc();
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final session = Session(id: sessionId, displayName: displayName, status: SessionStatus.stopped, startedAtUtc: now, startedAtOffsetMinutes: offsetMinutes);
    await store.insert(session);
    return sessionId;
  }

  /// Minimal 26-char Crockford-ish body — good enough for a one-off
  /// user-entry flow; production session creation via the IdGenerator
  /// lives in future non-dialog entry points (import, boot-time
  /// recovery) and those paths can swap in the full generator.
  String _mintSessionIdBody() {
    const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final StringBuffer buffer = StringBuffer();
    int remaining = now;
    for (int i = 0; i < 16; i++) {
      buffer.write(alphabet[remaining & 0x1F]);
      remaining >>= 5;
    }
    // Pad up to 26 chars with the timestamp-seeded cheap suffix.
    while (buffer.length < 26) {
      buffer.write(alphabet[(now >> (buffer.length * 2)) & 0x1F]);
    }
    return buffer.toString().substring(0, 26);
  }

  Future<void> _startWithPermissionFlow(SessionId id) async {
    final settings = await ref.read(sessionSettingsProvider.future);
    if (!settings.permissionFlowCompleted) {
      if (!mounted) return;
      // Route through the permission rationale screen — its Continue
      // button runs `requestLocationAlways()` and returns a bool via
      // `context.pop`. We treat anything non-`true` as "user did not
      // complete grant" and do not start the session.
      final result = await GoRouter.of(context).push<bool>('/permissions/rationale');
      if (!mounted) return;
      if (result != true) return;
    }

    try {
      await ref.read(activeSessionControllerProvider.notifier).start(id);
    } on ConcurrentActivationException {
      if (!mounted) return;
      // The user requested a Start while another session was active.
      // Ask whether to stop+switch. Kept inline in the dialog rather
      // than dispatched via the router so cancelling simply drops the
      // Start intent and the newly-created session stays `stopped`.
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
      await ref.read(activeSessionControllerProvider.notifier).start(id);
    }
  }
}

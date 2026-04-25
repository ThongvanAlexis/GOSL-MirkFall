// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/mirk_style_session_controller.dart';
import 'package:mirkfall/application/providers/builtin_mirk_styles_provider.dart';
import 'package:mirkfall/application/providers/mirk_style_session_controller_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mirk_style_picker_sheet.g.dart';

/// Resolves the current `mirkStyleId` for [sessionId] from the session
/// store. Used by [MirkStylePickerSheet] to render the trailing
/// checkmark on the active style — the `Tracking` state does not
/// carry the style id directly (it lives on the persisted `Session`
/// row, behind `SessionStore.findById`).
@riverpod
Future<MirkStyleId?> currentSessionMirkStyleId(
  Ref ref,
  SessionId sessionId,
) async {
  final store = await ref.watch(sessionStoreProvider.future);
  final session = await store.findById(sessionId);
  return session?.mirkStyleId;
}

/// Bottom-sheet picker that lists the 4 builtin mirk styles and persists
/// the user's selection via [`MirkStyleSessionController.select`].
///
/// Plan 09-07 Task 3 — replaces the Phase 07 burger-menu snackbar stub.
///
/// UI:
/// * Header `Choisir un style` (French — matches the rest of the app's
///   user-facing strings).
/// * One [ListTile] per builtin, titled with the style's `displayName`.
/// * Currently-selected tile shows a trailing checkmark.
/// * Loading state (provider future not yet resolved) shows a centred
///   spinner.
/// * Error state surfaces the error text (defensive — production paths
///   should not see this).
///
/// Tap → `mirkStyleSessionControllerProvider.select(...)` → close sheet.
/// Selection failure (style or session not found) surfaces a snackbar
/// from the host context.
class MirkStylePickerSheet extends ConsumerWidget {
  const MirkStylePickerSheet({super.key, required this.sessionId});

  /// Session whose `mirkStyleId` will be updated on tap.
  final SessionId sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builtinsAsync = ref.watch(builtinMirkStylesProvider);
    final currentStyleAsync = ref.watch(
      currentSessionMirkStyleIdProvider(sessionId),
    );
    final MirkStyleId? currentStyleId = currentStyleAsync.value;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
              child: Text(
                'Choisir un style',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            builtinsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Erreur : $err'),
              ),
              data: (builtins) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final style in builtins)
                    _StyleTile(
                      style: style,
                      isCurrent: currentStyleId == style.id,
                      onTap: () => _onSelect(context, ref, style),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSelect(
    BuildContext context,
    WidgetRef ref,
    MirkStyle style,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final controller = await ref.read(
        mirkStyleSessionControllerProvider.future,
      );
      await controller.select(sessionId: sessionId, styleId: style.id);
    } on MirkStyleNotFoundException catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Style introuvable')),
      );
      return;
    } on NoActiveSessionException catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Aucune session active')),
      );
      return;
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
      return;
    }
    if (navigator.canPop()) navigator.pop();
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.isCurrent,
    required this.onTap,
  });

  final MirkStyle style;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(style.displayName),
      trailing: isCurrent ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}

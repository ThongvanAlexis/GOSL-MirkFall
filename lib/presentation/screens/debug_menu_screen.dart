// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/constants.dart';
import '../../infrastructure/logging/file_logger.dart';

/// Hidden debug menu reached via 7-tap on the `/about` placeholder.
///
/// Phase 01 exposes three controls: a verbose-logging switch (toggles the
/// SharedPreferences flag read by [FileLogger.bootstrap]), a list of log
/// files on disk with per-file Share buttons, and a Clear-all action. Phase
/// 15 (OPT-07) exposes the same verbose toggle as an options entry.
class DebugMenuScreen extends StatefulWidget {
  const DebugMenuScreen({super.key});

  @override
  State<DebugMenuScreen> createState() => _DebugMenuScreenState();
}

class _DebugMenuScreenState extends State<DebugMenuScreen> {
  bool _verbose = false;
  List<File> _files = <File>[];
  bool _loading = true;

  // Compile-time constant — reflects the `--dart-define=DEBUG` flag used at
  // build time, displayed alongside the prefs flag so users / devs can tell
  // which channel is driving the current log level.
  static const bool _debugDefine = bool.fromEnvironment('DEBUG');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final verbose = await FileLogger.readVerbosePref();
    final files = await FileLogger.listLogFiles();
    if (!mounted) return;
    setState(() {
      _verbose = verbose;
      _files = files;
      _loading = false;
    });
  }

  Future<void> _onToggleVerbose(bool _) async {
    final next = await FileLogger.toggleVerbosePref();
    if (!mounted) return;
    setState(() {
      _verbose = next;
    });
    // Apply immediately for the current run, not just next launch.
    Logger.root.level = (_debugDefine || next) ? Level.ALL : Level.INFO;
  }

  Future<void> _onShare(File f) async {
    // Flush the active sink so the shared copy carries every record written
    // up to the moment the share was requested. _onRecord flushes per-record
    // already, but a pending write sitting in the IOSink Stream buffer could
    // still be lost between write and share if we skip this.
    await FileLogger.flush();
    // Wrap the plugin call in a bounded timeout per CLAUDE.md §Timeouts —
    // share_plus can hang indefinitely on OS-level dialog failures. Any
    // plugin error (or timeout) is logged and surfaced as a SnackBar so the
    // user sees feedback instead of a silent no-op.
    try {
      await SharePlus.instance.share(ShareParams(files: <XFile>[XFile(f.path)])).timeout(const Duration(milliseconds: kShareCallTimeoutMilliseconds));
    } on TimeoutException catch (e, st) {
      Logger('debug_menu').warning('_onShare timeout', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage annulé (timeout)')));
    } on Exception catch (e, st) {
      Logger('debug_menu').warning('_onShare failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partage échoué : $e')));
    }
  }

  Future<void> _onClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer tous les logs ?'),
        content: const Text('Cette action est irréversible.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed ?? false) {
      await FileLogger.clearAll();
      if (!mounted) return;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Debug menu')),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            title: const Text('Verbose logging'),
            subtitle: Text('--dart-define=DEBUG = $_debugDefine · prefs = $_verbose'),
            value: _verbose,
            onChanged: _onToggleVerbose,
          ),
          const Divider(),
          if (_files.isEmpty)
            const ListTile(title: Text('Aucun fichier de log'))
          else
            ..._files.map(
              (f) => ListTile(
                title: Text(f.uri.pathSegments.last),
                subtitle: FutureBuilder<int>(future: f.length(), builder: (_, snap) => Text('${snap.data ?? 0} bytes')),
                trailing: IconButton(icon: const Icon(Icons.share), onPressed: () => _onShare(f)),
              ),
            ),
          const Divider(),
          ListTile(leading: const Icon(Icons.delete_forever), title: const Text('Supprimer tous les logs'), onTap: _onClearAll),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Active: ${FileLogger.activeFilename ?? "(none)"}', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

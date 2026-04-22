// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/constants.dart';
import '../../infrastructure/logging/file_logger.dart';
import '../../infrastructure/platform/ios_crash_log_reader.dart';

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

  Future<void> _onToggleVerbose(bool newValue) async {
    // Write the switch's new value directly to prefs rather than XOR-ing the
    // stored value. If the switch UI and prefs ever desync (two taps land
    // within the same microtask, or a setState races a prefs write), the
    // XOR would flip the stored value to the opposite of what the user sees.
    // Using the explicit new value keeps switch and prefs monotonically in
    // sync.
    await FileLogger.writeVerbosePref(newValue);
    if (!mounted) return;
    setState(() {
      _verbose = newValue;
    });
    // Apply immediately for the current run, not just next launch.
    Logger.root.level = (_debugDefine || newValue) ? Level.ALL : Level.INFO;
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

  /// Shares the SQLite DB files (mirkfall.db + optional -wal / -shm
  /// sidecars) via the system share sheet. On iOS this is the only
  /// sideload-friendly way to extract the DB without a Mac (Xcode's
  /// "Download Container" is Mac-only ; Filza requires jailbreak).
  ///
  /// The WAL sidecar is shared alongside the main file because Drift
  /// uses WAL journaling by default — recent writes live in
  /// `mirkfall.db-wal` until SQLite checkpoints them. Sharing only the
  /// main `.db` loses those rows (exactly the trap the Android POC
  /// hit — see 2026-04-19 conversation). sqlite3 reads the WAL
  /// automatically when the three files are co-located.
  Future<void> _onShareDatabase() async {
    try {
      final Directory supportDir = await getApplicationSupportDirectory();
      final String dbBasename = kDbFilename;
      final List<File> candidates = <File>[
        File(p.join(supportDir.path, dbBasename)),
        File(p.join(supportDir.path, '$dbBasename-wal')),
        File(p.join(supportDir.path, '$dbBasename-shm')),
      ];
      final List<File> existing = <File>[
        for (final File f in candidates)
          if (await f.exists()) f,
      ];
      if (existing.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun fichier de base de données trouvé')));
        return;
      }
      // Snapshot into a temp directory BEFORE handing to the share
      // sheet. Drift uses WAL journaling; the live `.db-wal` / `.db-shm`
      // sidecars carry active SQLite locks while the app is running.
      // iOS's UIActivityViewController tries to read those files
      // during the share preview and can block indefinitely waiting
      // on those locks — the 2026-04-21 device smoke saw "Partager
      // la base de données" freeze on first tap and work after a
      // reboot (WAL checkpointed, locks released). Copying to tmp
      // decouples the share sheet from Drift's writer.
      final Directory tmpRoot = await getTemporaryDirectory();
      final Directory snapshotDir = Directory(p.join(tmpRoot.path, 'mirkfall-db-snapshot'))..createSync(recursive: true);
      // Clear any prior snapshot — tmp is bounded disk so stale copies
      // from prior shares should not linger. Best-effort; ignore
      // transient filesystem races.
      for (final FileSystemEntity e in snapshotDir.listSync()) {
        try {
          await e.delete();
        } on Object {
          // ignore
        }
      }
      final List<XFile> snapshots = <XFile>[];
      for (final File src in existing) {
        final String destPath = p.join(snapshotDir.path, p.basename(src.path));
        await src.copy(destPath);
        snapshots.add(XFile(destPath));
      }
      await SharePlus.instance
          .share(ShareParams(files: snapshots, subject: 'MirkFall DB snapshot'))
          .timeout(const Duration(milliseconds: kShareCallTimeoutMilliseconds));
    } on TimeoutException catch (e, st) {
      Logger('debug_menu').warning('_onShareDatabase timeout', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage annulé (timeout)')));
    } on Exception catch (e, st) {
      Logger('debug_menu').warning('_onShareDatabase failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partage échoué : $e')));
    }
  }

  /// Surfaces the last native iOS crash captured by CrashReporter.swift.
  ///
  /// On iOS only. The crash log is drained into today's JSONL at
  /// bootstrap (see [IosCrashLogReader.drainIfAny]), then renamed to
  /// `ios_crash.log.drained`; this screen reads whichever file currently
  /// exists so the user can inspect / share the most recent crash even
  /// after it has already been logged.
  Future<void> _onShowLastCrash() async {
    final IosCrashLogReader reader = IosCrashLogReader();
    final String? contents = await reader.readIfAny();
    if (!mounted) return;
    if (contents == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun plantage natif enregistré')));
      return;
    }
    // `resolveReadableFilename` returns whichever of the active / drained
    // files is currently on disk — ensures Share passes the right File.
    final String? filename = await reader.resolveReadableFilename();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dernier plantage natif (iOS)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(contents, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.0)),
          ),
        ),
        actions: <Widget>[
          if (filename != null)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _shareCrashAsTxt(filename);
              },
              child: const Text('Partager'),
            ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await reader.clear();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantage supprimé')));
            },
            child: const Text('Supprimer'),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  /// Copies [crashFilename] into the tmp directory with a `.txt`
  /// extension before handing it to the share sheet.
  ///
  /// Why : iOS's share sheet (UIActivityViewController) serialises an
  /// unknown-extension file as an NSURL reference rather than its body
  /// for most recipients — so sharing `ios_crash.log.drained` directly
  /// produced a bplist with just the file path when pasted into Notes /
  /// Mail / Messages. Copying to `<tmp>/ios_crash-<ts>.txt` gives the
  /// file a recognised MIME (`public.plain-text`) so recipients treat
  /// it as plain text and copy the actual body.
  Future<void> _shareCrashAsTxt(String crashFilename) async {
    try {
      final Directory tmp = await getTemporaryDirectory();
      final Directory stageDir = Directory(p.join(tmp.path, 'mirkfall-crash-snapshot'))..createSync(recursive: true);
      // Clean up any prior snapshot so tmp bounded disk usage stays
      // minimal. Best-effort — transient filesystem errors ignored.
      for (final FileSystemEntity e in stageDir.listSync()) {
        try {
          await e.delete();
        } on Object {
          // ignore
        }
      }
      final int ts = DateTime.now().millisecondsSinceEpoch;
      final String destFilename = p.join(stageDir.path, 'ios_crash-$ts.txt');
      await File(crashFilename).copy(destFilename);
      await SharePlus.instance
          .share(
            ShareParams(
              files: <XFile>[XFile(destFilename, mimeType: 'text/plain')],
              subject: 'MirkFall iOS crash dump',
            ),
          )
          .timeout(const Duration(milliseconds: kShareCallTimeoutMilliseconds));
    } on TimeoutException catch (e, st) {
      Logger('debug_menu').warning('_shareCrashAsTxt timeout', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage annulé (timeout)')));
    } on Exception catch (e, st) {
      Logger('debug_menu').warning('_shareCrashAsTxt failed', e, st);
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
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Partager la base de données'),
            subtitle: const Text('Exporte mirkfall.db + -wal + -shm via le share sheet (iOS-friendly).'),
            onTap: _onShareDatabase,
          ),
          if (Platform.isIOS) ...<Widget>[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Voir dernier crash (iOS)'),
              subtitle: const Text("Affiche et partage le dernier plantage natif capturé par CrashReporter."),
              onTap: _onShowLastCrash,
            ),
          ],
          const Divider(),
          ListTile(leading: const Icon(Icons.delete_forever), title: const Text('Supprimer tous les logs'), onTap: _onClearAll),
          const SizedBox(height: kListSectionPaddingLogicalPx),
          Padding(
            padding: const EdgeInsets.all(kListSectionPaddingLogicalPx),
            child: Text('Active: ${FileLogger.activeFilename ?? "(none)"}', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

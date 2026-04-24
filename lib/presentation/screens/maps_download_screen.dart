// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/download_queue_controller.dart';
import 'package:mirkfall/application/controllers/installed_maps_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';

import '../widgets/map_download_progress_chip.dart';

/// Format a byte-per-second rate the way browsers do: decimal SI units
/// (1 kB = 1000 B), `kB/s` below 1000 kB/s, `MB/s` with one decimal
/// above. Mirrors the threshold the user asked for in the MAP-08 UX
/// review ("en kB/s et MB/s si c'est plus rapide que 1000 KB/s").
///
/// Exposed at library scope so `_DownloadSpeedLabel` + its boundary
/// tests can share one implementation.
@visibleForTesting
String formatDownloadSpeed(double bytesPerSecond) {
  final double kbps = bytesPerSecond / 1000.0;
  if (kbps < 1000.0) {
    return '${kbps.toStringAsFixed(0)} kB/s';
  }
  final double mbps = kbps / 1000.0;
  return '${mbps.toStringAsFixed(1)} MB/s';
}

/// `/maps/download` — catalog browse + enqueue screen.
///
/// Lists every catalog entry (alpha3 name sort) with a per-row status
/// indicator:
/// - Installed + catalog-version match → "Installé" + green check
/// - Installed + stale version → "Mise à jour disponible" + orange dot
/// - Downloading → "En téléchargement XX %" + spinner
/// - Else → "Disponible" + download icon
///
/// A search field at the top filters the list by country name
/// (case-insensitive, partial match on `contains`). Filter state is
/// local to the screen — clearing it with the ✕ icon restores the full
/// 249-country list.
///
/// Tap on a "Disponible" row opens a confirmation dialog. Confirm →
/// [DownloadQueueController.enqueue]. The in-flight download surfaces
/// in the AppBar via [MapDownloadProgressChip].
class MapsDownloadScreen extends ConsumerStatefulWidget {
  const MapsDownloadScreen({super.key});

  @override
  ConsumerState<MapsDownloadScreen> createState() => _MapsDownloadScreenState();
}

class _MapsDownloadScreenState extends ConsumerState<MapsDownloadScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CountryCatalog> catalogAsync = ref.watch(countryCatalogProvider);
    final InstalledMapsState installedState = ref.watch(installedMapsControllerProvider);
    final DownloadState downloadState = ref.watch(downloadQueueControllerProvider);

    // Surface DownloadError + DownloadCompleted transitions as
    // snackbars so the user always gets feedback — the "download did
    // nothing" iOS bug (MissingPluginException on the disk-space
    // platform channel) slipped through Phase 07 smoke because the
    // error state never surfaced in the UI. Happy-path downloads are
    // still driven by the AppBar chip; this listener only fires on
    // state transitions.
    ref.listen<DownloadState>(downloadQueueControllerProvider, (previous, next) {
      if (!context.mounted) return;
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      if (next is DownloadError && previous is! DownloadError) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Échec du téléchargement de ${next.active.entry.name} — ${next.cause.toString()}'),
            duration: const Duration(seconds: kDownloadErrorSnackbarSeconds),
          ),
        );
      } else if (next is DownloadCompleted && previous is! DownloadCompleted) {
        messenger.showSnackBar(
          SnackBar(
            // next.active carries the full DownloadJob → entry → name, so the
            // snackbar no longer needs a catalog lookup (addresses §3 row #42).
            content: Text('${next.active.entry.name} téléchargé ✓'),
            duration: const Duration(seconds: kDownloadCompletedSnackbarSeconds),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Télécharger une carte'), actions: const <Widget>[MapDownloadProgressChip()]),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, st) => Center(
          child: Padding(padding: const EdgeInsets.all(24.0), child: Text('Erreur : $err')),
        ),
        data: (catalog) => _buildBody(context, catalog, installedState, downloadState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CountryCatalog catalog, InstalledMapsState installedState, DownloadState downloadState) {
    // Alphabetic sort over a fresh list — never mutate the catalog's own
    // `countries` list.
    final List<CountryEntry> sorted = <CountryEntry>[...catalog.countries]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final String normalizedQuery = _query.trim().toLowerCase();
    final List<CountryEntry> filtered = normalizedQuery.isEmpty ? sorted : sorted.where((e) => e.name.toLowerCase().contains(normalizedQuery)).toList();
    final CountryCode? activeDownloadAlpha3 = _activeDownloadAlpha3(downloadState);
    final double? activeFraction = _activeFraction(downloadState);
    final int? activeBytesDownloaded = _activeBytesDownloaded(downloadState);
    final int? activePartIndex = _activePartIndex(downloadState);
    final int? activeTotalParts = _activeTotalParts(downloadState);
    final String catalogVersion = _safeCatalogVersion(catalog);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Rechercher un pays',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Effacer la recherche',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Aucun pays ne correspond à "${_query.trim()}"', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1.0),
                  itemBuilder: (context, index) {
                    final CountryEntry entry = filtered[index];
                    return _CountryTile(
                      entry: entry,
                      installedState: installedState,
                      catalogVersion: catalogVersion,
                      activeDownloadAlpha3: activeDownloadAlpha3,
                      activeFraction: activeFraction,
                      activeBytesDownloaded: activeBytesDownloaded,
                      activePartIndex: activePartIndex,
                      activeTotalParts: activeTotalParts,
                      retryingSnapshot: downloadState is DownloadRetrying ? downloadState : null,
                      activePhase: downloadState is DownloadInProgress ? downloadState.phase : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  CountryCode? _activeDownloadAlpha3(DownloadState state) => state.activeJob?.alpha3;

  double? _activeFraction(DownloadState state) => state.activeSnapshot?.fractionDone;

  int? _activeBytesDownloaded(DownloadState state) => state.activeSnapshot?.bytesDownloaded;

  int? _activePartIndex(DownloadState state) => state.activeSnapshot?.currentPartIndex;

  int? _activeTotalParts(DownloadState state) => state.activeSnapshot?.totalParts;

  /// Returns the catalog version, or `''` when derivation throws (empty
  /// countries list — never expected in production, but keeps the widget
  /// resilient under misconfigured assets).
  String _safeCatalogVersion(CountryCatalog catalog) {
    try {
      return catalog.catalogVersion;
    } on FormatException {
      return '';
    }
  }
}

class _CountryTile extends ConsumerWidget {
  const _CountryTile({
    required this.entry,
    required this.installedState,
    required this.catalogVersion,
    required this.activeDownloadAlpha3,
    required this.activeFraction,
    required this.activeBytesDownloaded,
    required this.activePartIndex,
    required this.activeTotalParts,
    required this.retryingSnapshot,
    required this.activePhase,
  });

  final CountryEntry entry;
  final InstalledMapsState installedState;
  final String catalogVersion;
  final CountryCode? activeDownloadAlpha3;
  final double? activeFraction;
  final int? activeBytesDownloaded;

  /// 0-indexed chunk position of the in-flight download — drives the
  /// "Assemblage du bloc N/M + vérification finale…" subtitle during
  /// the concat phase. Null when no download is active.
  final int? activePartIndex;

  /// Number of catalog parts for the active download (= the M in N/M
  /// above). Null when no download is active.
  final int? activeTotalParts;

  /// Non-null when the active download is in a retry-backoff window; the
  /// tile should render "Reprise en cours (N/M)" instead of the usual
  /// "En téléchargement X%" so the user understands why the progress bar
  /// isn't moving. Supplied only for the tile matching the retrying
  /// job's alpha3 (the parent filters via `activeDownloadAlpha3`).
  final DownloadRetrying? retryingSnapshot;

  /// Current post-transfer phase of the in-flight download, if any.
  /// `null` when the active download state is not `DownloadInProgress`
  /// (e.g. paused, retrying, error). On `DownloadPhase.transferring`
  /// the tile renders the regular "En téléchargement X %" + speed
  /// label; other phases render dedicated copy
  /// (verifyingChunk → "Vérification de la partie…",
  /// concatenating → "Assemblage…",
  /// verifyingFinal → "Vérification finale…") so the progress bar is
  /// never silently frozen.
  final DownloadPhase? activePhase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InstalledCountry? installed = installedState.installed[entry.alpha3];
    final bool isDownloading = activeDownloadAlpha3 == entry.alpha3;
    final int totalMb = (entry.totalBytes / (1024 * 1024)).round();

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget trailing;
    final Widget subtitleWidget;
    final VoidCallback? onTap;
    final IconData leading;
    final Color leadingColor;

    if (isDownloading) {
      final int percent = ((activeFraction ?? 0.0) * 100).clamp(0, 100).round();
      final DownloadRetrying? retrying = retryingSnapshot;
      // Trailing empty during any download phase — the percent +
      // phase-specific copy live in the subtitle as a single string
      // so there's only one source of truth for status. The leading
      // icon disambiguates "this tile is the active download" from
      // "this tile is a normal idle entry" (downloading /
      // autorenew / verified / merge_type by phase).
      trailing = const SizedBox.shrink();
      onTap = null;
      leadingColor = cs.primary;
      if (retrying != null && retrying.active.alpha3 == entry.alpha3) {
        // Retry-backoff window — explain WHY the bar is frozen.
        // retry.attemptIndex is 0-indexed for the attempt that JUST
        // failed; the NEXT attempt is +1 (display as 1-indexed = +2).
        final int nextAttempt = retrying.attemptIndex + 2;
        subtitleWidget = Text('Reprise en cours (tentative $nextAttempt/${retrying.totalAttempts}) · $percent %', overflow: TextOverflow.ellipsis);
        leading = Icons.autorenew;
      } else {
        // Phase-specific subtitle. DownloadPhase.transferring falls
        // through to the _DownloadSpeedLabel which renders
        // "XX % · 3.4 MB/s" once a 3 s sliding window of samples is
        // available. The concat phase (which also computes the
        // reassembled sha256 inline) gets its own copy so the bar
        // isn't silently frozen while the single-pass finalize runs.
        switch (activePhase ?? DownloadPhase.transferring) {
          case DownloadPhase.concatenating:
            final int chunkIndex = activePartIndex ?? 0;
            final int chunkTotal = activeTotalParts ?? 1;
            subtitleWidget = Text('Assemblage du bloc ${chunkIndex + 1}/$chunkTotal + vérification finale…', overflow: TextOverflow.ellipsis);
            leading = Icons.merge_type_outlined;
          case DownloadPhase.transferring:
            subtitleWidget = _DownloadSpeedLabel(bytesDownloaded: activeBytesDownloaded ?? 0, prefix: 'En téléchargement $percent %');
            leading = Icons.downloading_outlined;
        }
      }
    } else if (installed != null) {
      final bool needsUpdate = catalogVersion.isNotEmpty && installed.pmtilesVersion != catalogVersion;
      if (needsUpdate) {
        trailing = Icon(Icons.update, color: Colors.orange[700]);
        subtitleWidget = const Text('Mise à jour disponible');
        onTap = () => _confirmAndEnqueue(context, ref);
        leading = Icons.check_circle_outline;
        leadingColor = Colors.orange[700]!;
      } else {
        trailing = const Icon(Icons.check, color: Colors.green);
        subtitleWidget = Text('Installé · $totalMb Mo');
        onTap = null;
        leading = Icons.check_circle;
        leadingColor = Colors.green;
      }
    } else {
      trailing = const Icon(Icons.download_outlined);
      subtitleWidget = Text('Disponible · $totalMb Mo');
      onTap = () => _confirmAndEnqueue(context, ref);
      leading = Icons.public_outlined;
      leadingColor = cs.onSurfaceVariant;
    }

    return ListTile(
      leading: Icon(leading, color: leadingColor),
      title: Text(entry.name),
      subtitle: subtitleWidget,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Future<void> _confirmAndEnqueue(BuildContext context, WidgetRef ref) async {
    final int totalMb = (entry.totalBytes / (1024 * 1024)).round();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Télécharger ${entry.name} ?'),
        content: Text('Taille approximative : $totalMb Mo. La carte sera disponible hors-ligne une fois téléchargée.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Télécharger')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    // Immediate feedback — the user tapped Download and something has
    // visibly happened. The AppBar chip takes over once the controller
    // transitions to DownloadInProgress; DownloadError transitions fire
    // the listener on MapsDownloadScreen.build which surfaces a second,
    // noisier snackbar.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text('${entry.name} ajouté à la file de téléchargement'),
        duration: const Duration(seconds: kDownloadEnqueueConfirmSnackbarSeconds),
      ),
    );
    try {
      await ref.read(downloadQueueControllerProvider.notifier).enqueue(entry);
    } on Object catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur à la mise en file : $err'), duration: const Duration(seconds: kDownloadEnqueueErrorSnackbarSeconds)));
    }
  }
}

/// Wall-clock getter injected into [_DownloadSpeedLabel]. Default is
/// `DateTime.now`; tests override it to feed monotonic, deterministic
/// timestamps into the sliding window without waiting on real time.
typedef _NowFn = DateTime Function();

DateTime _defaultNow() => DateTime.now();

/// Tiny live-updating speed readout ("420 kB/s" / "1.4 MB/s") shown next
/// to the "En téléchargement XX %" subtitle while the active job is
/// transferring. Gives the user visual proof the download is alive — on
/// a 500 MB country the percent digits can sit stale for a full second
/// between ticks, so a continuously-moving speed label is the fastest
/// "yes it's working" signal.
///
/// Keeps a 3-second sliding window of `(timestamp, bytesDownloaded)`
/// samples. On each parent rebuild it appends a new sample if the byte
/// count advanced, prunes anything older than 3 s, and returns the
/// first-to-last rate. Renders `SizedBox.shrink()` until there are at
/// least two samples separated by > 0 ms — keeps the UI clean during
/// the first ~tick of a fresh download.
///
/// State-only-at-widget level: when the active job switches country,
/// this widget is destroyed + reconstructed fresh, so samples never
/// bleed between countries.
class _DownloadSpeedLabel extends StatefulWidget {
  const _DownloadSpeedLabel({required this.bytesDownloaded, required this.prefix, _NowFn now = _defaultNow}) : _now = now;

  final int bytesDownloaded;

  /// Constant prefix prepended to the speed value — typically the
  /// phase + percent copy like `'En téléchargement 23 %'`. The widget
  /// renders `'$prefix · 2.4 MB/s'` when enough samples have
  /// accumulated, or falls back to just `prefix` before the first
  /// 3 s sliding window is populated.
  final String prefix;

  final _NowFn _now;

  @override
  State<_DownloadSpeedLabel> createState() => _DownloadSpeedLabelState();
}

class _DownloadSpeedLabelState extends State<_DownloadSpeedLabel> {
  // Keep the window small enough that the label reacts within one tick
  // of a real speed change, large enough to smooth out per-chunk jitter.
  // 3 s matches the "gut feeling" window Firefox + Chrome use in their
  // download bars (empirical — no public spec).
  static const Duration _window = Duration(seconds: 3);
  final List<_SpeedSample> _samples = <_SpeedSample>[];

  @override
  void initState() {
    super.initState();
    _samples.add(_SpeedSample(widget._now(), widget.bytesDownloaded));
  }

  @override
  void didUpdateWidget(covariant _DownloadSpeedLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bytesDownloaded != oldWidget.bytesDownloaded) {
      final DateTime now = widget._now();
      _samples.add(_SpeedSample(now, widget.bytesDownloaded));
      final DateTime threshold = now.subtract(_window);
      _samples.removeWhere((sample) => sample.at.isBefore(threshold));
      // Guarantee the list is never empty, so the next comparison always
      // has an anchor to measure against.
      if (_samples.isEmpty) {
        _samples.add(_SpeedSample(now, widget.bytesDownloaded));
      }
    }
  }

  double? _speedBytesPerSecond() {
    if (_samples.length < 2) return null;
    final _SpeedSample first = _samples.first;
    final _SpeedSample last = _samples.last;
    final int deltaMs = last.at.difference(first.at).inMilliseconds;
    if (deltaMs <= 0) return null;
    final int deltaBytes = last.bytes - first.bytes;
    if (deltaBytes <= 0) return null;
    return deltaBytes * 1000.0 / deltaMs;
  }

  @override
  Widget build(BuildContext context) {
    final double? speed = _speedBytesPerSecond();
    final String label = speed == null ? widget.prefix : '${widget.prefix} · ${formatDownloadSpeed(speed)}';
    return Text(label, overflow: TextOverflow.ellipsis);
  }
}

class _SpeedSample {
  const _SpeedSample(this.at, this.bytes);
  final DateTime at;
  final int bytes;
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Default initial size (fraction of screen height) for the tuner sheet.
/// Slightly under [_kMaxSheetSize] so the user has a visible drag affordance
/// upward; the cap keeps the map readable above the sheet while scrubbing.
const double _kInitialSheetSize = 0.45;

/// Hard cap on sheet height — capped at half so the user always has a
/// readable map area above the sheet. Sliders that don't fit scroll
/// inside the sheet (the sheet's [DraggableScrollableSheet] gives its
/// scroll controller to the inner ListView).
const double _kMaxSheetSize = 0.50;

/// Floor on sheet height. Below this the sheet should auto-dismiss; we
/// keep it slightly above zero so the user can collapse the sheet to a
/// minimal grip without it disappearing.
const double _kMinSheetSize = 0.18;

/// Opens the live mirk tuner as a draggable, non-blocking bottom sheet.
///
/// The sheet sits ABOVE the map screen — the renderers keep painting
/// underneath at 96 fps and pick up each tunable change on the next paint
/// (renderers read [MirkRuntimeTunables.instance] per paint).
///
/// Returns when the user dismisses the sheet (drag-to-dismiss, scrim tap,
/// or system back). Caller must already be on a route where a Scaffold
/// is in the widget tree (the map screen, in practice).
Future<void> showMirkTunerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Transparent scrim — keeps the map readable behind the dim layer so
    // the user can tell the tuner is responding live.
    barrierColor: Colors.black.withValues(alpha: 0.15),
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: _kInitialSheetSize,
        minChildSize: _kMinSheetSize,
        maxChildSize: _kMaxSheetSize,
        expand: false,
        builder: (BuildContext ctx, ScrollController controller) {
          return _MirkTunerSheetContent(scrollController: controller);
        },
      );
    },
  );
}

class _MirkTunerSheetContent extends StatefulWidget {
  const _MirkTunerSheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_MirkTunerSheetContent> createState() => _MirkTunerSheetContentState();
}

class _MirkTunerSheetContentState extends State<_MirkTunerSheetContent> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      elevation: 8.0,
      child: AnimatedBuilder(
        animation: MirkRuntimeTunables.instance,
        builder: (BuildContext ctx, Widget? _) {
          return ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: <Widget>[
              _buildGrip(cs),
              _buildHeader(context),
              const SizedBox(height: 8.0),
              _section('Atmosphérique — Drift Z'),
              _slider(
                label: 'driftZFar',
                value: MirkRuntimeTunables.instance.atmosphericDriftZFar,
                defaultValue: kMirkFogAtmosphericDriftZFar,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.atmosphericDriftZFar = v,
              ),
              _slider(
                label: 'driftZMid',
                value: MirkRuntimeTunables.instance.atmosphericDriftZMid,
                defaultValue: kMirkFogAtmosphericDriftZMid,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.atmosphericDriftZMid = v,
              ),
              _slider(
                label: 'driftZNear',
                value: MirkRuntimeTunables.instance.atmosphericDriftZNear,
                defaultValue: kMirkFogAtmosphericDriftZNear,
                min: 0.0,
                max: 2.0,
                onChanged: (v) => MirkRuntimeTunables.instance.atmosphericDriftZNear = v,
              ),
              _section('Atmosphérique — Échelle'),
              _slider(
                label: 'scaleFar',
                value: MirkRuntimeTunables.instance.atmosphericScaleFar,
                defaultValue: kMirkFogAtmosphericScaleFar,
                min: 0.1,
                max: 6.0,
                onChanged: (v) => MirkRuntimeTunables.instance.atmosphericScaleFar = v,
              ),
              _slider(
                label: 'scaleMid',
                value: MirkRuntimeTunables.instance.atmosphericScaleMid,
                defaultValue: kMirkFogAtmosphericScaleMid,
                min: 0.1,
                max: 10.0,
                onChanged: (v) => MirkRuntimeTunables.instance.atmosphericScaleMid = v,
              ),
              _slider(
                label: 'scaleNear',
                value: MirkRuntimeTunables.instance.atmosphericScaleNear,
                defaultValue: kMirkFogAtmosphericScaleNear,
                min: 0.1,
                max: 20.0,
                onChanged: (v) => MirkRuntimeTunables.instance.atmosphericScaleNear = v,
              ),
              _section('Heavenly — Drift Z'),
              _slider(
                label: 'driftZFar',
                value: MirkRuntimeTunables.instance.heavenlyDriftZFar,
                defaultValue: kMirkFogHeavenlyDriftZFar,
                min: 0.0,
                max: 1.5,
                onChanged: (v) => MirkRuntimeTunables.instance.heavenlyDriftZFar = v,
              ),
              _slider(
                label: 'driftZMid',
                value: MirkRuntimeTunables.instance.heavenlyDriftZMid,
                defaultValue: kMirkFogHeavenlyDriftZMid,
                min: 0.0,
                max: 1.5,
                onChanged: (v) => MirkRuntimeTunables.instance.heavenlyDriftZMid = v,
              ),
              _slider(
                label: 'driftZNear',
                value: MirkRuntimeTunables.instance.heavenlyDriftZNear,
                defaultValue: kMirkFogHeavenlyDriftZNear,
                min: 0.0,
                max: 2.5,
                onChanged: (v) => MirkRuntimeTunables.instance.heavenlyDriftZNear = v,
              ),
              _section('Heavenly — Échelle'),
              _slider(
                label: 'scaleFar',
                value: MirkRuntimeTunables.instance.heavenlyScaleFar,
                defaultValue: kMirkFogHeavenlyScaleFar,
                min: 0.1,
                max: 6.0,
                onChanged: (v) => MirkRuntimeTunables.instance.heavenlyScaleFar = v,
              ),
              _slider(
                label: 'scaleMid',
                value: MirkRuntimeTunables.instance.heavenlyScaleMid,
                defaultValue: kMirkFogHeavenlyScaleMid,
                min: 0.1,
                max: 10.0,
                onChanged: (v) => MirkRuntimeTunables.instance.heavenlyScaleMid = v,
              ),
              _slider(
                label: 'scaleNear',
                value: MirkRuntimeTunables.instance.heavenlyScaleNear,
                defaultValue: kMirkFogHeavenlyScaleNear,
                min: 0.1,
                max: 20.0,
                onChanged: (v) => MirkRuntimeTunables.instance.heavenlyScaleNear = v,
              ),
              _section('Opacités (poids des octaves)'),
              _slider(
                label: 'opacityFar',
                value: MirkRuntimeTunables.instance.opacityFar,
                defaultValue: kMirkFogOpacityFar,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.opacityFar = v,
              ),
              _slider(
                label: 'opacityMid',
                value: MirkRuntimeTunables.instance.opacityMid,
                defaultValue: kMirkFogOpacityMid,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.opacityMid = v,
              ),
              _slider(
                label: 'opacityNear',
                value: MirkRuntimeTunables.instance.opacityNear,
                defaultValue: kMirkFogOpacityNear,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.opacityNear = v,
              ),
              _section('Curl noise'),
              _slider(
                label: 'curlAmplitude',
                value: MirkRuntimeTunables.instance.curlAmplitude,
                defaultValue: kMirkFogCurlAmplitude,
                min: 0.0,
                max: 2.0,
                onChanged: (v) => MirkRuntimeTunables.instance.curlAmplitude = v,
              ),
              _slider(
                label: 'curlScale',
                value: MirkRuntimeTunables.instance.curlScale,
                defaultValue: kMirkFogCurlScale,
                min: 0.0,
                max: 3.0,
                onChanged: (v) => MirkRuntimeTunables.instance.curlScale = v,
              ),
              _section('Faux directional shading'),
              _slider(
                label: 'lightDirRadians',
                value: MirkRuntimeTunables.instance.lightDirRadians,
                defaultValue: kMirkFogLightDirRadians,
                min: -3.14159,
                max: 3.14159,
                onChanged: (v) => MirkRuntimeTunables.instance.lightDirRadians = v,
              ),
              _slider(
                label: 'lightOffset',
                value: MirkRuntimeTunables.instance.lightOffset,
                defaultValue: kMirkFogLightOffset,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.lightOffset = v,
              ),
              _slider(
                label: 'lightStrength',
                value: MirkRuntimeTunables.instance.lightStrength,
                defaultValue: kMirkFogLightStrength,
                min: 0.0,
                max: 3.0,
                onChanged: (v) => MirkRuntimeTunables.instance.lightStrength = v,
              ),
              _section('Hue variation'),
              _slider(
                label: 'hueNoiseScale',
                value: MirkRuntimeTunables.instance.hueNoiseScale,
                defaultValue: kMirkFogHueNoiseScale,
                min: 0.0,
                max: 3.0,
                onChanged: (v) => MirkRuntimeTunables.instance.hueNoiseScale = v,
              ),
              _slider(
                label: 'hueStrength',
                value: MirkRuntimeTunables.instance.hueStrength,
                defaultValue: kMirkFogHueStrength,
                min: 0.0,
                max: 2.0,
                onChanged: (v) => MirkRuntimeTunables.instance.hueStrength = v,
              ),
              _section('Boundary watercolour'),
              _slider(
                label: 'boundarySharpDistance',
                value: MirkRuntimeTunables.instance.boundarySharpDistance,
                defaultValue: kMirkFogBoundarySharpDistance,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.boundarySharpDistance = v,
              ),
              _slider(
                label: 'boundaryBleedDistance',
                value: MirkRuntimeTunables.instance.boundaryBleedDistance,
                defaultValue: kMirkFogBoundaryBleedDistance,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.boundaryBleedDistance = v,
              ),
              _slider(
                label: 'boundaryEdgeBand',
                value: MirkRuntimeTunables.instance.boundaryEdgeBand,
                defaultValue: kMirkFogBoundaryEdgeBand,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => MirkRuntimeTunables.instance.boundaryEdgeBand = v,
              ),
              _section('Diagnostic'),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Debug output density'),
                subtitle: const Text('Necessite une rebuild du shader (#define) pour avoir un effet visible.'),
                value: MirkRuntimeTunables.instance.debugOutputDensity,
                onChanged: (bool v) => MirkRuntimeTunables.instance.debugOutputDensity = v,
              ),
              const Divider(height: 32.0),
              FilledButton.tonalIcon(onPressed: _onExportJson, icon: const Icon(Icons.ios_share), label: const Text('Exporter JSON')),
              const SizedBox(height: 24.0),
            ],
          );
        },
      ),
    );
  }

  /// Serialises the current [MirkRuntimeTunables] state to a pretty JSON
  /// file in the temp dir and opens the native share sheet so the user
  /// can email / message the values back to themselves (and paste them
  /// to the agent for baking into `constants.dart`).
  ///
  /// File-based share (rather than text-based) so messaging apps treat
  /// the payload as a `.json` attachment — preserves indentation and
  /// avoids body reflow by clients that strip whitespace.
  Future<void> _onExportJson() async {
    try {
      final Map<String, Object?> payload = <String, Object?>{
        '_meta': <String, Object?>{'exported_at': DateTime.now().toUtc().toIso8601String(), 'git_commit': kGitCommitSha},
        'tunables': MirkRuntimeTunables.instance.toJson(),
      };
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String jsonText = encoder.convert(payload);

      final Directory tmpDir = await getTemporaryDirectory();
      final DateTime now = DateTime.now();
      // Filename includes a sortable timestamp so successive exports do
      // not overwrite each other in the share-sheet preview cache.
      final String timestamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final String exportBasename = 'mirkfall_tunables_$timestamp.json';
      final File exportFile = File(p.join(tmpDir.path, exportBasename));
      await exportFile.writeAsString(jsonText, flush: true);

      final String dateLabel = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await SharePlus.instance
          .share(
            ShareParams(
              files: <XFile>[XFile(exportFile.path, mimeType: 'application/json')],
              subject: 'MirkFall mirk tunables — $dateLabel',
            ),
          )
          .timeout(const Duration(milliseconds: kShareCallTimeoutMilliseconds));
    } on TimeoutException catch (e, st) {
      Logger('mirk_tuner_sheet').warning('_onExportJson timeout', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage annulé (timeout)')));
    } on Exception catch (e, st) {
      Logger('mirk_tuner_sheet').warning('_onExportJson failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export échoué : $e')));
    }
  }

  Widget _buildGrip(ColorScheme cs) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      width: 40.0,
      height: 4.0,
      decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.0)),
    ),
  );

  Widget _buildHeader(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text('Mirk tuner (live)', style: Theme.of(context).textTheme.titleMedium)),
      TextButton.icon(onPressed: () => MirkRuntimeTunables.instance.reset(), icon: const Icon(Icons.refresh, size: 18.0), label: const Text('Reset all')),
    ],
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 4.0),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _slider({
    required String label,
    required double value,
    required double defaultValue,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    // Clamp display value into [min..max] in case a previous run wrote a
    // value outside the current range (e.g. range tightened in code).
    final double clamped = value.clamp(min, max);
    final bool atDefault = (value - defaultValue).abs() < 1e-9;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: <Widget>[
          SizedBox(width: 130.0, child: Text(label, style: const TextStyle(fontSize: 12.0))),
          Expanded(
            child: Slider(value: clamped, min: min, max: max, onChanged: onChanged),
          ),
          SizedBox(
            width: 56.0,
            child: Text(
              value.toStringAsFixed(3),
              style: const TextStyle(fontSize: 12.0, fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            iconSize: 18.0,
            visualDensity: VisualDensity.compact,
            tooltip: 'Reset to default ${defaultValue.toStringAsFixed(3)}',
            onPressed: atDefault ? null : () => onChanged(defaultValue),
            icon: const Icon(Icons.replay),
          ),
        ],
      ),
    );
  }
}

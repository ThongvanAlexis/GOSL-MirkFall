// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';

import 'fog_layer.dart';

final Logger _log = Logger('presentation.fog_layer_connector');

/// Riverpod boundary of the same-canvas fog — mounted by `MapScreen` INSIDE the
/// `FlutterMap` children (`FlutterMapMapViewWidget.fogLayers`), between the tile
/// layer and the user puck.
///
/// Knows nothing about flutter_map: it watches the four application inputs
/// ([activeMirkRendererProvider], [mapViewportProvider],
/// [discsInViewportProvider], [activeSessionControllerProvider]) and hands them
/// to a [FogLayer], which reads its own `MapCamera` snapshot for the exact clip
/// and projection (FOG-07). The disc query is keyed on the THROTTLED viewport
/// bbox of [mapViewportProvider] (50 ms) padded by
/// [kMirkFogDiscQueryPaddingFactor] — never on the per-frame camera (RESEARCH
/// Pitfall 6: a query per frame would thrash Drift during a pan).
///
/// BUG-012 anti-strobe: while the disc query reloads on a new bbox key, the last
/// known disc list keeps feeding the layer so the fog never blinks off for a
/// frame. Without a resolved renderer (loading / error) the connector renders
/// nothing; the renderer is owned by its provider and never disposed here.
///
/// Owns the two verbose-only diagnostics of the layer (`start()` on mount,
/// `stop()` / `dispose()` on unmount); their emission is gated on verbose
/// logging, so production carries no per-frame cost when the toggle is off.
class FogLayerConnector extends ConsumerStatefulWidget {
  /// Creates the connector.
  const FogLayerConnector({super.key});

  @override
  ConsumerState<FogLayerConnector> createState() => _FogLayerConnectorState();
}

class _FogLayerConnectorState extends ConsumerState<FogLayerConnector> {
  final FrameDeltaProbe _frameDeltaProbe = FrameDeltaProbe();
  final FogTransformLogger _fogTransformLogger = FogTransformLogger();

  /// Last disc list obtained from a resolved query (BUG-012, see class docstring).
  List<RevealDisc>? _lastKnownDiscs;

  /// Disc count at the last FINE log — the count is logged on change only.
  int? _lastLoggedDiscCount;

  /// Renderer availability at the last INFO transition log.
  String? _lastLoggedRendererState;

  /// Set once the current renderer error has been logged; reset when a renderer resolves.
  bool _rendererErrorLogged = false;

  @override
  void initState() {
    super.initState();
    _frameDeltaProbe.start();
    _fogTransformLogger.start();
    _log.info('FogLayerConnector mounted — diagnostics armed (emission gated on verbose logging)');
  }

  @override
  void dispose() {
    _log.info('FogLayerConnector disposed');
    _fogTransformLogger.stop();
    unawaited(_frameDeltaProbe.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MirkRenderer> rendererAsync = ref.watch(activeMirkRendererProvider);
    final MirkViewportBbox? viewport = ref.watch(mapViewportProvider);
    final AsyncValue<ActiveSessionState> sessionAsync = ref.watch(activeSessionControllerProvider);
    final List<RevealDisc> discs = _watchDiscs(viewport);
    final Fix? currentFix = switch (sessionAsync.value) {
      Tracking(:final Fix? lastFix) => lastFix,
      _ => null,
    };
    return switch (rendererAsync) {
      AsyncData<MirkRenderer>(:final MirkRenderer value) => _buildFogLayer(value, discs, currentFix),
      AsyncError<MirkRenderer>(:final Object error, :final StackTrace stackTrace) => _rendererUnavailable(error, stackTrace),
      _ => _rendererLoading(),
    };
  }

  /// Watches the disc query on the PADDED throttled bbox and returns the list
  /// to paint: the fresh result when resolved, otherwise the last known one.
  /// No bbox yet (adapter not published) → no query, empty list.
  List<RevealDisc> _watchDiscs(MirkViewportBbox? viewport) {
    if (viewport == null) {
      _lastKnownDiscs = const <RevealDisc>[];
      return _logDiscCount(const <RevealDisc>[]);
    }
    final MirkViewportBbox paddedViewport = padMirkViewportBbox(viewport, kMirkFogDiscQueryPaddingFactor);
    final AsyncValue<List<RevealDisc>> discsAsync = ref.watch(discsInViewportProvider(viewport: paddedViewport));
    if (discsAsync.hasValue) {
      final List<RevealDisc>? fresh = discsAsync.value;
      if (fresh != null) _lastKnownDiscs = fresh;
    }
    return _logDiscCount(_lastKnownDiscs ?? const <RevealDisc>[]);
  }

  Widget _buildFogLayer(MirkRenderer renderer, List<RevealDisc> discs, Fix? currentFix) {
    _rendererErrorLogged = false;
    _logRendererState('ready (${renderer.runtimeType})');
    return FogLayer(renderer: renderer, discs: discs, currentFix: currentFix, frameDeltaProbe: _frameDeltaProbe, fogTransformLogger: _fogTransformLogger);
  }

  Widget _rendererLoading() {
    _logRendererState('loading');
    return const SizedBox.shrink();
  }

  /// Expected failure (level 2): the fog stays hidden and the error is logged
  /// once — `activeMirkRendererProvider` resolves again on the next session or
  /// style change.
  Widget _rendererUnavailable(Object error, StackTrace stackTrace) {
    _logRendererState('error');
    if (!_rendererErrorLogged) {
      _rendererErrorLogged = true;
      _log.warning('activeMirkRendererProvider failed — fog hidden until a renderer resolves', error, stackTrace);
    }
    return const SizedBox.shrink();
  }

  List<RevealDisc> _logDiscCount(List<RevealDisc> discs) {
    if (discs.length != _lastLoggedDiscCount) {
      _log.fine('disc snapshot: ${discs.length} disc(s) feeding the FogLayer');
      _lastLoggedDiscCount = discs.length;
    }
    return discs;
  }

  /// INFO on transition only (device diagnostics without a 60 Hz flood).
  void _logRendererState(String state) {
    if (state == _lastLoggedRendererState) return;
    _log.info('renderer ${_lastLoggedRendererState ?? "(initial)"} → $state');
    _lastLoggedRendererState = state;
  }
}

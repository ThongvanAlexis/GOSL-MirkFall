// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-07 — `FogLayerConnector`, the Riverpod boundary of the
// same-canvas fog: watches the active renderer, the throttled viewport bbox, the
// disc query (on the PADDED bbox) and the session fix, and mounts a `FogLayer`
// inside the `FlutterMap` children. Carries the BUG-012 anti-strobe rule from the
// deleted screen-space overlay (last known discs kept while the query reloads).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:logging/logging.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';
import 'package:mirkfall/presentation/widgets/fog_layer_connector.dart';

import '../../fakes/fake_mirk_renderer.dart';

const LatLng _parisCentre = LatLng(48.85, 2.35);
const double _parisZoom = 15.0;
const Duration _frame = Duration(milliseconds: 16);
const String _connectorSourcePath = 'lib/presentation/widgets/fog_layer_connector.dart';
const String _connectorLoggerName = 'presentation.fog_layer_connector';

MirkViewportBbox _parisViewport() => MirkViewportBbox(south: 48.84, west: 2.34, north: 48.86, east: 2.36);

/// The viewport after a small pan — a NEW family key for `discsInViewportProvider`.
MirkViewportBbox _shiftedViewport() => MirkViewportBbox(south: 48.85, west: 2.35, north: 48.87, east: 2.37);

RevealDisc _disc(String id) => RevealDisc(id: id, sessionId: 'sess_connector', lat: 48.85, lon: 2.35, radiusMeters: 25.0, fixedAtUtc: DateTime.utc(2026, 5));

List<RevealDisc> _twoDiscs() => <RevealDisc>[_disc('rvd_a'), _disc('rvd_b')];

const SessionId _sessionId = SessionId('sess_connector');

Fix _fix() => Fix(
  id: FixId.parse('fix_01ARZ3NDEKTSV4RRFFQ69G5FAV'),
  sessionId: _sessionId,
  recordedAtUtc: DateTime.utc(2026, 4, 21, 10, 30),
  recordedAtOffsetMinutes: 120,
  latitude: 48.8566,
  longitude: 2.3522,
  accuracyMeters: 10.0,
  speedMps: 1.0,
  headingDegrees: 0.0,
);

Tracking _tracking({Fix? lastFix}) => Tracking(
  sessionId: _sessionId,
  startedAtUtc: DateTime.utc(2026, 4, 25),
  fixCount: lastFix == null ? 0 : 1,
  distanceFilterMeters: kDefaultDistanceFilterMeters,
  lastFix: lastFix,
);

class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._seed);
  final ActiveSessionState _seed;

  @override
  ActiveSessionState build() => _seed;
}

/// Seeded viewport notifier whose value the test moves after mount (a pan).
class _SeededMapViewport extends MapViewport {
  _SeededMapViewport(this._seed);
  final MirkViewportBbox? _seed;

  @override
  MirkViewportBbox? build() => _seed;

  void push(MirkViewportBbox? bbox) => state = bbox;
}

/// Mounts the connector as a DIRECT child of a real `FlutterMap` (the `FogLayer`
/// needs `MapCamera.of(context)`) under the four provider overrides it watches.
/// Riverpod's automatic retry is disabled so a failing renderer provider stays in
/// `AsyncError` without arming retry timers.
Widget _host({
  required FutureOr<MirkRenderer> Function() renderer,
  required MirkViewportBbox? viewport,
  required FutureOr<List<RevealDisc>> Function(MirkViewportBbox viewport) discs,
  required ActiveSessionState session,
}) => ProviderScope(
  overrides: [
    activeMirkRendererProvider.overrideWith((ref) => renderer()),
    mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
    discsInViewportProvider.overrideWith((ref, MirkViewportBbox viewport) => discs(viewport)),
    activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(session)),
  ],
  retry: (int retryCount, Object error) => null,
  child: const MaterialApp(
    home: FlutterMap(
      options: MapOptions(initialCenter: _parisCentre, initialZoom: _parisZoom),
      children: <Widget>[FogLayerConnector()],
    ),
  ),
);

/// Two frames: one to flush the provider futures, one so the layer has painted.
Future<void> _pumpTwice(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_frame);
}

FogLayer _mountedFogLayer(WidgetTester tester) => tester.widget<FogLayer>(find.byType(FogLayer));

_SeededMapViewport _viewportNotifier(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FogLayerConnector))).read(mapViewportProvider.notifier) as _SeededMapViewport;

void main() {
  testWidgets('renders a FogLayer fed with the renderer, the two discs and the session fix', (WidgetTester tester) async {
    final FakeMirkRenderer renderer = FakeMirkRenderer();
    final Fix fix = _fix();
    await tester.pumpWidget(
      _host(
        renderer: () async => renderer,
        viewport: _parisViewport(),
        discs: (MirkViewportBbox _) async => _twoDiscs(),
        session: _tracking(lastFix: fix),
      ),
    );
    await _pumpTwice(tester);

    final FogLayer layer = _mountedFogLayer(tester);
    expect(layer.discs, hasLength(2));
    expect(layer.currentFix, equals(fix));
    expect(layer.renderer, same(renderer));
    expect(renderer.paintCallCount, greaterThan(0), reason: 'the layer delegates its paint to the provider renderer');
  });

  testWidgets('queries discsInViewportProvider with the PADDED bbox, never the raw throttled viewport', (WidgetTester tester) async {
    final List<MirkViewportBbox> queriedViewports = <MirkViewportBbox>[];
    await tester.pumpWidget(
      _host(
        renderer: () async => FakeMirkRenderer(),
        viewport: _parisViewport(),
        discs: (MirkViewportBbox viewport) async {
          queriedViewports.add(viewport);
          return _twoDiscs();
        },
        session: _tracking(),
      ),
    );
    await _pumpTwice(tester);

    expect(queriedViewports, isNotEmpty);
    final MirkViewportBbox expected = padMirkViewportBbox(_parisViewport(), kMirkFogDiscQueryPaddingFactor);
    expect(queriedViewports.first, equals(expected));
    expect(queriedViewports.any((MirkViewportBbox v) => v == _parisViewport()), isFalse, reason: 'the raw viewport must never be the query key');
    expect(expected.north - expected.south, closeTo(2 * (_parisViewport().north - _parisViewport().south), 1e-9), reason: 'half a viewport on each side');
  });

  testWidgets('keeps the last known discs while the query reloads on a new viewport key (BUG-012 anti-strobe)', (WidgetTester tester) async {
    final Completer<List<RevealDisc>> secondQuery = Completer<List<RevealDisc>>();
    int queryCount = 0;
    await tester.pumpWidget(
      _host(
        renderer: () async => FakeMirkRenderer(),
        viewport: _parisViewport(),
        discs: (MirkViewportBbox _) {
          queryCount++;
          return queryCount == 1 ? Future<List<RevealDisc>>.value(_twoDiscs()) : secondQuery.future;
        },
        session: _tracking(),
      ),
    );
    await _pumpTwice(tester);
    final List<RevealDisc> firstDiscs = _mountedFogLayer(tester).discs;
    expect(firstDiscs, hasLength(2));

    _viewportNotifier(tester).push(_shiftedViewport());
    await _pumpTwice(tester);
    expect(queryCount, equals(2), reason: 'a new viewport key starts a new query');
    final FogLayer duringReload = _mountedFogLayer(tester);
    expect(duringReload.discs, hasLength(2), reason: 'never an empty list while the fresh query is loading');
    expect(identical(duringReload.discs, firstDiscs), isTrue, reason: 'the SAME list instance is kept (no painter churn)');

    secondQuery.complete(<RevealDisc>[_disc('rvd_c')]);
    await _pumpTwice(tester);
    expect(_mountedFogLayer(tester).discs, hasLength(1), reason: 'the fresh result replaces the cached list once resolved');
  });

  testWidgets('renders SizedBox.shrink (no FogLayer) while the renderer provider is loading', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        renderer: () => Completer<MirkRenderer>().future,
        viewport: _parisViewport(),
        discs: (MirkViewportBbox _) async => _twoDiscs(),
        session: _tracking(),
      ),
    );
    await _pumpTwice(tester);

    expect(find.byType(FogLayer), findsNothing);
    expect(find.descendant(of: find.byType(FogLayerConnector), matching: find.byType(SizedBox)), findsOneWidget);
  });

  testWidgets('renders SizedBox.shrink and logs ONE warning when the renderer provider errors', (WidgetTester tester) async {
    final List<LogRecord> warnings = <LogRecord>[];
    final StreamSubscription<LogRecord> subscription = Logger.root.onRecord.listen((LogRecord record) {
      if (record.loggerName == _connectorLoggerName && record.level == Level.WARNING) warnings.add(record);
    });
    addTearDown(subscription.cancel);

    await tester.pumpWidget(
      _host(
        renderer: () async => throw StateError('shader program failed to load'),
        viewport: _parisViewport(),
        discs: (MirkViewportBbox _) async => _twoDiscs(),
        session: _tracking(),
      ),
    );
    await _pumpTwice(tester);
    expect(find.byType(FogLayer), findsNothing);
    expect(find.descendant(of: find.byType(FogLayerConnector), matching: find.byType(SizedBox)), findsOneWidget);
    expect(warnings, hasLength(1));

    // Two more rebuilds of the connector (viewport pans) must not repeat the warning.
    _viewportNotifier(tester).push(_shiftedViewport());
    await _pumpTwice(tester);
    _viewportNotifier(tester).push(_parisViewport());
    await _pumpTwice(tester);
    expect(warnings, hasLength(1), reason: 'the renderer error is logged once, not per build');
  });

  testWidgets('viewport == null (adapter not published yet) renders a FogLayer with no disc and no fix, without querying', (WidgetTester tester) async {
    int queryCount = 0;
    await tester.pumpWidget(
      _host(
        renderer: () async => FakeMirkRenderer(),
        viewport: null,
        discs: (MirkViewportBbox _) async {
          queryCount++;
          return _twoDiscs();
        },
        session: _tracking(),
      ),
    );
    await _pumpTwice(tester);

    final FogLayer layer = _mountedFogLayer(tester);
    expect(layer.discs, isEmpty);
    expect(layer.currentFix, isNull);
    expect(queryCount, equals(0), reason: 'no bbox → no DB query');
  });

  test('fog_layer_connector.dart imports neither flutter_map nor latlong2 (MAP-06 perimeter)', () {
    final List<String> importLines = File(_connectorSourcePath).readAsLinesSync().where((String line) => line.trimLeft().startsWith('import ')).toList();
    expect(importLines, isNotEmpty);
    expect(importLines.where((String line) => line.contains('package:flutter_map/')), isEmpty);
    expect(importLines.where((String line) => line.contains('package:latlong2/')), isEmpty);
    expect(importLines.where((String line) => line.contains('fog_layer.dart')), isNotEmpty, reason: 'the connector mounts the FogLayer');
  });
}

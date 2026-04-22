// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:mirkfall/domain/map/map_view.dart';

/// In-memory [MapView] double for widget + controller tests.
///
/// Records every method invocation in a public observable so tests can
/// assert ordering, arguments, and counts without spinning up a real
/// MapLibre surface. The subscribable [viewportUpdates] stream is backed
/// by a broadcast controller that tests drive via [pushViewport].
///
/// Conforms to the `implements` convention from Phase 05's
/// `FakeLocationStream` — never extends a concrete adapter.
class FakeMapView implements MapView {
  FakeMapView({MapTheme initialTheme = const MapThemeStandard()}) : _currentTheme = initialTheme;

  final StreamController<({double latitude, double longitude, double zoom})> _viewportCtrl =
      StreamController<({double latitude, double longitude, double zoom})>.broadcast();

  MapTheme _currentTheme;
  bool _followMe = false;
  bool _disposed = false;
  ({double latitude, double longitude, double zoom})? _lastViewport;

  /// Ordered record of every observable method call — lets tests assert
  /// call ordering (e.g. `showMap` precedes `setUserLocation`).
  final List<String> methodLog = <String>[];

  /// Every argument passed to [showMap] (including `null` — world
  /// fallback). Length equals the number of calls.
  final List<CountryCode?> showMapInvocations = <CountryCode?>[];

  /// Every argument triple passed to [moveCameraTo].
  final List<CameraMove> cameraMovesObserved = <CameraMove>[];

  /// POI ids passed to [addPointOfInterest] in order.
  final List<String> poiAddObservations = <String>[];

  /// POI ids passed to [removePointOfInterest] in order.
  final List<String> poiRemoveObservations = <String>[];

  /// Last [Fix] supplied to [setUserLocation]. `null` means the caller
  /// either never set a fix or explicitly cleared it.
  Fix? lastUserLocationSet;

  /// Last polygon supplied to [markVisited]. `null` when no call was made.
  List<({double latitude, double longitude})>? lastVisitedPolygon;

  /// True once [dispose] has been called. Idempotent — second call is a
  /// no-op.
  bool get disposedFlag => _disposed;

  /// Currently-applied theme. Tests inject the initial value via ctor,
  /// read back via this getter after [setTheme] calls.
  MapTheme get currentTheme => _currentTheme;

  /// True when follow-me-camera is active.
  bool get followMeEnabled => _followMe;

  /// Pushes a viewport update event onto [viewportUpdates] so subscribers
  /// observe a camera-idle event. Also updates the value that
  /// [queryViewport] will return (matches real MapLibre semantics — the
  /// last idle camera IS the viewport until the next gesture).
  void pushViewport({required double latitude, required double longitude, required double zoom}) {
    final ({double latitude, double longitude, double zoom}) v = (latitude: latitude, longitude: longitude, zoom: zoom);
    _lastViewport = v;
    _viewportCtrl.add(v);
  }

  @override
  Future<void> showMap(CountryCode? country) async {
    _checkNotDisposed();
    methodLog.add('showMap(${country?.value ?? 'null'})');
    showMapInvocations.add(country);
  }

  @override
  Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom}) async {
    _checkNotDisposed();
    methodLog.add('moveCameraTo($latitude, $longitude, $zoom)');
    cameraMovesObserved.add(CameraMove(latitude: latitude, longitude: longitude, zoom: zoom, timestamp: DateTime.now().toUtc()));
  }

  @override
  Future<void> jumpCameraTo({required double latitude, required double longitude, required double zoom}) async {
    _checkNotDisposed();
    methodLog.add('jumpCameraTo($latitude, $longitude, $zoom)');
    // Record jumps in the same observation queue as animated moves —
    // tests that assert "camera moved at least once" work for either
    // animation path.
    cameraMovesObserved.add(CameraMove(latitude: latitude, longitude: longitude, zoom: zoom, timestamp: DateTime.now().toUtc()));
  }

  @override
  Future<void> setTheme(MapTheme theme) async {
    _checkNotDisposed();
    methodLog.add('setTheme(${theme.toJsonString()})');
    _currentTheme = theme;
  }

  @override
  Future<void> setUserLocation(Fix? fix) async {
    _checkNotDisposed();
    methodLog.add('setUserLocation(${fix?.id.value ?? 'null'})');
    lastUserLocationSet = fix;
  }

  @override
  Future<({double latitude, double longitude, double zoom})> queryViewport() async {
    _checkNotDisposed();
    methodLog.add('queryViewport');
    return _lastViewport ?? (latitude: 0.0, longitude: 0.0, zoom: 0.0);
  }

  @override
  Stream<({double latitude, double longitude, double zoom})> get viewportUpdates => _viewportCtrl.stream;

  @override
  Future<void> markVisited(List<({double latitude, double longitude})> polygon) async {
    _checkNotDisposed();
    methodLog.add('markVisited(${polygon.length} pts)');
    lastVisitedPolygon = List<({double latitude, double longitude})>.from(polygon);
  }

  @override
  Future<void> addPointOfInterest({required String id, required double latitude, required double longitude, required String iconId}) async {
    _checkNotDisposed();
    methodLog.add('addPointOfInterest($id)');
    poiAddObservations.add(id);
  }

  @override
  Future<void> removePointOfInterest(String id) async {
    _checkNotDisposed();
    methodLog.add('removePointOfInterest($id)');
    poiRemoveObservations.add(id);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    methodLog.add('dispose');
    await _viewportCtrl.close();
  }

  @override
  bool get isFollowMeEnabled => _followMe;

  @override
  Future<void> setFollowMeEnabled(bool enabled) async {
    _checkNotDisposed();
    methodLog.add('setFollowMeEnabled($enabled)');
    _followMe = enabled;
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('FakeMapView: method called after dispose()');
    }
  }
}

/// Snapshot of a single [MapView.moveCameraTo] invocation — captured for
/// test inspection via [FakeMapView.cameraMovesObserved].
class CameraMove {
  const CameraMove({required this.latitude, required this.longitude, required this.zoom, required this.timestamp});

  final double latitude;
  final double longitude;
  final double zoom;
  final DateTime timestamp;

  @override
  String toString() => 'CameraMove($latitude, $longitude, zoom=$zoom, at=$timestamp)';
}

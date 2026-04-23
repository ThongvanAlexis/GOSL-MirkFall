// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:mirkfall/domain/map/map_view.dart';

import 'fake_map_view.dart';

void main() {
  group('FakeMapView basics', () {
    test('construction records initial theme and empty observables', () {
      final FakeMapView fake = FakeMapView();
      expect(fake.currentTheme, isA<MapThemeStandard>());
      expect(fake.followMeEnabled, isFalse);
      expect(fake.disposedFlag, isFalse);
      expect(fake.methodLog, isEmpty);
      expect(fake.showMapInvocations, isEmpty);
      expect(fake.cameraMovesObserved, isEmpty);
    });

    test('showMap(CountryCode) records the invocation', () async {
      final FakeMapView fake = FakeMapView();
      await fake.showMap(CountryCode.parse('fra'));
      expect(fake.showMapInvocations, hasLength(1));
      expect(fake.showMapInvocations.single!.value, equals('fra'));
      expect(fake.methodLog, contains('showMap(fra)'));
    });

    test('showMap(null) records a world-fallback call', () async {
      final FakeMapView fake = FakeMapView();
      await fake.showMap(null);
      expect(fake.showMapInvocations, hasLength(1));
      expect(fake.showMapInvocations.single, isNull);
      expect(fake.methodLog, contains('showMap(null)'));
    });

    test('moveCameraTo records lat/lon/zoom with a timestamp', () async {
      final FakeMapView fake = FakeMapView();
      await fake.moveCameraTo(latitude: 48.85, longitude: 2.35, zoom: 12);
      expect(fake.cameraMovesObserved, hasLength(1));
      final CameraMove m = fake.cameraMovesObserved.last;
      expect(m.latitude, closeTo(48.85, 1e-9));
      expect(m.longitude, closeTo(2.35, 1e-9));
      expect(m.zoom, equals(12));
      expect(m.timestamp.isUtc, isTrue);
    });

    test('setTheme updates currentTheme', () async {
      final FakeMapView fake = FakeMapView();
      await fake.setTheme(const MapThemeRpgParchment());
      expect(fake.currentTheme, isA<MapThemeRpgParchment>());
      expect(fake.methodLog.last, equals('setTheme(rpgParchment)'));
    });

    test('addPointOfInterest + removePointOfInterest observe ids', () async {
      final FakeMapView fake = FakeMapView();
      await fake.addPointOfInterest(id: 'm1', latitude: 0, longitude: 0, iconId: 'flag');
      await fake.addPointOfInterest(id: 'm2', latitude: 0, longitude: 0, iconId: 'pin');
      await fake.removePointOfInterest('m1');
      expect(fake.poiAddObservations, equals(<String>['m1', 'm2']));
      expect(fake.poiRemoveObservations, equals(<String>['m1']));
    });

    test('setFollowMeEnabled flips the getter', () async {
      final FakeMapView fake = FakeMapView();
      expect(fake.isFollowMeEnabled, isFalse);
      await fake.setFollowMeEnabled(true);
      expect(fake.isFollowMeEnabled, isTrue);
    });

    test('queryViewport returns last-pushed viewport', () async {
      final FakeMapView fake = FakeMapView();
      fake.pushViewport(latitude: 10.0, longitude: 20.0, zoom: 5.0);
      final ({double latitude, double longitude, double zoom}) v = await fake.queryViewport();
      expect(v.latitude, equals(10.0));
      expect(v.longitude, equals(20.0));
      expect(v.zoom, equals(5.0));
    });

    test('viewportUpdates stream emits pushed viewports', () async {
      final FakeMapView fake = FakeMapView();
      final Future<({double latitude, double longitude, double zoom})> next = fake.viewportUpdates.first;
      fake.pushViewport(latitude: 1.0, longitude: 2.0, zoom: 3.0);
      final ({double latitude, double longitude, double zoom}) v = await next;
      expect(v.latitude, equals(1.0));
      expect(v.longitude, equals(2.0));
      expect(v.zoom, equals(3.0));
    });

    test('markVisited captures the polygon', () async {
      final FakeMapView fake = FakeMapView();
      await fake.markVisited(<({double latitude, double longitude})>[(latitude: 0.0, longitude: 0.0), (latitude: 1.0, longitude: 1.0)]);
      expect(fake.lastVisitedPolygon, hasLength(2));
    });

    test('dispose is idempotent', () async {
      final FakeMapView fake = FakeMapView();
      await fake.dispose();
      await fake.dispose();
      expect(fake.disposedFlag, isTrue);
      // Only one 'dispose' entry in the log — second call is a no-op.
      expect(fake.methodLog.where((String s) => s == 'dispose'), hasLength(1));
    });

    test('calls after dispose silently no-op AND record in postDisposeInvocations (row #4)', () async {
      // §3 row #4 regression: pre-fix, FakeMapView threw StateError on
      // post-dispose calls while MapLibreMapView._aliveOrLog silently
      // returned. Tests never exercised the production silent-ignore
      // path. Now FakeMapView matches: silent return + record in
      // postDisposeInvocations so assertions remain observable.
      final FakeMapView fake = FakeMapView();
      await fake.dispose();
      final int logLenPreDisposedCall = fake.methodLog.length;

      await fake.showMap(null);
      await fake.setFollowMeEnabled(true);
      await fake.moveCameraTo(latitude: 0, longitude: 0, zoom: 0);

      // No StateError, no methodLog growth, no showMapInvocations entry.
      expect(fake.methodLog.length, logLenPreDisposedCall);
      expect(fake.showMapInvocations, isEmpty);

      // The silent-ignore path was exercised — observable via the new
      // postDisposeInvocations list.
      expect(fake.postDisposeInvocations, containsAll(<String>['showMap', 'setFollowMeEnabled', 'moveCameraTo']));
    });
  });

  group('FakeMapView as MapView (type conformance)', () {
    test('FakeMapView implements MapView — compile-time witness', () {
      // If MapView grows a new abstract method, this instantiation
      // stops compiling with missing_concrete_implementation. Runtime
      // expect (isA<MapView>) is a smoke sanity check on the type
      // relationship.
      final MapView asPort = FakeMapView();
      expect(asPort, isA<MapView>());
    });
  });
}

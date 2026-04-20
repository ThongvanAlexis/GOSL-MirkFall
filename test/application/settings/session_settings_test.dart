// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 06 Should #9 (Agent #2 #9) regression guard.
///
/// Covers the `test/application/settings/**` directory gap surfaced by
/// the audit: `SessionSettings` notifier (SharedPreferences-backed,
/// distance-filter clamping, permission_flow_completed + oem_guidance_seen
/// flags) previously had ZERO test coverage.
///
/// Three invariants anchored here:
///  1. `clampDistanceFilterMeters` boundary behaviour — raw values
///     outside `[kMinDistanceFilterMeters, kMaxDistanceFilterMeters]`
///     are clamped at the edges (Phase 05 STATE.md asked for a regression
///     test on this).
///  2. SharedPreferences round-trip — setDistanceFilterMeters + the
///     one-shot flag setters persist to SharedPreferences and the
///     notifier's state reflects the new values on the next `future`
///     resolution.
///  3. Default fallback when no key is set — falls back to
///     `kDefaultDistanceFilterMeters`, re-clamped through the same
///     boundary guard (defensive against a future drift between
///     `kDefaultDistanceFilterMeters` and `[kMin, kMax]`).
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('clampDistanceFilterMeters (boundary behaviour)', () {
    test('clampsBelowMinimumToMinimum', () {
      expect(clampDistanceFilterMeters(0), kMinDistanceFilterMeters);
      expect(clampDistanceFilterMeters(-999), kMinDistanceFilterMeters);
      expect(clampDistanceFilterMeters(kMinDistanceFilterMeters - 1), kMinDistanceFilterMeters);
    });

    test('clampsAboveMaximumToMaximum', () {
      expect(clampDistanceFilterMeters(kMaxDistanceFilterMeters + 1), kMaxDistanceFilterMeters);
      expect(clampDistanceFilterMeters(99999), kMaxDistanceFilterMeters);
    });

    test('passesThroughInRangeValues', () {
      expect(clampDistanceFilterMeters(kMinDistanceFilterMeters), kMinDistanceFilterMeters);
      expect(clampDistanceFilterMeters(kMaxDistanceFilterMeters), kMaxDistanceFilterMeters);
      const int midpoint = (kMinDistanceFilterMeters + kMaxDistanceFilterMeters) ~/ 2;
      expect(clampDistanceFilterMeters(midpoint), midpoint);
    });

    test('kDefaultDistanceFilterMetersIsWithinValidRange', () {
      // Defensive: if kDefault drifts out of [kMin, kMax], the build()
      // fallback would persist a clamped value instead of the declared
      // default. This test fails loudly if a future refactor breaks
      // that invariant.
      expect(kDefaultDistanceFilterMeters, greaterThanOrEqualTo(kMinDistanceFilterMeters));
      expect(kDefaultDistanceFilterMeters, lessThanOrEqualTo(kMaxDistanceFilterMeters));
    });
  });

  group('SessionSettings notifier (SharedPreferences persistence)', () {
    test('buildReturnsDefaultSnapshotWhenNoPrefsSet', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final snapshot = await container.read(sessionSettingsProvider.future);

      expect(snapshot.distanceFilterMeters, kDefaultDistanceFilterMeters);
      expect(snapshot.permissionFlowCompleted, isFalse);
      expect(snapshot.oemGuidanceSeen, isFalse);
    });

    test('buildClampsAnOutOfRangeStoredValue', () async {
      // Defensive regression: a past build / foreign import wrote a
      // value above kMaxDistanceFilterMeters. On re-read we must
      // surface the clamped value rather than propagating an illegal
      // slider input into the controller.
      SharedPreferences.setMockInitialValues(<String, Object>{'distanceFilter_meters': kMaxDistanceFilterMeters + 50});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final snapshot = await container.read(sessionSettingsProvider.future);

      expect(snapshot.distanceFilterMeters, kMaxDistanceFilterMeters);
    });

    test('setDistanceFilterMetersPersistsAndUpdatesState', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionSettingsProvider.future);
      await container.read(sessionSettingsProvider.notifier).setDistanceFilterMeters(42);

      final snapshot = await container.read(sessionSettingsProvider.future);
      expect(snapshot.distanceFilterMeters, 42);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('distanceFilter_meters'), 42, reason: 'setter must persist through SharedPreferences');
    });

    test('setDistanceFilterMetersClampsOutOfRangeInput', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionSettingsProvider.future);
      await container.read(sessionSettingsProvider.notifier).setDistanceFilterMeters(kMaxDistanceFilterMeters + 1000);

      final snapshot = await container.read(sessionSettingsProvider.future);
      expect(snapshot.distanceFilterMeters, kMaxDistanceFilterMeters, reason: 'setter must clamp before persisting');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('distanceFilter_meters'), kMaxDistanceFilterMeters, reason: 'SharedPreferences must hold the clamped value');
    });

    test('markPermissionFlowCompletedPersistsTrue', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionSettingsProvider.future);
      await container.read(sessionSettingsProvider.notifier).markPermissionFlowCompleted();

      final snapshot = await container.read(sessionSettingsProvider.future);
      expect(snapshot.permissionFlowCompleted, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('permission_flow_completed'), isTrue);
    });

    test('markOemGuidanceSeenPersistsTrue', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionSettingsProvider.future);
      await container.read(sessionSettingsProvider.notifier).markOemGuidanceSeen();

      final snapshot = await container.read(sessionSettingsProvider.future);
      expect(snapshot.oemGuidanceSeen, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('oem_guidance_seen'), isTrue);
    });

    test('buildSurfacesPreviouslyPersistedFlags', () async {
      // Cold-start hydration: app restarts, SharedPreferences still
      // holds the flags from a previous session — build() must reflect
      // them in the snapshot.
      SharedPreferences.setMockInitialValues(const <String, Object>{'distanceFilter_meters': 25, 'permission_flow_completed': true, 'oem_guidance_seen': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final snapshot = await container.read(sessionSettingsProvider.future);

      expect(snapshot.distanceFilterMeters, 25);
      expect(snapshot.permissionFlowCompleted, isTrue);
      expect(snapshot.oemGuidanceSeen, isTrue);
    });
  });
}

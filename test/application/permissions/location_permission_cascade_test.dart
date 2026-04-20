// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Phase 06 Adversarial Test #2 — permanent regression guard for the
/// `requestLocationAlways` permission cascade.
///
/// The cascade order is a three-step invariant (see
/// `lib/application/permissions/location_permission_flow.dart` docstring):
///
///   1. `Permission.notification` (Android 13+ POST_NOTIFICATIONS,
///      best-effort; denial never blocks location flow).
///   2. `Permission.locationWhenInUse` (foreground location — prerequisite
///      for always on Android 10+; silently ignored otherwise).
///   3. `Permission.locationAlways` (background location — only requested
///      when whenInUse is `granted`).
///
/// A silent reorder or step-skip regression has no compile-time detector.
/// The existing `location_permission_flow_test.dart` suite covers
/// happy-path + individual denial routes but does NOT assert the
/// **invocation count** as a first-class expectation before checking the
/// outcome — so a refactor that (for example) swallowed the whenInUse
/// step and jumped straight to always would silently return "denied"
/// WITHOUT the test catching the skipped step.
///
/// This test fixes that gap with the Phase 04 inertness-guard idiom:
///
///   - Intermediate `expect(fake.invocationCount == N, ...)` BEFORE the
///     outcome assertion.
///   - Without the intermediate expect, a future refactor that bypasses
///     a step could keep the outcome correct by coincidence.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/permissions/location_permission_flow.dart';
import 'package:mirkfall/domain/errors/location_permission_errors.dart';
import 'package:permission_handler/permission_handler.dart';

/// Fake `PermissionRequester` that records every invocation (in order)
/// and returns the programmed status per permission.
///
/// `invocationCount` is read BEFORE the outcome assertion in every test
/// — see inertness-guard docstring above.
class _CountingPermissionRequester {
  _CountingPermissionRequester(this._responseByPermission);

  final Map<Permission, PermissionStatus> _responseByPermission;
  final List<Permission> invocations = <Permission>[];

  int get invocationCount => invocations.length;

  Future<PermissionStatus> request(Permission permission) async {
    invocations.add(permission);
    final PermissionStatus? response = _responseByPermission[permission];
    if (response == null) {
      fail('PermissionRequester called with unexpected permission: $permission. Registered: ${_responseByPermission.keys.toList()}');
    }
    return response;
  }
}

void main() {
  group('Permission cascade regression guard (Phase 06 Test #2)', () {
    test('notification-denied scenario still proceeds to whenInUse and always (best-effort notification)', () async {
      // Scenario: notification denied (best-effort — does not block
      // flow); whenInUse granted; always granted. Expected: 3
      // invocations in strict order.
      final _CountingPermissionRequester fake = _CountingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.denied,
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.granted,
      });

      final LocationPermissionOutcome outcome = await requestLocationAlways(requestPermission: fake.request);

      // Inertness guard: invocation count assert BEFORE the outcome assert.
      // If a future refactor skipped the notification step silently, the
      // outcome would still be `granted` but the count would reveal the
      // regression.
      expect(
        fake.invocationCount,
        3,
        reason: 'permission flow skipped at least one step — silent ignore regression returned, test would be silently inert. Invocations: ${fake.invocations}',
      );
      expect(fake.invocations, <Permission>[Permission.notification, Permission.locationWhenInUse, Permission.locationAlways]);
      expect(outcome, LocationPermissionOutcome.granted);
    });

    test('whenInUse-denied short-circuits the cascade — always NEVER requested', () async {
      // Scenario: notification granted; whenInUse denied. Expected: 2
      // invocations (notification + whenInUse), always MUST NOT be
      // requested (Android 10+ silently ignores a direct Always request).
      final _CountingPermissionRequester fake = _CountingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.denied,
      });

      final LocationPermissionOutcome outcome = await requestLocationAlways(requestPermission: fake.request);

      // Inertness guard: count = 2 proves the flow short-circuited BEFORE
      // the always step. Without this assert, a regression that re-
      // requests always (despite whenInUse denial) would still return
      // "denied" on the happy-case path and silently pass the test.
      expect(
        fake.invocationCount,
        2,
        reason:
            'permission flow requested locationAlways despite whenInUse denial — regression would be silent if we only checked outcome. Invocations: ${fake.invocations}',
      );
      expect(fake.invocations, <Permission>[Permission.notification, Permission.locationWhenInUse]);
      expect(outcome, LocationPermissionOutcome.denied);
    });

    test('whenInUse permanentlyDenied → permanentlyDenied outcome, no always call', () async {
      // Scenario: notification granted; whenInUse permanentlyDenied.
      // Expected: 2 invocations, outcome permanentlyDenied.
      final _CountingPermissionRequester fake = _CountingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
      });

      final LocationPermissionOutcome outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(
        fake.invocationCount,
        2,
        reason: 'whenInUse permanentlyDenied must short-circuit BEFORE always; test silently inert if count != 2. Invocations: ${fake.invocations}',
      );
      expect(fake.invocations, <Permission>[Permission.notification, Permission.locationWhenInUse]);
      expect(outcome, LocationPermissionOutcome.permanentlyDenied);
    });

    test('always-only denied → whileInUseOnly outcome, 3 invocations', () async {
      // Scenario: notification granted; whenInUse granted; always denied.
      // Expected: 3 invocations, outcome whileInUseOnly.
      final _CountingPermissionRequester fake = _CountingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.denied,
      });

      final LocationPermissionOutcome outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(
        fake.invocationCount,
        3,
        reason: 'always-denied path must still invoke all 3 steps; test silently inert if count != 3. Invocations: ${fake.invocations}',
      );
      expect(fake.invocations, <Permission>[Permission.notification, Permission.locationWhenInUse, Permission.locationAlways]);
      expect(outcome, LocationPermissionOutcome.whileInUseOnly);
    });

    test('always permanentlyDenied (restricted-status proxy) → permanentlyDenied outcome, 3 invocations', () async {
      // Scenario: notification granted; whenInUse granted; always
      // permanentlyDenied (iOS "Don't Ask Again" / Android restricted
      // equivalent). Expected: 3 invocations, outcome permanentlyDenied.
      // This scenario also acts as the restricted-status coverage row —
      // `permission_handler` maps iOS restricted to permanentlyDenied in
      // the outcome mapping, so the cascade behaves the same.
      final _CountingPermissionRequester fake = _CountingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.permanentlyDenied,
      });

      final LocationPermissionOutcome outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(
        fake.invocationCount,
        3,
        reason: 'always permanentlyDenied must still record 3 invocations; silent inert if count != 3. Invocations: ${fake.invocations}',
      );
      expect(outcome, LocationPermissionOutcome.permanentlyDenied);
    });
  });
}

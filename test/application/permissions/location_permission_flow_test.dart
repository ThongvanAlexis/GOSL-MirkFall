// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/permissions/location_permission_flow.dart';
import 'package:mirkfall/domain/errors/location_permission_errors.dart';
import 'package:permission_handler/permission_handler.dart';

/// Captures every permission requested via [PermissionRequester].
///
/// Returns programmed [PermissionStatus] values in the order they were
/// registered, keyed by [Permission]. Missing-registration triggers a
/// hard failure so tests never silently pass against an unexpected
/// request.
class _RecordingPermissionRequester {
  _RecordingPermissionRequester(this._responseByPermission);

  final Map<Permission, PermissionStatus> _responseByPermission;
  final List<Permission> requested = <Permission>[];

  Future<PermissionStatus> request(Permission permission) async {
    requested.add(permission);
    final response = _responseByPermission[permission];
    if (response == null) {
      fail(
        'PermissionRequester called with unexpected permission: $permission. '
        'Registered permissions: ${_responseByPermission.keys.toList()}',
      );
    }
    return response;
  }
}

void main() {
  group('requestLocationAlways', () {
    test('grantsFullAlwaysOnTwoStepSuccess', () async {
      final fake = _RecordingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.granted,
      });

      final outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(outcome, LocationPermissionOutcome.granted);
      expect(fake.requested, <Permission>[Permission.notification, Permission.locationWhenInUse, Permission.locationAlways]);
    });

    test('returnsDeniedIfWhenInUseDenied', () async {
      final fake = _RecordingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.denied,
      });

      final outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(outcome, LocationPermissionOutcome.denied);
    });

    test('returnsPermanentlyDeniedIfWhenInUsePermanentlyDenied', () async {
      final fake = _RecordingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
      });

      final outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(outcome, LocationPermissionOutcome.permanentlyDenied);
    });

    test('returnsWhileInUseOnlyIfAlwaysDeclined', () async {
      final fake = _RecordingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.denied,
      });

      final outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(outcome, LocationPermissionOutcome.whileInUseOnly);
    });

    test('returnsPermanentlyDeniedIfAlwaysPermanentlyDenied', () async {
      final fake = _RecordingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.permanentlyDenied,
      });

      final outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(outcome, LocationPermissionOutcome.permanentlyDenied);
    });

    test('neverRequestsAlwaysIfWhenInUseNotGrantedFirst', () async {
      // Android 10+ silently ignores a direct Always request; the chain
      // MUST request whenInUse BEFORE always and only proceed to always
      // if whenInUse was granted. Regression guard.
      final fake = _RecordingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.denied,
      });

      await requestLocationAlways(requestPermission: fake.request);

      expect(fake.requested.length, 2, reason: 'Always must NOT be requested when whenInUse is denied');
      expect(fake.requested, <Permission>[Permission.notification, Permission.locationWhenInUse]);
    });

    test('requestsNotificationFirstAndDenialDoesNotBlockLocationFlow', () async {
      // Android 13+ POST_NOTIFICATIONS is best-effort : the session must
      // start even if the user denies notifications. Regression guard
      // that notification is requested FIRST and its denial does not
      // change the outcome.
      final fake = _RecordingPermissionRequester(<Permission, PermissionStatus>{
        Permission.notification: PermissionStatus.denied,
        Permission.locationWhenInUse: PermissionStatus.granted,
        Permission.locationAlways: PermissionStatus.granted,
      });

      final outcome = await requestLocationAlways(requestPermission: fake.request);

      expect(outcome, LocationPermissionOutcome.granted);
      expect(fake.requested.first, Permission.notification, reason: 'Notification must be requested FIRST so both OS dialogs appear back-to-back in the rationale flow');
    });
  });
}

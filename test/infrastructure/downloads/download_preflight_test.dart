// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/infrastructure/platform/disk_space_checker.dart';

/// Stand-in for the Plan 07-04 preflight check: given a
/// [DiskSpaceChecker] result and an expected [neededBytes], raise
/// [DiskSpaceInsufficientException] when free < needed * margin.
/// The real implementation lives inside `PmtilesDownloadController`
/// (Task 3). This test proves the boundary math in isolation without
/// having to spin up the full controller.
Future<void> preflightOrThrow({required DiskSpaceChecker checker, required String path, required int neededBytes}) async {
  final int free = await checker.freeBytes(path: path);
  final int withMargin = (neededBytes * kDiskSpaceSafetyMarginMultiplier).ceil();
  if (free < withMargin) {
    throw DiskSpaceInsufficientException(neededBytes: withMargin, freeBytes: free);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('download preflight', () {
    test('passes when free bytes comfortably exceed needed × margin', () async {
      const MethodChannel channel = MethodChannel(kDiskSpaceChannelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        return 10_000_000_000; // 10 GB free
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

      final DiskSpaceChecker checker = DiskSpaceChecker();
      // 1 GB needed × 1.1 = 1.1 GB — under 10 GB. Expect no throw.
      await preflightOrThrow(checker: checker, path: '/sandbox', neededBytes: 1_000_000_000);
    });

    test('throws DiskSpaceInsufficientException when free < needed × 1.1', () async {
      const MethodChannel channel = MethodChannel(kDiskSpaceChannelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        return 10_000_000; // 10 MB free
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

      final DiskSpaceChecker checker = DiskSpaceChecker();
      // 1 GB needed → margin-adjusted 1.1 GB. Only 10 MB free → throws.
      await expectLater(preflightOrThrow(checker: checker, path: '/sandbox', neededBytes: 1_000_000_000), throwsA(isA<DiskSpaceInsufficientException>()));
    });

    test('honours the safety-margin multiplier — passes at exactly needed × 1.1', () async {
      const MethodChannel channel = MethodChannel(kDiskSpaceChannelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        // Exactly needed × 1.1
        return (1000 * kDiskSpaceSafetyMarginMultiplier).ceil();
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

      final DiskSpaceChecker checker = DiskSpaceChecker();
      // Boundary case: free == needed × 1.1 ⇒ should pass (strict <).
      await preflightOrThrow(checker: checker, path: '/', neededBytes: 1000);
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// MethodChannel name shared with Android Kotlin + iOS Swift sides.
/// Triple-source truth: any change must land on all three sides in
/// lockstep (Dart `_channel`, Kotlin `DiskSpaceChannel.CHANNEL`, Swift
/// `DiskSpaceChannel.channelName`).
const String kDiskSpaceChannelName = 'app.gosl.mirkfall/disk_space';

/// Hand-rolled disk-space checker.
///
/// Closes RESEARCH Open Question #6: instead of pulling in a full
/// package for a one-method contract, MirkFall wires a thin platform
/// channel on each side:
/// - Android: `android.os.StatFs(path).availableBytes`
/// - iOS: `FileManager.default.attributesOfFileSystem(forPath:)` →
///   `FileAttributeKey.systemFreeSize`
///
/// Called before every country download (Plan 07-04) to enforce the
/// `kDiskSpaceSafetyMarginMultiplier` (1.1× expected size) policy.
class DiskSpaceChecker {
  DiskSpaceChecker({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(kDiskSpaceChannelName);

  static final Logger _log = Logger('infrastructure.platform.disk_space_checker');

  final MethodChannel _channel;

  /// Timeout for the platform call. 5 s is conservative — `StatFs` and
  /// `attributesOfFileSystem` both complete in sub-millisecond on
  /// consumer hardware; a pending call past 5 s signals a wedged native
  /// side rather than a slow filesystem.
  static const Duration _kTimeout = Duration(seconds: 5);

  /// Returns the free bytes reported by the filesystem at [path].
  ///
  /// Throws:
  /// - [TimeoutException] when the native side doesn't respond within
  ///   [_kTimeout].
  /// - [DiskSpaceCheckException] wrapping any `PlatformException` or
  ///   other native error.
  Future<int> freeBytes({required String path}) async {
    try {
      final Object? raw = await _channel.invokeMethod<Object?>('freeBytes', <String, Object>{'path': path}).timeout(_kTimeout);
      if (raw is int) return raw;
      // Some platform-channel setups auto-box to num; coerce to int.
      if (raw is num) return raw.toInt();
      throw DiskSpaceCheckException('unexpected platform result type: ${raw?.runtimeType}');
    } on TimeoutException {
      _log.warning('freeBytes: timed out after ${_kTimeout.inSeconds}s for path=$path');
      rethrow;
    } on PlatformException catch (e, st) {
      _log.warning('freeBytes platform error: ${e.code} ${e.message}', e, st);
      throw DiskSpaceCheckException('platform error: code=${e.code}, message=${e.message}');
    } on MissingPluginException catch (e, st) {
      _log.warning('freeBytes: native handler missing', e, st);
      throw const DiskSpaceCheckException('native handler missing on this platform');
    }
  }
}

/// Recoverable exception surfaced when the disk-space probe fails.
/// Implements [Exception] per CLAUDE.md §Error handling — the caller
/// (Plan 07-04 download controller) surfaces this as a user-facing
/// "impossible to check disk space" banner + aborts the download.
class DiskSpaceCheckException implements Exception {
  const DiskSpaceCheckException(this.message);
  final String message;

  @override
  String toString() => 'DiskSpaceCheckException($message)';
}

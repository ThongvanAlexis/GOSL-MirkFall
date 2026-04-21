// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// MethodChannel name shared with iOS Swift side. Triple-source truth:
/// the Dart constant here, the Swift `IosBackupExcluderChannel.channelName`,
/// and (by convention) the CI `check_platform_manifests.dart` entries must
/// stay in lockstep.
const String kIosBackupExcluderChannelName = 'app.gosl.mirkfall/ios_backup_excluder';

/// Sets `NSURLIsExcludedFromBackupKey=true` on files that MirkFall
/// manages but does not want iCloud to back up.
///
/// Closes RESEARCH Open Question #3: per-country PMTiles bundles can be
/// hundreds of MB to 1.5 GB; letting iCloud back them up both wastes
/// iCloud quota AND breaks the mental model ("these files can be
/// re-downloaded on demand, they're not user data"). Apple's file-system
/// guidelines explicitly require this attribute for caches and
/// re-downloadable data.
///
/// Behaviour:
/// - On iOS: invokes the platform-channel method; native side sets the
///   attribute via `URL.setResourceValues(URLResourceValues(isExcludedFromBackup: true))`.
/// - On Android: silently no-op — Android has no iCloud equivalent; the
///   caller logic can be platform-agnostic.
class IosBackupExcluder {
  IosBackupExcluder({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(kIosBackupExcluderChannelName);

  static final Logger _log = Logger('infrastructure.platform.ios_backup_excluder');

  final MethodChannel _channel;

  /// Marks the file at [absolutePath] as excluded from iCloud backup.
  /// No-op on non-iOS platforms.
  ///
  /// Swallows platform exceptions best-effort: backup-exclusion failure
  /// should never block a download commit (the file is still usable,
  /// just also backed up — a minor issue, not a correctness break).
  Future<void> excludePath(String absolutePath) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('excludeFromBackup', <String, Object>{'path': absolutePath});
    } on MissingPluginException catch (e, st) {
      _log.fine('excludePath: no iOS handler registered — not installed or simulator. path=$absolutePath. $e', e, st);
    } on PlatformException catch (e, st) {
      _log.warning('excludePath platform error (swallowed): ${e.code} ${e.message}', e, st);
    } on Object catch (e, st) {
      _log.warning('excludePath unexpected error (swallowed): $e', e, st);
    }
  }
}

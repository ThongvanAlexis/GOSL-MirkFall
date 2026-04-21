// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:logging/logging.dart';

/// Atomic same-volume file rename with a cross-volume copy fallback.
///
/// [commit] is the load-bearing step #5 of the download atomic protocol
/// (see `README.md`): once it returns without throwing, the country's
/// PMTiles bundle is visible at its canonical path. A crash between
/// [commit] and the subsequent manifest write leaves the file on disk
/// but missing from `installed.json` — Plan 07-04's bootstrap heals
/// that case by recomputing the sha256 and inserting a manifest entry
/// if the hash matches the catalog.
///
/// Same-volume rename uses [File.rename] which is atomic on every
/// filesystem MirkFall ships to (ext4, APFS, NTFS). Cross-volume
/// renames throw [FileSystemException] with errno 18 (EXDEV) on POSIX;
/// the fallback copies + deletes with a warning log, which is NOT
/// atomic — but this branch is reserved for the rare case where
/// `<app_support>` spans two volumes, not for normal operation.
class AtomicRenamer {
  AtomicRenamer({Logger? logger}) : _log = logger ?? Logger('infrastructure.downloads.atomic_renamer');

  final Logger _log;

  /// Renames [source] onto [target]. Creates [target]'s parent
  /// directory if it is missing.
  ///
  /// Throws [FileSystemException] when [source] does not exist or
  /// cannot be read. Propagates any other filesystem error after a
  /// best-effort copy+delete fallback for cross-volume moves.
  Future<void> commit({required File source, required File target}) async {
    if (!source.existsSync()) {
      throw FileSystemException('AtomicRenamer.commit: source missing', source.path);
    }
    await target.parent.create(recursive: true);

    try {
      await source.rename(target.path);
      return;
    } on FileSystemException catch (e) {
      // POSIX errno 18 = EXDEV (cross-device link). On Windows, rename
      // across volumes surfaces a different error but the recovery is
      // the same: copy to target + delete source.
      if (!_isCrossDeviceError(e)) {
        rethrow;
      }
      _log.warning('commit: cross-volume rename fallback (source=${source.path}, target=${target.path}): $e');
    }

    // Cross-volume fallback: copy then delete. Not atomic — logged so a
    // future refactor can revisit if this branch ever fires in the wild.
    try {
      await source.copy(target.path);
      await source.delete();
    } on FileSystemException catch (e) {
      _log.severe('commit: cross-volume copy+delete failed: $e');
      rethrow;
    }
  }

  /// Returns true when [e] looks like a cross-device-link error. The
  /// Dart I/O layer surfaces the OS errno via `osError.errorCode`; both
  /// POSIX (`EXDEV == 18`) and Windows (`ERROR_NOT_SAME_DEVICE == 17`)
  /// land here. Unknown error codes default to `false` so unrelated
  /// failures (permission denied, missing target parent, etc.) still
  /// propagate rather than triggering a silent copy+delete fallback.
  bool _isCrossDeviceError(FileSystemException e) {
    final OSError? os = e.osError;
    if (os == null) return false;
    return os.errorCode == 18 || os.errorCode == 17;
  }
}

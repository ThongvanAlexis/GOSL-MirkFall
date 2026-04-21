// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import Flutter
import Foundation

/// iOS side of the `app.gosl.mirkfall/ios_backup_excluder` MethodChannel.
///
/// Dart side: `lib/infrastructure/platform/ios_backup_excluder.dart`
/// (constant `kIosBackupExcluderChannelName`).
///
/// Exposes one method: `excludeFromBackup({path: String})` — sets
/// `NSURLIsExcludedFromBackupKey=true` on the URL representing [path]
/// so iCloud skips the file during backup. Closes RESEARCH
/// Open Question #3: per-country PMTiles bundles (hundreds of MB to
/// 1.5 GB) must NOT be backed up — they are re-downloadable on demand.
class IosBackupExcluderChannel {
    /// MethodChannel name — mirrored in
    /// `lib/infrastructure/platform/ios_backup_excluder.dart`
    /// (`kIosBackupExcluderChannelName`).
    static let channelName = "app.gosl.mirkfall/ios_backup_excluder"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "excludeFromBackup":
                handleExcludeFromBackup(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func handleExcludeFromBackup(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String, !path.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "path argument is required", details: nil))
            return
        }
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try url.setResourceValues(values)
            result(nil)
        } catch let nsError as NSError {
            result(FlutterError(code: "IO_ERROR", message: nsError.localizedDescription, details: nil))
        }
    }
}

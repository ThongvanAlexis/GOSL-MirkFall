// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import Flutter
import Foundation

/// iOS side of the Phase 07 disk-space MethodChannel.
///
/// Dart side: `lib/infrastructure/platform/disk_space_checker.dart`
/// (constant `kDiskSpaceChannelName`).
///
/// Exposes one method: `freeBytes({path: String}) -> Int` — returns the
/// `systemFreeSize` attribute reported by `FileManager.attributesOfFileSystem(forPath:)`.
/// `NSNumber` → Int coercion handles the platform-channel boxing.
class DiskSpaceChannel {
    /// MethodChannel name — mirrored in
    /// `lib/infrastructure/platform/disk_space_checker.dart` + the
    /// Android Kotlin side (`DiskSpaceChannel.CHANNEL`).
    static let channelName = "app.gosl.mirkfall/disk_space"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "freeBytes":
                handleFreeBytes(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func handleFreeBytes(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String, !path.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "path argument is required", details: nil))
            return
        }
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
            guard let freeSize = attrs[.systemFreeSize] as? NSNumber else {
                result(FlutterError(code: "IO_ERROR", message: "systemFreeSize attribute missing", details: nil))
                return
            }
            // Return as Int — MethodChannel round-trips numbers through
            // NSNumber → Dart num safely.
            result(freeSize.int64Value)
        } catch let nsError as NSError {
            result(FlutterError(code: "IO_ERROR", message: nsError.localizedDescription, details: nil))
        }
    }
}

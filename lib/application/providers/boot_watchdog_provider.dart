// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/infrastructure/platform/ios_significant_change_watchdog.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'boot_watchdog_provider.g.dart';

/// Process-singleton [IosSignificantChangeWatchdog] wired over the
/// `app.gosl.mirkfall/boot_watchdog` MethodChannel.
///
/// `keepAlive: true` — the underlying channel handler on the iOS side is a
/// per-process resource; re-creating the Dart wrapper on every consumer
/// subscription would not reduce native work but would churn the Riverpod
/// graph.
@Riverpod(keepAlive: true)
IosSignificantChangeWatchdog iosSignificantChangeWatchdog(Ref ref) => const IosSignificantChangeWatchdog();

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Thrown when a [`MirkStyleConfig`] payload fails its boundary validation
/// (missing required field, malformed nested shape, etc.).
///
/// Note: an unknown `rendererType` does NOT throw — `MirkStyleConfig.fromJson`
/// returns `UnknownConfig(raw: payload)` instead, preserving forward
/// compatibility (D6 + D9).
class MirkStyleConfigException implements Exception {
  const MirkStyleConfigException({required this.reason});

  final String reason;

  @override
  String toString() => 'MirkStyleConfigException(reason=$reason)';
}

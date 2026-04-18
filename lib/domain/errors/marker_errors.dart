// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/marker_id.dart';

/// Thrown when a marker lookup-by-ID returns no row.
class MarkerNotFoundException implements Exception {
  const MarkerNotFoundException({required this.id});

  final MarkerId id;

  @override
  String toString() => 'MarkerNotFoundException(id=${id.value})';
}

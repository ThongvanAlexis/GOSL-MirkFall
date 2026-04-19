// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/gps/location_stream.dart';
import 'package:mirkfall/infrastructure/gps/geolocator_location_stream.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'id_generator_provider.dart';

part 'location_stream_provider.g.dart';

/// Production [LocationStream] — wraps [`GeolocatorLocationStream`] around
/// the app's [`IdGenerator`] (the stream mints fresh `FixId`s on every
/// accepted `Position`).
///
/// `keepAlive: true` — the underlying geolocator foreground-service
/// subscription is expensive to (re-)start; the controller (Plan 05-03)
/// owns the actual `.positions(...)` subscription lifecycle. This provider
/// only holds the stateless factory.
@Riverpod(keepAlive: true)
LocationStream locationStream(Ref ref) {
  final idGenerator = ref.watch(idGeneratorProvider);
  return GeolocatorLocationStream(idGenerator: idGenerator);
}

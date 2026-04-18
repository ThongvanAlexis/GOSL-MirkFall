// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math';

import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/infrastructure/ids/ulid.dart';

/// Production [IdGenerator] backed by `Random.secure()` and a wall-clock
/// UTC timestamp.
///
/// `Random.secure()` is the only safe choice for IDs that ever cross a
/// trust boundary (e.g. exported to JSON the user can hand off to a
/// peer); the deterministic [SeededIdGenerator] is for tests only.
class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator([Random? rng]) : _rng = rng ?? Random.secure();

  final Random _rng;

  @override
  String newId(String prefix) =>
      '$prefix${Ulid.generate(now: DateTime.now().toUtc(), rng: _rng)}';
}

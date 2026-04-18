// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math';

import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/infrastructure/ids/ulid.dart';

/// Deterministic [IdGenerator] for tests.
///
/// Two instances built with the same [seed] (and same [fixedNow], if
/// provided) emit identical sequences — letting tests assert on exact
/// ID values instead of fuzzy `expect(matches(regex))` patterns.
///
/// [fixedNow] is optional: when null, the generator falls back to wall-clock
/// UTC so the same instance is still useful in end-to-end test harnesses
/// where only prefix safety + uniqueness matter (timestamp drift in those
/// harnesses is irrelevant).
class SeededIdGenerator implements IdGenerator {
  SeededIdGenerator({required int seed, DateTime? fixedNow})
    : _rng = Random(seed),
      _fixedNow = fixedNow;

  final Random _rng;
  final DateTime? _fixedNow;

  @override
  String newId(String prefix) {
    final now = _fixedNow ?? DateTime.now().toUtc();
    return '$prefix${Ulid.generate(now: now, rng: _rng)}';
  }
}

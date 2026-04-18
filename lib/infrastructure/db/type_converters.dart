// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';

/// Converter INT ms <-> UTC [DateTime]. Milliseconds since Unix epoch,
/// always UTC (CONTEXT.md §Time storage convention). Paired with a separate
/// `*_offset_minutes` column when wall-clock reconstruction is needed.
class UnixMsToDateTimeConverter extends TypeConverter<DateTime, int> {
  const UnixMsToDateTimeConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

/// Converter TEXT <-> [SessionStatus]. Wire values mirror the `@JsonValue`
/// strings on the enum so DB rows stay greppable in SQL inspectors.
class SessionStatusStringConverter extends TypeConverter<SessionStatus, String> {
  const SessionStatusStringConverter();

  @override
  SessionStatus fromSql(String fromDb) => switch (fromDb) {
        'active' => SessionStatus.active,
        'stopped' => SessionStatus.stopped,
        _ => throw ArgumentError.value(
            fromDb,
            'status',
            'unknown SessionStatus value — expected active|stopped',
          ),
      };

  @override
  String toSql(SessionStatus value) => switch (value) {
        SessionStatus.active => 'active',
        SessionStatus.stopped => 'stopped',
      };
}

/// Converter TEXT (JSON) <-> [MirkStyleConfig]. The column stores the
/// serialized `MirkStyleConfig.toJson()` as a TEXT payload; decoding routes
/// through the sealed-union `fromJson` that falls back to [UnknownConfig]
/// on unrecognized `rendererType` values (forward-compat, decision D9).
class MirkStyleConfigJsonConverter extends TypeConverter<MirkStyleConfig, String> {
  const MirkStyleConfigJsonConverter();

  @override
  MirkStyleConfig fromSql(String fromDb) {
    final Object? decoded = jsonDecode(fromDb);
    if (decoded is! Map) {
      throw FormatException(
        'MirkStyleConfig column payload is not a JSON object',
        fromDb,
      );
    }
    return MirkStyleConfig.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  String toSql(MirkStyleConfig value) => jsonEncode(value.toJson());
}

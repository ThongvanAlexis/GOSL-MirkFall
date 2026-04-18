// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta = const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    check: () => status.isIn(const <String>['active', 'stopped']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> startedAtUtc = GeneratedColumn<int>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($SessionsTable.$converterstartedAtUtc);
  static const VerificationMeta _startedAtOffsetMinutesMeta = const VerificationMeta('startedAtOffsetMinutes');
  @override
  late final GeneratedColumn<int> startedAtOffsetMinutes = GeneratedColumn<int>(
    'started_at_offset_minutes',
    aliasedName,
    false,
    check: () => ComparableExpr(startedAtOffsetMinutes).isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> stoppedAtUtc = GeneratedColumn<int>(
    'stopped_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($SessionsTable.$converterstoppedAtUtcn);
  static const VerificationMeta _stoppedAtOffsetMinutesMeta = const VerificationMeta('stoppedAtOffsetMinutes');
  @override
  late final GeneratedColumn<int> stoppedAtOffsetMinutes = GeneratedColumn<int>(
    'stopped_at_offset_minutes',
    aliasedName,
    true,
    check: () => ComparableExpr(stoppedAtOffsetMinutes).isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>('notes', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, displayName, status, startedAtUtc, startedAtOffsetMinutes, stoppedAtUtc, stoppedAtOffsetMinutes, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 't_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<SessionRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(_displayNameMeta, displayName.isAcceptableOrUnknown(data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at_offset_minutes')) {
      context.handle(
        _startedAtOffsetMinutesMeta,
        startedAtOffsetMinutes.isAcceptableOrUnknown(data['started_at_offset_minutes']!, _startedAtOffsetMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtOffsetMinutesMeta);
    }
    if (data.containsKey('stopped_at_offset_minutes')) {
      context.handle(
        _stoppedAtOffsetMinutesMeta,
        stoppedAtOffsetMinutes.isAcceptableOrUnknown(data['stopped_at_offset_minutes']!, _stoppedAtOffsetMinutesMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      startedAtUtc: $SessionsTable.$converterstartedAtUtc.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}started_at_utc'])!,
      ),
      startedAtOffsetMinutes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}started_at_offset_minutes'])!,
      stoppedAtUtc: $SessionsTable.$converterstoppedAtUtcn.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}stopped_at_utc']),
      ),
      stoppedAtOffsetMinutes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}stopped_at_offset_minutes']),
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterstartedAtUtc = const UnixMsToDateTimeConverter();
  static TypeConverter<DateTime, int> $converterstoppedAtUtc = const UnixMsToDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterstoppedAtUtcn = NullAwareTypeConverter.wrap($converterstoppedAtUtc);
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String displayName;
  final String status;
  final DateTime startedAtUtc;
  final int startedAtOffsetMinutes;
  final DateTime? stoppedAtUtc;
  final int? stoppedAtOffsetMinutes;
  final String? notes;
  const SessionRow({
    required this.id,
    required this.displayName,
    required this.status,
    required this.startedAtUtc,
    required this.startedAtOffsetMinutes,
    this.stoppedAtUtc,
    this.stoppedAtOffsetMinutes,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['status'] = Variable<String>(status);
    {
      map['started_at_utc'] = Variable<int>($SessionsTable.$converterstartedAtUtc.toSql(startedAtUtc));
    }
    map['started_at_offset_minutes'] = Variable<int>(startedAtOffsetMinutes);
    if (!nullToAbsent || stoppedAtUtc != null) {
      map['stopped_at_utc'] = Variable<int>($SessionsTable.$converterstoppedAtUtcn.toSql(stoppedAtUtc));
    }
    if (!nullToAbsent || stoppedAtOffsetMinutes != null) {
      map['stopped_at_offset_minutes'] = Variable<int>(stoppedAtOffsetMinutes);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      displayName: Value(displayName),
      status: Value(status),
      startedAtUtc: Value(startedAtUtc),
      startedAtOffsetMinutes: Value(startedAtOffsetMinutes),
      stoppedAtUtc: stoppedAtUtc == null && nullToAbsent ? const Value.absent() : Value(stoppedAtUtc),
      stoppedAtOffsetMinutes: stoppedAtOffsetMinutes == null && nullToAbsent ? const Value.absent() : Value(stoppedAtOffsetMinutes),
      notes: notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory SessionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      status: serializer.fromJson<String>(json['status']),
      startedAtUtc: serializer.fromJson<DateTime>(json['startedAtUtc']),
      startedAtOffsetMinutes: serializer.fromJson<int>(json['startedAtOffsetMinutes']),
      stoppedAtUtc: serializer.fromJson<DateTime?>(json['stoppedAtUtc']),
      stoppedAtOffsetMinutes: serializer.fromJson<int?>(json['stoppedAtOffsetMinutes']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'status': serializer.toJson<String>(status),
      'startedAtUtc': serializer.toJson<DateTime>(startedAtUtc),
      'startedAtOffsetMinutes': serializer.toJson<int>(startedAtOffsetMinutes),
      'stoppedAtUtc': serializer.toJson<DateTime?>(stoppedAtUtc),
      'stoppedAtOffsetMinutes': serializer.toJson<int?>(stoppedAtOffsetMinutes),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  SessionRow copyWith({
    String? id,
    String? displayName,
    String? status,
    DateTime? startedAtUtc,
    int? startedAtOffsetMinutes,
    Value<DateTime?> stoppedAtUtc = const Value.absent(),
    Value<int?> stoppedAtOffsetMinutes = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    status: status ?? this.status,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    startedAtOffsetMinutes: startedAtOffsetMinutes ?? this.startedAtOffsetMinutes,
    stoppedAtUtc: stoppedAtUtc.present ? stoppedAtUtc.value : this.stoppedAtUtc,
    stoppedAtOffsetMinutes: stoppedAtOffsetMinutes.present ? stoppedAtOffsetMinutes.value : this.stoppedAtOffsetMinutes,
    notes: notes.present ? notes.value : this.notes,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present ? data.displayName.value : this.displayName,
      status: data.status.present ? data.status.value : this.status,
      startedAtUtc: data.startedAtUtc.present ? data.startedAtUtc.value : this.startedAtUtc,
      startedAtOffsetMinutes: data.startedAtOffsetMinutes.present ? data.startedAtOffsetMinutes.value : this.startedAtOffsetMinutes,
      stoppedAtUtc: data.stoppedAtUtc.present ? data.stoppedAtUtc.value : this.stoppedAtUtc,
      stoppedAtOffsetMinutes: data.stoppedAtOffsetMinutes.present ? data.stoppedAtOffsetMinutes.value : this.stoppedAtOffsetMinutes,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('startedAtOffsetMinutes: $startedAtOffsetMinutes, ')
          ..write('stoppedAtUtc: $stoppedAtUtc, ')
          ..write('stoppedAtOffsetMinutes: $stoppedAtOffsetMinutes, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, status, startedAtUtc, startedAtOffsetMinutes, stoppedAtUtc, stoppedAtOffsetMinutes, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.status == this.status &&
          other.startedAtUtc == this.startedAtUtc &&
          other.startedAtOffsetMinutes == this.startedAtOffsetMinutes &&
          other.stoppedAtUtc == this.stoppedAtUtc &&
          other.stoppedAtOffsetMinutes == this.stoppedAtOffsetMinutes &&
          other.notes == this.notes);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> status;
  final Value<DateTime> startedAtUtc;
  final Value<int> startedAtOffsetMinutes;
  final Value<DateTime?> stoppedAtUtc;
  final Value<int?> stoppedAtOffsetMinutes;
  final Value<String?> notes;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.startedAtOffsetMinutes = const Value.absent(),
    this.stoppedAtUtc = const Value.absent(),
    this.stoppedAtOffsetMinutes = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String displayName,
    required String status,
    required DateTime startedAtUtc,
    required int startedAtOffsetMinutes,
    this.stoppedAtUtc = const Value.absent(),
    this.stoppedAtOffsetMinutes = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       status = Value(status),
       startedAtUtc = Value(startedAtUtc),
       startedAtOffsetMinutes = Value(startedAtOffsetMinutes);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? status,
    Expression<int>? startedAtUtc,
    Expression<int>? startedAtOffsetMinutes,
    Expression<int>? stoppedAtUtc,
    Expression<int>? stoppedAtOffsetMinutes,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (status != null) 'status': status,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (startedAtOffsetMinutes != null) 'started_at_offset_minutes': startedAtOffsetMinutes,
      if (stoppedAtUtc != null) 'stopped_at_utc': stoppedAtUtc,
      if (stoppedAtOffsetMinutes != null) 'stopped_at_offset_minutes': stoppedAtOffsetMinutes,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? status,
    Value<DateTime>? startedAtUtc,
    Value<int>? startedAtOffsetMinutes,
    Value<DateTime?>? stoppedAtUtc,
    Value<int?>? stoppedAtOffsetMinutes,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      startedAtOffsetMinutes: startedAtOffsetMinutes ?? this.startedAtOffsetMinutes,
      stoppedAtUtc: stoppedAtUtc ?? this.stoppedAtUtc,
      stoppedAtOffsetMinutes: stoppedAtOffsetMinutes ?? this.stoppedAtOffsetMinutes,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<int>($SessionsTable.$converterstartedAtUtc.toSql(startedAtUtc.value));
    }
    if (startedAtOffsetMinutes.present) {
      map['started_at_offset_minutes'] = Variable<int>(startedAtOffsetMinutes.value);
    }
    if (stoppedAtUtc.present) {
      map['stopped_at_utc'] = Variable<int>($SessionsTable.$converterstoppedAtUtcn.toSql(stoppedAtUtc.value));
    }
    if (stoppedAtOffsetMinutes.present) {
      map['stopped_at_offset_minutes'] = Variable<int>(stoppedAtOffsetMinutes.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('startedAtOffsetMinutes: $startedAtOffsetMinutes, ')
          ..write('stoppedAtUtc: $stoppedAtUtc, ')
          ..write('stoppedAtOffsetMinutes: $stoppedAtOffsetMinutes, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarkerCategoriesTable extends MarkerCategories with TableInfo<$MarkerCategoriesTable, MarkerCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarkerCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta = const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>('icon_name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($MarkerCategoriesTable.$convertercreatedAtUtc);
  static const VerificationMeta _createdAtOffsetMinutesMeta = const VerificationMeta('createdAtOffsetMinutes');
  @override
  late final GeneratedColumn<int> createdAtOffsetMinutes = GeneratedColumn<int>(
    'created_at_offset_minutes',
    aliasedName,
    false,
    check: () => ComparableExpr(createdAtOffsetMinutes).isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, displayName, iconName, createdAtUtc, createdAtOffsetMinutes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 't_marker_categories';
  @override
  VerificationContext validateIntegrity(Insertable<MarkerCategoryRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(_displayNameMeta, displayName.isAcceptableOrUnknown(data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta, iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('created_at_offset_minutes')) {
      context.handle(
        _createdAtOffsetMinutesMeta,
        createdAtOffsetMinutes.isAcceptableOrUnknown(data['created_at_offset_minutes']!, _createdAtOffsetMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtOffsetMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MarkerCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarkerCategoryRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      iconName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}icon_name'])!,
      createdAtUtc: $MarkerCategoriesTable.$convertercreatedAtUtc.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_utc'])!,
      ),
      createdAtOffsetMinutes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_offset_minutes'])!,
    );
  }

  @override
  $MarkerCategoriesTable createAlias(String alias) {
    return $MarkerCategoriesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAtUtc = const UnixMsToDateTimeConverter();
}

class MarkerCategoryRow extends DataClass implements Insertable<MarkerCategoryRow> {
  final String id;
  final String displayName;
  final String iconName;
  final DateTime createdAtUtc;
  final int createdAtOffsetMinutes;
  const MarkerCategoryRow({
    required this.id,
    required this.displayName,
    required this.iconName,
    required this.createdAtUtc,
    required this.createdAtOffsetMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['icon_name'] = Variable<String>(iconName);
    {
      map['created_at_utc'] = Variable<int>($MarkerCategoriesTable.$convertercreatedAtUtc.toSql(createdAtUtc));
    }
    map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes);
    return map;
  }

  MarkerCategoriesCompanion toCompanion(bool nullToAbsent) {
    return MarkerCategoriesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      iconName: Value(iconName),
      createdAtUtc: Value(createdAtUtc),
      createdAtOffsetMinutes: Value(createdAtOffsetMinutes),
    );
  }

  factory MarkerCategoryRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarkerCategoryRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      iconName: serializer.fromJson<String>(json['iconName']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      createdAtOffsetMinutes: serializer.fromJson<int>(json['createdAtOffsetMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'iconName': serializer.toJson<String>(iconName),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'createdAtOffsetMinutes': serializer.toJson<int>(createdAtOffsetMinutes),
    };
  }

  MarkerCategoryRow copyWith({String? id, String? displayName, String? iconName, DateTime? createdAtUtc, int? createdAtOffsetMinutes}) => MarkerCategoryRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    iconName: iconName ?? this.iconName,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
  );
  MarkerCategoryRow copyWithCompanion(MarkerCategoriesCompanion data) {
    return MarkerCategoryRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present ? data.displayName.value : this.displayName,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      createdAtUtc: data.createdAtUtc.present ? data.createdAtUtc.value : this.createdAtUtc,
      createdAtOffsetMinutes: data.createdAtOffsetMinutes.present ? data.createdAtOffsetMinutes.value : this.createdAtOffsetMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarkerCategoryRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('iconName: $iconName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, iconName, createdAtUtc, createdAtOffsetMinutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarkerCategoryRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.iconName == this.iconName &&
          other.createdAtUtc == this.createdAtUtc &&
          other.createdAtOffsetMinutes == this.createdAtOffsetMinutes);
}

class MarkerCategoriesCompanion extends UpdateCompanion<MarkerCategoryRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> iconName;
  final Value<DateTime> createdAtUtc;
  final Value<int> createdAtOffsetMinutes;
  final Value<int> rowid;
  const MarkerCategoriesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.iconName = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.createdAtOffsetMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarkerCategoriesCompanion.insert({
    required String id,
    required String displayName,
    required String iconName,
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       iconName = Value(iconName),
       createdAtUtc = Value(createdAtUtc),
       createdAtOffsetMinutes = Value(createdAtOffsetMinutes);
  static Insertable<MarkerCategoryRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? iconName,
    Expression<int>? createdAtUtc,
    Expression<int>? createdAtOffsetMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (iconName != null) 'icon_name': iconName,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (createdAtOffsetMinutes != null) 'created_at_offset_minutes': createdAtOffsetMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarkerCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? iconName,
    Value<DateTime>? createdAtUtc,
    Value<int>? createdAtOffsetMinutes,
    Value<int>? rowid,
  }) {
    return MarkerCategoriesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      iconName: iconName ?? this.iconName,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>($MarkerCategoriesTable.$convertercreatedAtUtc.toSql(createdAtUtc.value));
    }
    if (createdAtOffsetMinutes.present) {
      map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarkerCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('iconName: $iconName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarkersTable extends Markers with TableInfo<$MarkersTable, MarkerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES t_sessions (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES t_marker_categories (id)'),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>('lat', aliasedName, false, type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>('lon', aliasedName, false, type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>('title', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>('notes', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($MarkersTable.$convertercreatedAtUtc);
  static const VerificationMeta _createdAtOffsetMinutesMeta = const VerificationMeta('createdAtOffsetMinutes');
  @override
  late final GeneratedColumn<int> createdAtOffsetMinutes = GeneratedColumn<int>(
    'created_at_offset_minutes',
    aliasedName,
    false,
    check: () => ComparableExpr(createdAtOffsetMinutes).isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, categoryId, lat, lon, title, notes, createdAtUtc, createdAtOffsetMinutes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 't_markers';
  @override
  VerificationContext validateIntegrity(Insertable<MarkerRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta, sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(_categoryIdMeta, categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(_latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lon')) {
      context.handle(_lonMeta, lon.isAcceptableOrUnknown(data['lon']!, _lonMeta));
    } else if (isInserting) {
      context.missing(_lonMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at_offset_minutes')) {
      context.handle(
        _createdAtOffsetMinutesMeta,
        createdAtOffsetMinutes.isAcceptableOrUnknown(data['created_at_offset_minutes']!, _createdAtOffsetMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtOffsetMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MarkerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarkerRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      categoryId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      lat: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}lat'])!,
      lon: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}lon'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAtUtc: $MarkersTable.$convertercreatedAtUtc.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_utc'])!,
      ),
      createdAtOffsetMinutes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_offset_minutes'])!,
    );
  }

  @override
  $MarkersTable createAlias(String alias) {
    return $MarkersTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAtUtc = const UnixMsToDateTimeConverter();
}

class MarkerRow extends DataClass implements Insertable<MarkerRow> {
  final String id;
  final String sessionId;
  final String categoryId;
  final double lat;
  final double lon;
  final String title;
  final String? notes;
  final DateTime createdAtUtc;
  final int createdAtOffsetMinutes;
  const MarkerRow({
    required this.id,
    required this.sessionId,
    required this.categoryId,
    required this.lat,
    required this.lon,
    required this.title,
    this.notes,
    required this.createdAtUtc,
    required this.createdAtOffsetMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['category_id'] = Variable<String>(categoryId);
    map['lat'] = Variable<double>(lat);
    map['lon'] = Variable<double>(lon);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    {
      map['created_at_utc'] = Variable<int>($MarkersTable.$convertercreatedAtUtc.toSql(createdAtUtc));
    }
    map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes);
    return map;
  }

  MarkersCompanion toCompanion(bool nullToAbsent) {
    return MarkersCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      categoryId: Value(categoryId),
      lat: Value(lat),
      lon: Value(lon),
      title: Value(title),
      notes: notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAtUtc: Value(createdAtUtc),
      createdAtOffsetMinutes: Value(createdAtOffsetMinutes),
    );
  }

  factory MarkerRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarkerRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      lat: serializer.fromJson<double>(json['lat']),
      lon: serializer.fromJson<double>(json['lon']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      createdAtOffsetMinutes: serializer.fromJson<int>(json['createdAtOffsetMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'categoryId': serializer.toJson<String>(categoryId),
      'lat': serializer.toJson<double>(lat),
      'lon': serializer.toJson<double>(lon),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'createdAtOffsetMinutes': serializer.toJson<int>(createdAtOffsetMinutes),
    };
  }

  MarkerRow copyWith({
    String? id,
    String? sessionId,
    String? categoryId,
    double? lat,
    double? lon,
    String? title,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAtUtc,
    int? createdAtOffsetMinutes,
  }) => MarkerRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    categoryId: categoryId ?? this.categoryId,
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
  );
  MarkerRow copyWithCompanion(MarkersCompanion data) {
    return MarkerRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      categoryId: data.categoryId.present ? data.categoryId.value : this.categoryId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAtUtc: data.createdAtUtc.present ? data.createdAtUtc.value : this.createdAtUtc,
      createdAtOffsetMinutes: data.createdAtOffsetMinutes.present ? data.createdAtOffsetMinutes.value : this.createdAtOffsetMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarkerRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('categoryId: $categoryId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, categoryId, lat, lon, title, notes, createdAtUtc, createdAtOffsetMinutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarkerRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.categoryId == this.categoryId &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.createdAtUtc == this.createdAtUtc &&
          other.createdAtOffsetMinutes == this.createdAtOffsetMinutes);
}

class MarkersCompanion extends UpdateCompanion<MarkerRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> categoryId;
  final Value<double> lat;
  final Value<double> lon;
  final Value<String> title;
  final Value<String?> notes;
  final Value<DateTime> createdAtUtc;
  final Value<int> createdAtOffsetMinutes;
  final Value<int> rowid;
  const MarkersCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.createdAtOffsetMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarkersCompanion.insert({
    required String id,
    required String sessionId,
    required String categoryId,
    required double lat,
    required double lon,
    required String title,
    this.notes = const Value.absent(),
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       categoryId = Value(categoryId),
       lat = Value(lat),
       lon = Value(lon),
       title = Value(title),
       createdAtUtc = Value(createdAtUtc),
       createdAtOffsetMinutes = Value(createdAtOffsetMinutes);
  static Insertable<MarkerRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? categoryId,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? createdAtUtc,
    Expression<int>? createdAtOffsetMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (categoryId != null) 'category_id': categoryId,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (createdAtOffsetMinutes != null) 'created_at_offset_minutes': createdAtOffsetMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarkersCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? categoryId,
    Value<double>? lat,
    Value<double>? lon,
    Value<String>? title,
    Value<String?>? notes,
    Value<DateTime>? createdAtUtc,
    Value<int>? createdAtOffsetMinutes,
    Value<int>? rowid,
  }) {
    return MarkersCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      categoryId: categoryId ?? this.categoryId,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>($MarkersTable.$convertercreatedAtUtc.toSql(createdAtUtc.value));
    }
    if (createdAtOffsetMinutes.present) {
      map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarkersCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('categoryId: $categoryId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RevealedTilesTable extends RevealedTiles with TableInfo<$RevealedTilesTable, RevealedTileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevealedTilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES t_sessions (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _parentXMeta = const VerificationMeta('parentX');
  @override
  late final GeneratedColumn<int> parentX = GeneratedColumn<int>('parent_x', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _parentYMeta = const VerificationMeta('parentY');
  @override
  late final GeneratedColumn<int> parentY = GeneratedColumn<int>('parent_y', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _parentZoomMeta = const VerificationMeta('parentZoom');
  @override
  late final GeneratedColumn<int> parentZoom = GeneratedColumn<int>(
    'parent_zoom',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kRevealedTileParentZoom),
  );
  static const VerificationMeta _bitmapMeta = const VerificationMeta('bitmap');
  @override
  late final GeneratedColumn<Uint8List> bitmap = GeneratedColumn<Uint8List>(
    'bitmap',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('length(bitmap) = 512'),
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setBitCountMeta = const VerificationMeta('setBitCount');
  @override
  late final GeneratedColumn<int> setBitCount = GeneratedColumn<int>(
    'set_bit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($RevealedTilesTable.$converterupdatedAtUtc);
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, parentX, parentY, parentZoom, bitmap, setBitCount, updatedAtUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 't_revealed_tiles';
  @override
  VerificationContext validateIntegrity(Insertable<RevealedTileRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta, sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('parent_x')) {
      context.handle(_parentXMeta, parentX.isAcceptableOrUnknown(data['parent_x']!, _parentXMeta));
    } else if (isInserting) {
      context.missing(_parentXMeta);
    }
    if (data.containsKey('parent_y')) {
      context.handle(_parentYMeta, parentY.isAcceptableOrUnknown(data['parent_y']!, _parentYMeta));
    } else if (isInserting) {
      context.missing(_parentYMeta);
    }
    if (data.containsKey('parent_zoom')) {
      context.handle(_parentZoomMeta, parentZoom.isAcceptableOrUnknown(data['parent_zoom']!, _parentZoomMeta));
    }
    if (data.containsKey('bitmap')) {
      context.handle(_bitmapMeta, bitmap.isAcceptableOrUnknown(data['bitmap']!, _bitmapMeta));
    } else if (isInserting) {
      context.missing(_bitmapMeta);
    }
    if (data.containsKey('set_bit_count')) {
      context.handle(_setBitCountMeta, setBitCount.isAcceptableOrUnknown(data['set_bit_count']!, _setBitCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, parentX, parentY, parentZoom},
  ];
  @override
  RevealedTileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RevealedTileRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      parentX: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}parent_x'])!,
      parentY: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}parent_y'])!,
      parentZoom: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}parent_zoom'])!,
      bitmap: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}bitmap'])!,
      setBitCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}set_bit_count'])!,
      updatedAtUtc: $RevealedTilesTable.$converterupdatedAtUtc.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at_utc'])!,
      ),
    );
  }

  @override
  $RevealedTilesTable createAlias(String alias) {
    return $RevealedTilesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAtUtc = const UnixMsToDateTimeConverter();
}

class RevealedTileRow extends DataClass implements Insertable<RevealedTileRow> {
  final String id;
  final String sessionId;
  final int parentX;
  final int parentY;
  final int parentZoom;
  final Uint8List bitmap;
  final int setBitCount;
  final DateTime updatedAtUtc;
  const RevealedTileRow({
    required this.id,
    required this.sessionId,
    required this.parentX,
    required this.parentY,
    required this.parentZoom,
    required this.bitmap,
    required this.setBitCount,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['parent_x'] = Variable<int>(parentX);
    map['parent_y'] = Variable<int>(parentY);
    map['parent_zoom'] = Variable<int>(parentZoom);
    map['bitmap'] = Variable<Uint8List>(bitmap);
    map['set_bit_count'] = Variable<int>(setBitCount);
    {
      map['updated_at_utc'] = Variable<int>($RevealedTilesTable.$converterupdatedAtUtc.toSql(updatedAtUtc));
    }
    return map;
  }

  RevealedTilesCompanion toCompanion(bool nullToAbsent) {
    return RevealedTilesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      parentX: Value(parentX),
      parentY: Value(parentY),
      parentZoom: Value(parentZoom),
      bitmap: Value(bitmap),
      setBitCount: Value(setBitCount),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory RevealedTileRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RevealedTileRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      parentX: serializer.fromJson<int>(json['parentX']),
      parentY: serializer.fromJson<int>(json['parentY']),
      parentZoom: serializer.fromJson<int>(json['parentZoom']),
      bitmap: serializer.fromJson<Uint8List>(json['bitmap']),
      setBitCount: serializer.fromJson<int>(json['setBitCount']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'parentX': serializer.toJson<int>(parentX),
      'parentY': serializer.toJson<int>(parentY),
      'parentZoom': serializer.toJson<int>(parentZoom),
      'bitmap': serializer.toJson<Uint8List>(bitmap),
      'setBitCount': serializer.toJson<int>(setBitCount),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  RevealedTileRow copyWith({
    String? id,
    String? sessionId,
    int? parentX,
    int? parentY,
    int? parentZoom,
    Uint8List? bitmap,
    int? setBitCount,
    DateTime? updatedAtUtc,
  }) => RevealedTileRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    parentX: parentX ?? this.parentX,
    parentY: parentY ?? this.parentY,
    parentZoom: parentZoom ?? this.parentZoom,
    bitmap: bitmap ?? this.bitmap,
    setBitCount: setBitCount ?? this.setBitCount,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  RevealedTileRow copyWithCompanion(RevealedTilesCompanion data) {
    return RevealedTileRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      parentX: data.parentX.present ? data.parentX.value : this.parentX,
      parentY: data.parentY.present ? data.parentY.value : this.parentY,
      parentZoom: data.parentZoom.present ? data.parentZoom.value : this.parentZoom,
      bitmap: data.bitmap.present ? data.bitmap.value : this.bitmap,
      setBitCount: data.setBitCount.present ? data.setBitCount.value : this.setBitCount,
      updatedAtUtc: data.updatedAtUtc.present ? data.updatedAtUtc.value : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RevealedTileRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('parentX: $parentX, ')
          ..write('parentY: $parentY, ')
          ..write('parentZoom: $parentZoom, ')
          ..write('bitmap: $bitmap, ')
          ..write('setBitCount: $setBitCount, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, parentX, parentY, parentZoom, $driftBlobEquality.hash(bitmap), setBitCount, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RevealedTileRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.parentX == this.parentX &&
          other.parentY == this.parentY &&
          other.parentZoom == this.parentZoom &&
          $driftBlobEquality.equals(other.bitmap, this.bitmap) &&
          other.setBitCount == this.setBitCount &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class RevealedTilesCompanion extends UpdateCompanion<RevealedTileRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> parentX;
  final Value<int> parentY;
  final Value<int> parentZoom;
  final Value<Uint8List> bitmap;
  final Value<int> setBitCount;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const RevealedTilesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.parentX = const Value.absent(),
    this.parentY = const Value.absent(),
    this.parentZoom = const Value.absent(),
    this.bitmap = const Value.absent(),
    this.setBitCount = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RevealedTilesCompanion.insert({
    required String id,
    required String sessionId,
    required int parentX,
    required int parentY,
    this.parentZoom = const Value.absent(),
    required Uint8List bitmap,
    this.setBitCount = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       parentX = Value(parentX),
       parentY = Value(parentY),
       bitmap = Value(bitmap),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<RevealedTileRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? parentX,
    Expression<int>? parentY,
    Expression<int>? parentZoom,
    Expression<Uint8List>? bitmap,
    Expression<int>? setBitCount,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (parentX != null) 'parent_x': parentX,
      if (parentY != null) 'parent_y': parentY,
      if (parentZoom != null) 'parent_zoom': parentZoom,
      if (bitmap != null) 'bitmap': bitmap,
      if (setBitCount != null) 'set_bit_count': setBitCount,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RevealedTilesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? parentX,
    Value<int>? parentY,
    Value<int>? parentZoom,
    Value<Uint8List>? bitmap,
    Value<int>? setBitCount,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return RevealedTilesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      parentX: parentX ?? this.parentX,
      parentY: parentY ?? this.parentY,
      parentZoom: parentZoom ?? this.parentZoom,
      bitmap: bitmap ?? this.bitmap,
      setBitCount: setBitCount ?? this.setBitCount,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (parentX.present) {
      map['parent_x'] = Variable<int>(parentX.value);
    }
    if (parentY.present) {
      map['parent_y'] = Variable<int>(parentY.value);
    }
    if (parentZoom.present) {
      map['parent_zoom'] = Variable<int>(parentZoom.value);
    }
    if (bitmap.present) {
      map['bitmap'] = Variable<Uint8List>(bitmap.value);
    }
    if (setBitCount.present) {
      map['set_bit_count'] = Variable<int>(setBitCount.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>($RevealedTilesTable.$converterupdatedAtUtc.toSql(updatedAtUtc.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RevealedTilesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('parentX: $parentX, ')
          ..write('parentY: $parentY, ')
          ..write('parentZoom: $parentZoom, ')
          ..write('bitmap: $bitmap, ')
          ..write('setBitCount: $setBitCount, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MirkStylesTable extends MirkStyles with TableInfo<$MirkStylesTable, MirkStyleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MirkStylesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta = const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rendererTypeMeta = const VerificationMeta('rendererType');
  @override
  late final GeneratedColumn<String> rendererType = GeneratedColumn<String>(
    'renderer_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MirkStyleConfig, String> config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MirkStyleConfig>($MirkStylesTable.$converterconfig);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($MirkStylesTable.$convertercreatedAtUtc);
  static const VerificationMeta _createdAtOffsetMinutesMeta = const VerificationMeta('createdAtOffsetMinutes');
  @override
  late final GeneratedColumn<int> createdAtOffsetMinutes = GeneratedColumn<int>(
    'created_at_offset_minutes',
    aliasedName,
    false,
    check: () => ComparableExpr(createdAtOffsetMinutes).isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, displayName, rendererType, config, createdAtUtc, createdAtOffsetMinutes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 't_mirk_styles';
  @override
  VerificationContext validateIntegrity(Insertable<MirkStyleRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(_displayNameMeta, displayName.isAcceptableOrUnknown(data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('renderer_type')) {
      context.handle(_rendererTypeMeta, rendererType.isAcceptableOrUnknown(data['renderer_type']!, _rendererTypeMeta));
    } else if (isInserting) {
      context.missing(_rendererTypeMeta);
    }
    if (data.containsKey('created_at_offset_minutes')) {
      context.handle(
        _createdAtOffsetMinutesMeta,
        createdAtOffsetMinutes.isAcceptableOrUnknown(data['created_at_offset_minutes']!, _createdAtOffsetMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtOffsetMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MirkStyleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MirkStyleRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      rendererType: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}renderer_type'])!,
      config: $MirkStylesTable.$converterconfig.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}config'])!),
      createdAtUtc: $MirkStylesTable.$convertercreatedAtUtc.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_utc'])!,
      ),
      createdAtOffsetMinutes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_offset_minutes'])!,
    );
  }

  @override
  $MirkStylesTable createAlias(String alias) {
    return $MirkStylesTable(attachedDatabase, alias);
  }

  static TypeConverter<MirkStyleConfig, String> $converterconfig = const MirkStyleConfigJsonConverter();
  static TypeConverter<DateTime, int> $convertercreatedAtUtc = const UnixMsToDateTimeConverter();
}

class MirkStyleRow extends DataClass implements Insertable<MirkStyleRow> {
  final String id;
  final String displayName;
  final String rendererType;
  final MirkStyleConfig config;
  final DateTime createdAtUtc;
  final int createdAtOffsetMinutes;
  const MirkStyleRow({
    required this.id,
    required this.displayName,
    required this.rendererType,
    required this.config,
    required this.createdAtUtc,
    required this.createdAtOffsetMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['renderer_type'] = Variable<String>(rendererType);
    {
      map['config'] = Variable<String>($MirkStylesTable.$converterconfig.toSql(config));
    }
    {
      map['created_at_utc'] = Variable<int>($MirkStylesTable.$convertercreatedAtUtc.toSql(createdAtUtc));
    }
    map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes);
    return map;
  }

  MirkStylesCompanion toCompanion(bool nullToAbsent) {
    return MirkStylesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      rendererType: Value(rendererType),
      config: Value(config),
      createdAtUtc: Value(createdAtUtc),
      createdAtOffsetMinutes: Value(createdAtOffsetMinutes),
    );
  }

  factory MirkStyleRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MirkStyleRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      rendererType: serializer.fromJson<String>(json['rendererType']),
      config: serializer.fromJson<MirkStyleConfig>(json['config']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      createdAtOffsetMinutes: serializer.fromJson<int>(json['createdAtOffsetMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'rendererType': serializer.toJson<String>(rendererType),
      'config': serializer.toJson<MirkStyleConfig>(config),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'createdAtOffsetMinutes': serializer.toJson<int>(createdAtOffsetMinutes),
    };
  }

  MirkStyleRow copyWith({
    String? id,
    String? displayName,
    String? rendererType,
    MirkStyleConfig? config,
    DateTime? createdAtUtc,
    int? createdAtOffsetMinutes,
  }) => MirkStyleRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    rendererType: rendererType ?? this.rendererType,
    config: config ?? this.config,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
  );
  MirkStyleRow copyWithCompanion(MirkStylesCompanion data) {
    return MirkStyleRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present ? data.displayName.value : this.displayName,
      rendererType: data.rendererType.present ? data.rendererType.value : this.rendererType,
      config: data.config.present ? data.config.value : this.config,
      createdAtUtc: data.createdAtUtc.present ? data.createdAtUtc.value : this.createdAtUtc,
      createdAtOffsetMinutes: data.createdAtOffsetMinutes.present ? data.createdAtOffsetMinutes.value : this.createdAtOffsetMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MirkStyleRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('rendererType: $rendererType, ')
          ..write('config: $config, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, rendererType, config, createdAtUtc, createdAtOffsetMinutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MirkStyleRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.rendererType == this.rendererType &&
          other.config == this.config &&
          other.createdAtUtc == this.createdAtUtc &&
          other.createdAtOffsetMinutes == this.createdAtOffsetMinutes);
}

class MirkStylesCompanion extends UpdateCompanion<MirkStyleRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> rendererType;
  final Value<MirkStyleConfig> config;
  final Value<DateTime> createdAtUtc;
  final Value<int> createdAtOffsetMinutes;
  final Value<int> rowid;
  const MirkStylesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rendererType = const Value.absent(),
    this.config = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.createdAtOffsetMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MirkStylesCompanion.insert({
    required String id,
    required String displayName,
    required String rendererType,
    required MirkStyleConfig config,
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       rendererType = Value(rendererType),
       config = Value(config),
       createdAtUtc = Value(createdAtUtc),
       createdAtOffsetMinutes = Value(createdAtOffsetMinutes);
  static Insertable<MirkStyleRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? rendererType,
    Expression<String>? config,
    Expression<int>? createdAtUtc,
    Expression<int>? createdAtOffsetMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (rendererType != null) 'renderer_type': rendererType,
      if (config != null) 'config': config,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (createdAtOffsetMinutes != null) 'created_at_offset_minutes': createdAtOffsetMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MirkStylesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? rendererType,
    Value<MirkStyleConfig>? config,
    Value<DateTime>? createdAtUtc,
    Value<int>? createdAtOffsetMinutes,
    Value<int>? rowid,
  }) {
    return MirkStylesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      rendererType: rendererType ?? this.rendererType,
      config: config ?? this.config,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rendererType.present) {
      map['renderer_type'] = Variable<String>(rendererType.value);
    }
    if (config.present) {
      map['config'] = Variable<String>($MirkStylesTable.$converterconfig.toSql(config.value));
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>($MirkStylesTable.$convertercreatedAtUtc.toSql(createdAtUtc.value));
    }
    if (createdAtOffsetMinutes.present) {
      map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MirkStylesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('rendererType: $rendererType, ')
          ..write('config: $config, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, PhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _markerIdMeta = const VerificationMeta('markerId');
  @override
  late final GeneratedColumn<String> markerId = GeneratedColumn<String>(
    'marker_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES t_markers (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _relativeBasenameMeta = const VerificationMeta('relativeBasename');
  @override
  late final GeneratedColumn<String> relativeBasename = GeneratedColumn<String>(
    'relative_basename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthPxMeta = const VerificationMeta('widthPx');
  @override
  late final GeneratedColumn<int> widthPx = GeneratedColumn<int>('width_px', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _heightPxMeta = const VerificationMeta('heightPx');
  @override
  late final GeneratedColumn<int> heightPx = GeneratedColumn<int>('height_px', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($PhotosTable.$convertercreatedAtUtc);
  static const VerificationMeta _createdAtOffsetMinutesMeta = const VerificationMeta('createdAtOffsetMinutes');
  @override
  late final GeneratedColumn<int> createdAtOffsetMinutes = GeneratedColumn<int>(
    'created_at_offset_minutes',
    aliasedName,
    false,
    check: () => ComparableExpr(createdAtOffsetMinutes).isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, markerId, relativeBasename, widthPx, heightPx, fileSizeBytes, createdAtUtc, createdAtOffsetMinutes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 't_photos';
  @override
  VerificationContext validateIntegrity(Insertable<PhotoRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('marker_id')) {
      context.handle(_markerIdMeta, markerId.isAcceptableOrUnknown(data['marker_id']!, _markerIdMeta));
    } else if (isInserting) {
      context.missing(_markerIdMeta);
    }
    if (data.containsKey('relative_basename')) {
      context.handle(_relativeBasenameMeta, relativeBasename.isAcceptableOrUnknown(data['relative_basename']!, _relativeBasenameMeta));
    } else if (isInserting) {
      context.missing(_relativeBasenameMeta);
    }
    if (data.containsKey('width_px')) {
      context.handle(_widthPxMeta, widthPx.isAcceptableOrUnknown(data['width_px']!, _widthPxMeta));
    } else if (isInserting) {
      context.missing(_widthPxMeta);
    }
    if (data.containsKey('height_px')) {
      context.handle(_heightPxMeta, heightPx.isAcceptableOrUnknown(data['height_px']!, _heightPxMeta));
    } else if (isInserting) {
      context.missing(_heightPxMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(_fileSizeBytesMeta, fileSizeBytes.isAcceptableOrUnknown(data['file_size_bytes']!, _fileSizeBytesMeta));
    } else if (isInserting) {
      context.missing(_fileSizeBytesMeta);
    }
    if (data.containsKey('created_at_offset_minutes')) {
      context.handle(
        _createdAtOffsetMinutesMeta,
        createdAtOffsetMinutes.isAcceptableOrUnknown(data['created_at_offset_minutes']!, _createdAtOffsetMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtOffsetMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      markerId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}marker_id'])!,
      relativeBasename: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}relative_basename'])!,
      widthPx: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}width_px'])!,
      heightPx: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}height_px'])!,
      fileSizeBytes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes'])!,
      createdAtUtc: $PhotosTable.$convertercreatedAtUtc.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_utc'])!),
      createdAtOffsetMinutes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at_offset_minutes'])!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAtUtc = const UnixMsToDateTimeConverter();
}

class PhotoRow extends DataClass implements Insertable<PhotoRow> {
  final String id;
  final String markerId;
  final String relativeBasename;
  final int widthPx;
  final int heightPx;
  final int fileSizeBytes;
  final DateTime createdAtUtc;
  final int createdAtOffsetMinutes;
  const PhotoRow({
    required this.id,
    required this.markerId,
    required this.relativeBasename,
    required this.widthPx,
    required this.heightPx,
    required this.fileSizeBytes,
    required this.createdAtUtc,
    required this.createdAtOffsetMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['marker_id'] = Variable<String>(markerId);
    map['relative_basename'] = Variable<String>(relativeBasename);
    map['width_px'] = Variable<int>(widthPx);
    map['height_px'] = Variable<int>(heightPx);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    {
      map['created_at_utc'] = Variable<int>($PhotosTable.$convertercreatedAtUtc.toSql(createdAtUtc));
    }
    map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      markerId: Value(markerId),
      relativeBasename: Value(relativeBasename),
      widthPx: Value(widthPx),
      heightPx: Value(heightPx),
      fileSizeBytes: Value(fileSizeBytes),
      createdAtUtc: Value(createdAtUtc),
      createdAtOffsetMinutes: Value(createdAtOffsetMinutes),
    );
  }

  factory PhotoRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoRow(
      id: serializer.fromJson<String>(json['id']),
      markerId: serializer.fromJson<String>(json['markerId']),
      relativeBasename: serializer.fromJson<String>(json['relativeBasename']),
      widthPx: serializer.fromJson<int>(json['widthPx']),
      heightPx: serializer.fromJson<int>(json['heightPx']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      createdAtOffsetMinutes: serializer.fromJson<int>(json['createdAtOffsetMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'markerId': serializer.toJson<String>(markerId),
      'relativeBasename': serializer.toJson<String>(relativeBasename),
      'widthPx': serializer.toJson<int>(widthPx),
      'heightPx': serializer.toJson<int>(heightPx),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'createdAtOffsetMinutes': serializer.toJson<int>(createdAtOffsetMinutes),
    };
  }

  PhotoRow copyWith({
    String? id,
    String? markerId,
    String? relativeBasename,
    int? widthPx,
    int? heightPx,
    int? fileSizeBytes,
    DateTime? createdAtUtc,
    int? createdAtOffsetMinutes,
  }) => PhotoRow(
    id: id ?? this.id,
    markerId: markerId ?? this.markerId,
    relativeBasename: relativeBasename ?? this.relativeBasename,
    widthPx: widthPx ?? this.widthPx,
    heightPx: heightPx ?? this.heightPx,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
  );
  PhotoRow copyWithCompanion(PhotosCompanion data) {
    return PhotoRow(
      id: data.id.present ? data.id.value : this.id,
      markerId: data.markerId.present ? data.markerId.value : this.markerId,
      relativeBasename: data.relativeBasename.present ? data.relativeBasename.value : this.relativeBasename,
      widthPx: data.widthPx.present ? data.widthPx.value : this.widthPx,
      heightPx: data.heightPx.present ? data.heightPx.value : this.heightPx,
      fileSizeBytes: data.fileSizeBytes.present ? data.fileSizeBytes.value : this.fileSizeBytes,
      createdAtUtc: data.createdAtUtc.present ? data.createdAtUtc.value : this.createdAtUtc,
      createdAtOffsetMinutes: data.createdAtOffsetMinutes.present ? data.createdAtOffsetMinutes.value : this.createdAtOffsetMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRow(')
          ..write('id: $id, ')
          ..write('markerId: $markerId, ')
          ..write('relativeBasename: $relativeBasename, ')
          ..write('widthPx: $widthPx, ')
          ..write('heightPx: $heightPx, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, markerId, relativeBasename, widthPx, heightPx, fileSizeBytes, createdAtUtc, createdAtOffsetMinutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoRow &&
          other.id == this.id &&
          other.markerId == this.markerId &&
          other.relativeBasename == this.relativeBasename &&
          other.widthPx == this.widthPx &&
          other.heightPx == this.heightPx &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.createdAtUtc == this.createdAtUtc &&
          other.createdAtOffsetMinutes == this.createdAtOffsetMinutes);
}

class PhotosCompanion extends UpdateCompanion<PhotoRow> {
  final Value<String> id;
  final Value<String> markerId;
  final Value<String> relativeBasename;
  final Value<int> widthPx;
  final Value<int> heightPx;
  final Value<int> fileSizeBytes;
  final Value<DateTime> createdAtUtc;
  final Value<int> createdAtOffsetMinutes;
  final Value<int> rowid;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.markerId = const Value.absent(),
    this.relativeBasename = const Value.absent(),
    this.widthPx = const Value.absent(),
    this.heightPx = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.createdAtOffsetMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosCompanion.insert({
    required String id,
    required String markerId,
    required String relativeBasename,
    required int widthPx,
    required int heightPx,
    required int fileSizeBytes,
    required DateTime createdAtUtc,
    required int createdAtOffsetMinutes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       markerId = Value(markerId),
       relativeBasename = Value(relativeBasename),
       widthPx = Value(widthPx),
       heightPx = Value(heightPx),
       fileSizeBytes = Value(fileSizeBytes),
       createdAtUtc = Value(createdAtUtc),
       createdAtOffsetMinutes = Value(createdAtOffsetMinutes);
  static Insertable<PhotoRow> custom({
    Expression<String>? id,
    Expression<String>? markerId,
    Expression<String>? relativeBasename,
    Expression<int>? widthPx,
    Expression<int>? heightPx,
    Expression<int>? fileSizeBytes,
    Expression<int>? createdAtUtc,
    Expression<int>? createdAtOffsetMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (markerId != null) 'marker_id': markerId,
      if (relativeBasename != null) 'relative_basename': relativeBasename,
      if (widthPx != null) 'width_px': widthPx,
      if (heightPx != null) 'height_px': heightPx,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (createdAtOffsetMinutes != null) 'created_at_offset_minutes': createdAtOffsetMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? markerId,
    Value<String>? relativeBasename,
    Value<int>? widthPx,
    Value<int>? heightPx,
    Value<int>? fileSizeBytes,
    Value<DateTime>? createdAtUtc,
    Value<int>? createdAtOffsetMinutes,
    Value<int>? rowid,
  }) {
    return PhotosCompanion(
      id: id ?? this.id,
      markerId: markerId ?? this.markerId,
      relativeBasename: relativeBasename ?? this.relativeBasename,
      widthPx: widthPx ?? this.widthPx,
      heightPx: heightPx ?? this.heightPx,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      createdAtOffsetMinutes: createdAtOffsetMinutes ?? this.createdAtOffsetMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (markerId.present) {
      map['marker_id'] = Variable<String>(markerId.value);
    }
    if (relativeBasename.present) {
      map['relative_basename'] = Variable<String>(relativeBasename.value);
    }
    if (widthPx.present) {
      map['width_px'] = Variable<int>(widthPx.value);
    }
    if (heightPx.present) {
      map['height_px'] = Variable<int>(heightPx.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>($PhotosTable.$convertercreatedAtUtc.toSql(createdAtUtc.value));
    }
    if (createdAtOffsetMinutes.present) {
      map['created_at_offset_minutes'] = Variable<int>(createdAtOffsetMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('markerId: $markerId, ')
          ..write('relativeBasename: $relativeBasename, ')
          ..write('widthPx: $widthPx, ')
          ..write('heightPx: $heightPx, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('createdAtOffsetMinutes: $createdAtOffsetMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MarkerCategoriesTable markerCategories = $MarkerCategoriesTable(this);
  late final $MarkersTable markers = $MarkersTable(this);
  late final $RevealedTilesTable revealedTiles = $RevealedTilesTable(this);
  late final $MirkStylesTable mirkStyles = $MirkStylesTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final Index idxTSessionsStatusActive = Index(
    'idx_t_sessions_status_active',
    'CREATE UNIQUE INDEX idx_t_sessions_status_active ON t_sessions (status) WHERE status = \'active\'',
  );
  late final Index idxTMarkersSessionId = Index('idx_t_markers_session_id', 'CREATE INDEX idx_t_markers_session_id ON t_markers (session_id)');
  late final Index idxTMarkersCategoryId = Index('idx_t_markers_category_id', 'CREATE INDEX idx_t_markers_category_id ON t_markers (category_id)');
  late final Index idxTRevealedTilesSessionIdParentKey = Index(
    'idx_t_revealed_tiles_session_id_parent_key',
    'CREATE INDEX idx_t_revealed_tiles_session_id_parent_key ON t_revealed_tiles (session_id, parent_x, parent_y)',
  );
  late final Index idxTPhotosMarkerId = Index('idx_t_photos_marker_id', 'CREATE INDEX idx_t_photos_marker_id ON t_photos (marker_id)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    markerCategories,
    markers,
    revealedTiles,
    mirkStyles,
    photos,
    idxTSessionsStatusActive,
    idxTMarkersSessionId,
    idxTMarkersCategoryId,
    idxTRevealedTilesSessionIdParentKey,
    idxTPhotosMarkerId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('t_sessions', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('t_markers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('t_sessions', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('t_revealed_tiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('t_markers', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('t_photos', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      required String displayName,
      required String status,
      required DateTime startedAtUtc,
      required int startedAtOffsetMinutes,
      Value<DateTime?> stoppedAtUtc,
      Value<int?> stoppedAtOffsetMinutes,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> status,
      Value<DateTime> startedAtUtc,
      Value<int> startedAtOffsetMinutes,
      Value<DateTime?> stoppedAtUtc,
      Value<int?> stoppedAtOffsetMinutes,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$SessionsTableReferences extends BaseReferences<_$AppDatabase, $SessionsTable, SessionRow> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MarkersTable, List<MarkerRow>> _markersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.markers, aliasName: $_aliasNameGenerator(db.sessions.id, db.markers.sessionId));

  $$MarkersTableProcessedTableManager get markersRefs {
    final manager = $$MarkersTableTableManager($_db, $_db.markers).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_markersRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$RevealedTilesTable, List<RevealedTileRow>> _revealedTilesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.revealedTiles, aliasName: $_aliasNameGenerator(db.sessions.id, db.revealedTiles.sessionId));

  $$RevealedTilesTableProcessedTableManager get revealedTilesRefs {
    final manager = $$RevealedTilesTableTableManager($_db, $_db.revealedTiles).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_revealedTilesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableFilterComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get startedAtUtc =>
      $composableBuilder(column: $table.startedAtUtc, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get startedAtOffsetMinutes => $composableBuilder(column: $table.startedAtOffsetMinutes, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get stoppedAtUtc =>
      $composableBuilder(column: $table.stoppedAtUtc, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get stoppedAtOffsetMinutes => $composableBuilder(column: $table.stoppedAtOffsetMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  Expression<bool> markersRefs(Expression<bool> Function($$MarkersTableFilterComposer f) f) {
    final $$MarkersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkersTableFilterComposer(
        $db: $db,
        $table: $db.markers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }

  Expression<bool> revealedTilesRefs(Expression<bool> Function($$RevealedTilesTableFilterComposer f) f) {
    final $$RevealedTilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.revealedTiles,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$RevealedTilesTableFilterComposer(
        $db: $db,
        $table: $db.revealedTiles,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAtUtc => $composableBuilder(column: $table.startedAtUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAtOffsetMinutes => $composableBuilder(column: $table.startedAtOffsetMinutes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stoppedAtUtc => $composableBuilder(column: $table.stoppedAtUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stoppedAtOffsetMinutes => $composableBuilder(column: $table.stoppedAtOffsetMinutes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get status => $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get startedAtUtc => $composableBuilder(column: $table.startedAtUtc, builder: (column) => column);

  GeneratedColumn<int> get startedAtOffsetMinutes => $composableBuilder(column: $table.startedAtOffsetMinutes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get stoppedAtUtc => $composableBuilder(column: $table.stoppedAtUtc, builder: (column) => column);

  GeneratedColumn<int> get stoppedAtOffsetMinutes => $composableBuilder(column: $table.stoppedAtOffsetMinutes, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> markersRefs<T extends Object>(Expression<T> Function($$MarkersTableAnnotationComposer a) f) {
    final $$MarkersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkersTableAnnotationComposer(
        $db: $db,
        $table: $db.markers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }

  Expression<T> revealedTilesRefs<T extends Object>(Expression<T> Function($$RevealedTilesTableAnnotationComposer a) f) {
    final $$RevealedTilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.revealedTiles,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$RevealedTilesTableAnnotationComposer(
        $db: $db,
        $table: $db.revealedTiles,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (SessionRow, $$SessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({bool markersRefs, bool revealedTilesRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAtUtc = const Value.absent(),
                Value<int> startedAtOffsetMinutes = const Value.absent(),
                Value<DateTime?> stoppedAtUtc = const Value.absent(),
                Value<int?> stoppedAtOffsetMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                displayName: displayName,
                status: status,
                startedAtUtc: startedAtUtc,
                startedAtOffsetMinutes: startedAtOffsetMinutes,
                stoppedAtUtc: stoppedAtUtc,
                stoppedAtOffsetMinutes: stoppedAtOffsetMinutes,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String status,
                required DateTime startedAtUtc,
                required int startedAtOffsetMinutes,
                Value<DateTime?> stoppedAtUtc = const Value.absent(),
                Value<int?> stoppedAtOffsetMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                displayName: displayName,
                status: status,
                startedAtUtc: startedAtUtc,
                startedAtOffsetMinutes: startedAtOffsetMinutes,
                stoppedAtUtc: stoppedAtUtc,
                stoppedAtOffsetMinutes: stoppedAtOffsetMinutes,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), $$SessionsTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({markersRefs = false, revealedTilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (markersRefs) db.markers, if (revealedTilesRefs) db.revealedTiles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (markersRefs)
                    await $_getPrefetchedData<SessionRow, $SessionsTable, MarkerRow>(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences._markersRefsTable(db),
                      managerFromTypedResult: (p0) => $$SessionsTableReferences(db, table, p0).markersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) => referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                  if (revealedTilesRefs)
                    await $_getPrefetchedData<SessionRow, $SessionsTable, RevealedTileRow>(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences._revealedTilesRefsTable(db),
                      managerFromTypedResult: (p0) => $$SessionsTableReferences(db, table, p0).revealedTilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) => referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, $$SessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({bool markersRefs, bool revealedTilesRefs})
    >;
typedef $$MarkerCategoriesTableCreateCompanionBuilder =
    MarkerCategoriesCompanion Function({
      required String id,
      required String displayName,
      required String iconName,
      required DateTime createdAtUtc,
      required int createdAtOffsetMinutes,
      Value<int> rowid,
    });
typedef $$MarkerCategoriesTableUpdateCompanionBuilder =
    MarkerCategoriesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> iconName,
      Value<DateTime> createdAtUtc,
      Value<int> createdAtOffsetMinutes,
      Value<int> rowid,
    });

final class $$MarkerCategoriesTableReferences extends BaseReferences<_$AppDatabase, $MarkerCategoriesTable, MarkerCategoryRow> {
  $$MarkerCategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MarkersTable, List<MarkerRow>> _markersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.markers, aliasName: $_aliasNameGenerator(db.markerCategories.id, db.markers.categoryId));

  $$MarkersTableProcessedTableManager get markersRefs {
    final manager = $$MarkersTableTableManager($_db, $_db.markers).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_markersRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MarkerCategoriesTableFilterComposer extends Composer<_$AppDatabase, $MarkerCategoriesTable> {
  $$MarkerCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAtUtc =>
      $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnFilters(column));

  Expression<bool> markersRefs(Expression<bool> Function($$MarkersTableFilterComposer f) f) {
    final $$MarkersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkersTableFilterComposer(
        $db: $db,
        $table: $db.markers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$MarkerCategoriesTableOrderingComposer extends Composer<_$AppDatabase, $MarkerCategoriesTable> {
  $$MarkerCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnOrderings(column));
}

class $$MarkerCategoriesTableAnnotationComposer extends Composer<_$AppDatabase, $MarkerCategoriesTable> {
  $$MarkerCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get iconName => $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => column);

  GeneratedColumn<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => column);

  Expression<T> markersRefs<T extends Object>(Expression<T> Function($$MarkersTableAnnotationComposer a) f) {
    final $$MarkersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkersTableAnnotationComposer(
        $db: $db,
        $table: $db.markers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$MarkerCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarkerCategoriesTable,
          MarkerCategoryRow,
          $$MarkerCategoriesTableFilterComposer,
          $$MarkerCategoriesTableOrderingComposer,
          $$MarkerCategoriesTableAnnotationComposer,
          $$MarkerCategoriesTableCreateCompanionBuilder,
          $$MarkerCategoriesTableUpdateCompanionBuilder,
          (MarkerCategoryRow, $$MarkerCategoriesTableReferences),
          MarkerCategoryRow,
          PrefetchHooks Function({bool markersRefs})
        > {
  $$MarkerCategoriesTableTableManager(_$AppDatabase db, $MarkerCategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MarkerCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MarkerCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MarkerCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> createdAtOffsetMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarkerCategoriesCompanion(
                id: id,
                displayName: displayName,
                iconName: iconName,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String iconName,
                required DateTime createdAtUtc,
                required int createdAtOffsetMinutes,
                Value<int> rowid = const Value.absent(),
              }) => MarkerCategoriesCompanion.insert(
                id: id,
                displayName: displayName,
                iconName: iconName,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), $$MarkerCategoriesTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({markersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (markersRefs) db.markers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (markersRefs)
                    await $_getPrefetchedData<MarkerCategoryRow, $MarkerCategoriesTable, MarkerRow>(
                      currentTable: table,
                      referencedTable: $$MarkerCategoriesTableReferences._markersRefsTable(db),
                      managerFromTypedResult: (p0) => $$MarkerCategoriesTableReferences(db, table, p0).markersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) => referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MarkerCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarkerCategoriesTable,
      MarkerCategoryRow,
      $$MarkerCategoriesTableFilterComposer,
      $$MarkerCategoriesTableOrderingComposer,
      $$MarkerCategoriesTableAnnotationComposer,
      $$MarkerCategoriesTableCreateCompanionBuilder,
      $$MarkerCategoriesTableUpdateCompanionBuilder,
      (MarkerCategoryRow, $$MarkerCategoriesTableReferences),
      MarkerCategoryRow,
      PrefetchHooks Function({bool markersRefs})
    >;
typedef $$MarkersTableCreateCompanionBuilder =
    MarkersCompanion Function({
      required String id,
      required String sessionId,
      required String categoryId,
      required double lat,
      required double lon,
      required String title,
      Value<String?> notes,
      required DateTime createdAtUtc,
      required int createdAtOffsetMinutes,
      Value<int> rowid,
    });
typedef $$MarkersTableUpdateCompanionBuilder =
    MarkersCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> categoryId,
      Value<double> lat,
      Value<double> lon,
      Value<String> title,
      Value<String?> notes,
      Value<DateTime> createdAtUtc,
      Value<int> createdAtOffsetMinutes,
      Value<int> rowid,
    });

final class $$MarkersTableReferences extends BaseReferences<_$AppDatabase, $MarkersTable, MarkerRow> {
  $$MarkersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) => db.sessions.createAlias($_aliasNameGenerator(db.markers.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager($_db, $_db.sessions).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static $MarkerCategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.markerCategories.createAlias($_aliasNameGenerator(db.markers.categoryId, db.markerCategories.id));

  $$MarkerCategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$MarkerCategoriesTableTableManager($_db, $_db.markerCategories).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$PhotosTable, List<PhotoRow>> _photosRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.photos, aliasName: $_aliasNameGenerator(db.markers.id, db.photos.markerId));

  $$PhotosTableProcessedTableManager get photosRefs {
    final manager = $$PhotosTableTableManager($_db, $_db.photos).filter((f) => f.markerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_photosRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MarkersTableFilterComposer extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lon => $composableBuilder(column: $table.lon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAtUtc =>
      $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$SessionsTableFilterComposer(
        $db: $db,
        $table: $db.sessions,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }

  $$MarkerCategoriesTableFilterComposer get categoryId {
    final $$MarkerCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.markerCategories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkerCategoriesTableFilterComposer(
        $db: $db,
        $table: $db.markerCategories,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }

  Expression<bool> photosRefs(Expression<bool> Function($$PhotosTableFilterComposer f) f) {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.markerId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$PhotosTableFilterComposer(
        $db: $db,
        $table: $db.photos,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$MarkersTableOrderingComposer extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lon => $composableBuilder(column: $table.lon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$SessionsTableOrderingComposer(
        $db: $db,
        $table: $db.sessions,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }

  $$MarkerCategoriesTableOrderingComposer get categoryId {
    final $$MarkerCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.markerCategories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkerCategoriesTableOrderingComposer(
        $db: $db,
        $table: $db.markerCategories,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$MarkersTableAnnotationComposer extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat => $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon => $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => column);

  GeneratedColumn<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$SessionsTableAnnotationComposer(
        $db: $db,
        $table: $db.sessions,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }

  $$MarkerCategoriesTableAnnotationComposer get categoryId {
    final $$MarkerCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.markerCategories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkerCategoriesTableAnnotationComposer(
        $db: $db,
        $table: $db.markerCategories,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }

  Expression<T> photosRefs<T extends Object>(Expression<T> Function($$PhotosTableAnnotationComposer a) f) {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.markerId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$PhotosTableAnnotationComposer(
        $db: $db,
        $table: $db.photos,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$MarkersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarkersTable,
          MarkerRow,
          $$MarkersTableFilterComposer,
          $$MarkersTableOrderingComposer,
          $$MarkersTableAnnotationComposer,
          $$MarkersTableCreateCompanionBuilder,
          $$MarkersTableUpdateCompanionBuilder,
          (MarkerRow, $$MarkersTableReferences),
          MarkerRow,
          PrefetchHooks Function({bool sessionId, bool categoryId, bool photosRefs})
        > {
  $$MarkersTableTableManager(_$AppDatabase db, $MarkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lon = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> createdAtOffsetMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarkersCompanion(
                id: id,
                sessionId: sessionId,
                categoryId: categoryId,
                lat: lat,
                lon: lon,
                title: title,
                notes: notes,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String categoryId,
                required double lat,
                required double lon,
                required String title,
                Value<String?> notes = const Value.absent(),
                required DateTime createdAtUtc,
                required int createdAtOffsetMinutes,
                Value<int> rowid = const Value.absent(),
              }) => MarkersCompanion.insert(
                id: id,
                sessionId: sessionId,
                categoryId: categoryId,
                lat: lat,
                lon: lon,
                title: title,
                notes: notes,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), $$MarkersTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({sessionId = false, categoryId = false, photosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (photosRefs) db.photos],
              addJoins:
                  <T extends TableManagerState<dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic>>(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$MarkersTableReferences._sessionIdTable(db),
                                referencedColumn: $$MarkersTableReferences._sessionIdTable(db).id,
                              )
                              as T;
                    }
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$MarkersTableReferences._categoryIdTable(db),
                                referencedColumn: $$MarkersTableReferences._categoryIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (photosRefs)
                    await $_getPrefetchedData<MarkerRow, $MarkersTable, PhotoRow>(
                      currentTable: table,
                      referencedTable: $$MarkersTableReferences._photosRefsTable(db),
                      managerFromTypedResult: (p0) => $$MarkersTableReferences(db, table, p0).photosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) => referencedItems.where((e) => e.markerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarkersTable,
      MarkerRow,
      $$MarkersTableFilterComposer,
      $$MarkersTableOrderingComposer,
      $$MarkersTableAnnotationComposer,
      $$MarkersTableCreateCompanionBuilder,
      $$MarkersTableUpdateCompanionBuilder,
      (MarkerRow, $$MarkersTableReferences),
      MarkerRow,
      PrefetchHooks Function({bool sessionId, bool categoryId, bool photosRefs})
    >;
typedef $$RevealedTilesTableCreateCompanionBuilder =
    RevealedTilesCompanion Function({
      required String id,
      required String sessionId,
      required int parentX,
      required int parentY,
      Value<int> parentZoom,
      required Uint8List bitmap,
      Value<int> setBitCount,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$RevealedTilesTableUpdateCompanionBuilder =
    RevealedTilesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> parentX,
      Value<int> parentY,
      Value<int> parentZoom,
      Value<Uint8List> bitmap,
      Value<int> setBitCount,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$RevealedTilesTableReferences extends BaseReferences<_$AppDatabase, $RevealedTilesTable, RevealedTileRow> {
  $$RevealedTilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) => db.sessions.createAlias($_aliasNameGenerator(db.revealedTiles.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager($_db, $_db.sessions).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RevealedTilesTableFilterComposer extends Composer<_$AppDatabase, $RevealedTilesTable> {
  $$RevealedTilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentX => $composableBuilder(column: $table.parentX, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentY => $composableBuilder(column: $table.parentY, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentZoom => $composableBuilder(column: $table.parentZoom, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get bitmap => $composableBuilder(column: $table.bitmap, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get setBitCount => $composableBuilder(column: $table.setBitCount, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAtUtc =>
      $composableBuilder(column: $table.updatedAtUtc, builder: (column) => ColumnWithTypeConverterFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$SessionsTableFilterComposer(
        $db: $db,
        $table: $db.sessions,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$RevealedTilesTableOrderingComposer extends Composer<_$AppDatabase, $RevealedTilesTable> {
  $$RevealedTilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentX => $composableBuilder(column: $table.parentX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentY => $composableBuilder(column: $table.parentY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentZoom => $composableBuilder(column: $table.parentZoom, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get bitmap => $composableBuilder(column: $table.bitmap, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get setBitCount => $composableBuilder(column: $table.setBitCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(column: $table.updatedAtUtc, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$SessionsTableOrderingComposer(
        $db: $db,
        $table: $db.sessions,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$RevealedTilesTableAnnotationComposer extends Composer<_$AppDatabase, $RevealedTilesTable> {
  $$RevealedTilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get parentX => $composableBuilder(column: $table.parentX, builder: (column) => column);

  GeneratedColumn<int> get parentY => $composableBuilder(column: $table.parentY, builder: (column) => column);

  GeneratedColumn<int> get parentZoom => $composableBuilder(column: $table.parentZoom, builder: (column) => column);

  GeneratedColumn<Uint8List> get bitmap => $composableBuilder(column: $table.bitmap, builder: (column) => column);

  GeneratedColumn<int> get setBitCount => $composableBuilder(column: $table.setBitCount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAtUtc => $composableBuilder(column: $table.updatedAtUtc, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$SessionsTableAnnotationComposer(
        $db: $db,
        $table: $db.sessions,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$RevealedTilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RevealedTilesTable,
          RevealedTileRow,
          $$RevealedTilesTableFilterComposer,
          $$RevealedTilesTableOrderingComposer,
          $$RevealedTilesTableAnnotationComposer,
          $$RevealedTilesTableCreateCompanionBuilder,
          $$RevealedTilesTableUpdateCompanionBuilder,
          (RevealedTileRow, $$RevealedTilesTableReferences),
          RevealedTileRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$RevealedTilesTableTableManager(_$AppDatabase db, $RevealedTilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RevealedTilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RevealedTilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RevealedTilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> parentX = const Value.absent(),
                Value<int> parentY = const Value.absent(),
                Value<int> parentZoom = const Value.absent(),
                Value<Uint8List> bitmap = const Value.absent(),
                Value<int> setBitCount = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RevealedTilesCompanion(
                id: id,
                sessionId: sessionId,
                parentX: parentX,
                parentY: parentY,
                parentZoom: parentZoom,
                bitmap: bitmap,
                setBitCount: setBitCount,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int parentX,
                required int parentY,
                Value<int> parentZoom = const Value.absent(),
                required Uint8List bitmap,
                Value<int> setBitCount = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => RevealedTilesCompanion.insert(
                id: id,
                sessionId: sessionId,
                parentX: parentX,
                parentY: parentY,
                parentZoom: parentZoom,
                bitmap: bitmap,
                setBitCount: setBitCount,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), $$RevealedTilesTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <T extends TableManagerState<dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic>>(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$RevealedTilesTableReferences._sessionIdTable(db),
                                referencedColumn: $$RevealedTilesTableReferences._sessionIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RevealedTilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RevealedTilesTable,
      RevealedTileRow,
      $$RevealedTilesTableFilterComposer,
      $$RevealedTilesTableOrderingComposer,
      $$RevealedTilesTableAnnotationComposer,
      $$RevealedTilesTableCreateCompanionBuilder,
      $$RevealedTilesTableUpdateCompanionBuilder,
      (RevealedTileRow, $$RevealedTilesTableReferences),
      RevealedTileRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$MirkStylesTableCreateCompanionBuilder =
    MirkStylesCompanion Function({
      required String id,
      required String displayName,
      required String rendererType,
      required MirkStyleConfig config,
      required DateTime createdAtUtc,
      required int createdAtOffsetMinutes,
      Value<int> rowid,
    });
typedef $$MirkStylesTableUpdateCompanionBuilder =
    MirkStylesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> rendererType,
      Value<MirkStyleConfig> config,
      Value<DateTime> createdAtUtc,
      Value<int> createdAtOffsetMinutes,
      Value<int> rowid,
    });

class $$MirkStylesTableFilterComposer extends Composer<_$AppDatabase, $MirkStylesTable> {
  $$MirkStylesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rendererType => $composableBuilder(column: $table.rendererType, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<MirkStyleConfig, MirkStyleConfig, String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAtUtc =>
      $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnFilters(column));
}

class $$MirkStylesTableOrderingComposer extends Composer<_$AppDatabase, $MirkStylesTable> {
  $$MirkStylesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rendererType => $composableBuilder(column: $table.rendererType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get config => $composableBuilder(column: $table.config, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnOrderings(column));
}

class $$MirkStylesTableAnnotationComposer extends Composer<_$AppDatabase, $MirkStylesTable> {
  $$MirkStylesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get rendererType => $composableBuilder(column: $table.rendererType, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MirkStyleConfig, String> get config => $composableBuilder(column: $table.config, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => column);

  GeneratedColumn<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => column);
}

class $$MirkStylesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MirkStylesTable,
          MirkStyleRow,
          $$MirkStylesTableFilterComposer,
          $$MirkStylesTableOrderingComposer,
          $$MirkStylesTableAnnotationComposer,
          $$MirkStylesTableCreateCompanionBuilder,
          $$MirkStylesTableUpdateCompanionBuilder,
          (MirkStyleRow, BaseReferences<_$AppDatabase, $MirkStylesTable, MirkStyleRow>),
          MirkStyleRow,
          PrefetchHooks Function()
        > {
  $$MirkStylesTableTableManager(_$AppDatabase db, $MirkStylesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MirkStylesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MirkStylesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MirkStylesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> rendererType = const Value.absent(),
                Value<MirkStyleConfig> config = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> createdAtOffsetMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MirkStylesCompanion(
                id: id,
                displayName: displayName,
                rendererType: rendererType,
                config: config,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String rendererType,
                required MirkStyleConfig config,
                required DateTime createdAtUtc,
                required int createdAtOffsetMinutes,
                Value<int> rowid = const Value.absent(),
              }) => MirkStylesCompanion.insert(
                id: id,
                displayName: displayName,
                rendererType: rendererType,
                config: config,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MirkStylesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MirkStylesTable,
      MirkStyleRow,
      $$MirkStylesTableFilterComposer,
      $$MirkStylesTableOrderingComposer,
      $$MirkStylesTableAnnotationComposer,
      $$MirkStylesTableCreateCompanionBuilder,
      $$MirkStylesTableUpdateCompanionBuilder,
      (MirkStyleRow, BaseReferences<_$AppDatabase, $MirkStylesTable, MirkStyleRow>),
      MirkStyleRow,
      PrefetchHooks Function()
    >;
typedef $$PhotosTableCreateCompanionBuilder =
    PhotosCompanion Function({
      required String id,
      required String markerId,
      required String relativeBasename,
      required int widthPx,
      required int heightPx,
      required int fileSizeBytes,
      required DateTime createdAtUtc,
      required int createdAtOffsetMinutes,
      Value<int> rowid,
    });
typedef $$PhotosTableUpdateCompanionBuilder =
    PhotosCompanion Function({
      Value<String> id,
      Value<String> markerId,
      Value<String> relativeBasename,
      Value<int> widthPx,
      Value<int> heightPx,
      Value<int> fileSizeBytes,
      Value<DateTime> createdAtUtc,
      Value<int> createdAtOffsetMinutes,
      Value<int> rowid,
    });

final class $$PhotosTableReferences extends BaseReferences<_$AppDatabase, $PhotosTable, PhotoRow> {
  $$PhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MarkersTable _markerIdTable(_$AppDatabase db) => db.markers.createAlias($_aliasNameGenerator(db.photos.markerId, db.markers.id));

  $$MarkersTableProcessedTableManager get markerId {
    final $_column = $_itemColumn<String>('marker_id')!;

    final manager = $$MarkersTableTableManager($_db, $_db.markers).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_markerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PhotosTableFilterComposer extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relativeBasename => $composableBuilder(column: $table.relativeBasename, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get widthPx => $composableBuilder(column: $table.widthPx, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heightPx => $composableBuilder(column: $table.heightPx, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAtUtc =>
      $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnFilters(column));

  $$MarkersTableFilterComposer get markerId {
    final $$MarkersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.markerId,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkersTableFilterComposer(
        $db: $db,
        $table: $db.markers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$PhotosTableOrderingComposer extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relativeBasename => $composableBuilder(column: $table.relativeBasename, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get widthPx => $composableBuilder(column: $table.widthPx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heightPx => $composableBuilder(column: $table.heightPx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(column: $table.fileSizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => ColumnOrderings(column));

  $$MarkersTableOrderingComposer get markerId {
    final $$MarkersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.markerId,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkersTableOrderingComposer(
        $db: $db,
        $table: $db.markers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$PhotosTableAnnotationComposer extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relativeBasename => $composableBuilder(column: $table.relativeBasename, builder: (column) => column);

  GeneratedColumn<int> get widthPx => $composableBuilder(column: $table.widthPx, builder: (column) => column);

  GeneratedColumn<int> get heightPx => $composableBuilder(column: $table.heightPx, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAtUtc => $composableBuilder(column: $table.createdAtUtc, builder: (column) => column);

  GeneratedColumn<int> get createdAtOffsetMinutes => $composableBuilder(column: $table.createdAtOffsetMinutes, builder: (column) => column);

  $$MarkersTableAnnotationComposer get markerId {
    final $$MarkersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.markerId,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$MarkersTableAnnotationComposer(
        $db: $db,
        $table: $db.markers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosTable,
          PhotoRow,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (PhotoRow, $$PhotosTableReferences),
          PhotoRow,
          PrefetchHooks Function({bool markerId})
        > {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> markerId = const Value.absent(),
                Value<String> relativeBasename = const Value.absent(),
                Value<int> widthPx = const Value.absent(),
                Value<int> heightPx = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> createdAtOffsetMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion(
                id: id,
                markerId: markerId,
                relativeBasename: relativeBasename,
                widthPx: widthPx,
                heightPx: heightPx,
                fileSizeBytes: fileSizeBytes,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String markerId,
                required String relativeBasename,
                required int widthPx,
                required int heightPx,
                required int fileSizeBytes,
                required DateTime createdAtUtc,
                required int createdAtOffsetMinutes,
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion.insert(
                id: id,
                markerId: markerId,
                relativeBasename: relativeBasename,
                widthPx: widthPx,
                heightPx: heightPx,
                fileSizeBytes: fileSizeBytes,
                createdAtUtc: createdAtUtc,
                createdAtOffsetMinutes: createdAtOffsetMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), $$PhotosTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({markerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <T extends TableManagerState<dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic>>(state) {
                    if (markerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.markerId,
                                referencedTable: $$PhotosTableReferences._markerIdTable(db),
                                referencedColumn: $$PhotosTableReferences._markerIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosTable,
      PhotoRow,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (PhotoRow, $$PhotosTableReferences),
      PhotoRow,
      PrefetchHooks Function({bool markerId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions => $$SessionsTableTableManager(_db, _db.sessions);
  $$MarkerCategoriesTableTableManager get markerCategories => $$MarkerCategoriesTableTableManager(_db, _db.markerCategories);
  $$MarkersTableTableManager get markers => $$MarkersTableTableManager(_db, _db.markers);
  $$RevealedTilesTableTableManager get revealedTiles => $$RevealedTilesTableTableManager(_db, _db.revealedTiles);
  $$MirkStylesTableTableManager get mirkStyles => $$MirkStylesTableTableManager(_db, _db.mirkStyles);
  $$PhotosTableTableManager get photos => $$PhotosTableTableManager(_db, _db.photos);
}

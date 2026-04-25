// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Session {

@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId get id; String get displayName; SessionStatus get status; DateTime get startedAtUtc; int get startedAtOffsetMinutes; DateTime? get stoppedAtUtc; int? get stoppedAtOffsetMinutes; String? get notes;@JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable) MirkStyleId? get mirkStyleId;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAtUtc, startedAtUtc) || other.startedAtUtc == startedAtUtc)&&(identical(other.startedAtOffsetMinutes, startedAtOffsetMinutes) || other.startedAtOffsetMinutes == startedAtOffsetMinutes)&&(identical(other.stoppedAtUtc, stoppedAtUtc) || other.stoppedAtUtc == stoppedAtUtc)&&(identical(other.stoppedAtOffsetMinutes, stoppedAtOffsetMinutes) || other.stoppedAtOffsetMinutes == stoppedAtOffsetMinutes)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.mirkStyleId, mirkStyleId) || other.mirkStyleId == mirkStyleId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,status,startedAtUtc,startedAtOffsetMinutes,stoppedAtUtc,stoppedAtOffsetMinutes,notes,mirkStyleId);

@override
String toString() {
  return 'Session(id: $id, displayName: $displayName, status: $status, startedAtUtc: $startedAtUtc, startedAtOffsetMinutes: $startedAtOffsetMinutes, stoppedAtUtc: $stoppedAtUtc, stoppedAtOffsetMinutes: $stoppedAtOffsetMinutes, notes: $notes, mirkStyleId: $mirkStyleId)';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId id, String displayName, SessionStatus status, DateTime startedAtUtc, int startedAtOffsetMinutes, DateTime? stoppedAtUtc, int? stoppedAtOffsetMinutes, String? notes,@JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable) MirkStyleId? mirkStyleId
});




}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? status = null,Object? startedAtUtc = null,Object? startedAtOffsetMinutes = null,Object? stoppedAtUtc = freezed,Object? stoppedAtOffsetMinutes = freezed,Object? notes = freezed,Object? mirkStyleId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as SessionId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,startedAtUtc: null == startedAtUtc ? _self.startedAtUtc : startedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,startedAtOffsetMinutes: null == startedAtOffsetMinutes ? _self.startedAtOffsetMinutes : startedAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,stoppedAtUtc: freezed == stoppedAtUtc ? _self.stoppedAtUtc : stoppedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime?,stoppedAtOffsetMinutes: freezed == stoppedAtOffsetMinutes ? _self.stoppedAtOffsetMinutes : stoppedAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,mirkStyleId: freezed == mirkStyleId ? _self.mirkStyleId : mirkStyleId // ignore: cast_nullable_to_non_nullable
as MirkStyleId?,
  ));
}

}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId id,  String displayName,  SessionStatus status,  DateTime startedAtUtc,  int startedAtOffsetMinutes,  DateTime? stoppedAtUtc,  int? stoppedAtOffsetMinutes,  String? notes, @JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable)  MirkStyleId? mirkStyleId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.displayName,_that.status,_that.startedAtUtc,_that.startedAtOffsetMinutes,_that.stoppedAtUtc,_that.stoppedAtOffsetMinutes,_that.notes,_that.mirkStyleId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId id,  String displayName,  SessionStatus status,  DateTime startedAtUtc,  int startedAtOffsetMinutes,  DateTime? stoppedAtUtc,  int? stoppedAtOffsetMinutes,  String? notes, @JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable)  MirkStyleId? mirkStyleId)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.displayName,_that.status,_that.startedAtUtc,_that.startedAtOffsetMinutes,_that.stoppedAtUtc,_that.stoppedAtOffsetMinutes,_that.notes,_that.mirkStyleId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId id,  String displayName,  SessionStatus status,  DateTime startedAtUtc,  int startedAtOffsetMinutes,  DateTime? stoppedAtUtc,  int? stoppedAtOffsetMinutes,  String? notes, @JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable)  MirkStyleId? mirkStyleId)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.displayName,_that.status,_that.startedAtUtc,_that.startedAtOffsetMinutes,_that.stoppedAtUtc,_that.stoppedAtOffsetMinutes,_that.notes,_that.mirkStyleId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Session implements Session {
   _Session({@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) required this.id, required this.displayName, required this.status, required this.startedAtUtc, required this.startedAtOffsetMinutes, this.stoppedAtUtc, this.stoppedAtOffsetMinutes, this.notes, @JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable) this.mirkStyleId}): assert(displayName.trim().isNotEmpty, 'Session.displayName must be non-empty'),assert(startedAtOffsetMinutes >= -720 && startedAtOffsetMinutes <= 840, 'Session.startedAtOffsetMinutes out of range (UTC-12 to UTC+14)'),assert(stoppedAtOffsetMinutes == null || (stoppedAtOffsetMinutes >= -720 && stoppedAtOffsetMinutes <= 840), 'Session.stoppedAtOffsetMinutes out of range (UTC-12 to UTC+14)');
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) final  SessionId id;
@override final  String displayName;
@override final  SessionStatus status;
@override final  DateTime startedAtUtc;
@override final  int startedAtOffsetMinutes;
@override final  DateTime? stoppedAtUtc;
@override final  int? stoppedAtOffsetMinutes;
@override final  String? notes;
@override@JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable) final  MirkStyleId? mirkStyleId;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAtUtc, startedAtUtc) || other.startedAtUtc == startedAtUtc)&&(identical(other.startedAtOffsetMinutes, startedAtOffsetMinutes) || other.startedAtOffsetMinutes == startedAtOffsetMinutes)&&(identical(other.stoppedAtUtc, stoppedAtUtc) || other.stoppedAtUtc == stoppedAtUtc)&&(identical(other.stoppedAtOffsetMinutes, stoppedAtOffsetMinutes) || other.stoppedAtOffsetMinutes == stoppedAtOffsetMinutes)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.mirkStyleId, mirkStyleId) || other.mirkStyleId == mirkStyleId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,status,startedAtUtc,startedAtOffsetMinutes,stoppedAtUtc,stoppedAtOffsetMinutes,notes,mirkStyleId);

@override
String toString() {
  return 'Session(id: $id, displayName: $displayName, status: $status, startedAtUtc: $startedAtUtc, startedAtOffsetMinutes: $startedAtOffsetMinutes, stoppedAtUtc: $stoppedAtUtc, stoppedAtOffsetMinutes: $stoppedAtOffsetMinutes, notes: $notes, mirkStyleId: $mirkStyleId)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId id, String displayName, SessionStatus status, DateTime startedAtUtc, int startedAtOffsetMinutes, DateTime? stoppedAtUtc, int? stoppedAtOffsetMinutes, String? notes,@JsonKey(fromJson: _mirkStyleIdFromJsonNullable, toJson: _mirkStyleIdToJsonNullable) MirkStyleId? mirkStyleId
});




}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? status = null,Object? startedAtUtc = null,Object? startedAtOffsetMinutes = null,Object? stoppedAtUtc = freezed,Object? stoppedAtOffsetMinutes = freezed,Object? notes = freezed,Object? mirkStyleId = freezed,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as SessionId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,startedAtUtc: null == startedAtUtc ? _self.startedAtUtc : startedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,startedAtOffsetMinutes: null == startedAtOffsetMinutes ? _self.startedAtOffsetMinutes : startedAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,stoppedAtUtc: freezed == stoppedAtUtc ? _self.stoppedAtUtc : stoppedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime?,stoppedAtOffsetMinutes: freezed == stoppedAtOffsetMinutes ? _self.stoppedAtOffsetMinutes : stoppedAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,mirkStyleId: freezed == mirkStyleId ? _self.mirkStyleId : mirkStyleId // ignore: cast_nullable_to_non_nullable
as MirkStyleId?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mirk_style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MirkStyle {

@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson) MirkStyleId get id; String get displayName; MirkStyleConfig get config; DateTime get createdAtUtc; int get createdAtOffsetMinutes;
/// Create a copy of MirkStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MirkStyleCopyWith<MirkStyle> get copyWith => _$MirkStyleCopyWithImpl<MirkStyle>(this as MirkStyle, _$identity);

  /// Serializes this MirkStyle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MirkStyle&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.config, config) || other.config == config)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,config,createdAtUtc,createdAtOffsetMinutes);

@override
String toString() {
  return 'MirkStyle(id: $id, displayName: $displayName, config: $config, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class $MirkStyleCopyWith<$Res>  {
  factory $MirkStyleCopyWith(MirkStyle value, $Res Function(MirkStyle) _then) = _$MirkStyleCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson) MirkStyleId id, String displayName, MirkStyleConfig config, DateTime createdAtUtc, int createdAtOffsetMinutes
});


$MirkStyleConfigCopyWith<$Res> get config;

}
/// @nodoc
class _$MirkStyleCopyWithImpl<$Res>
    implements $MirkStyleCopyWith<$Res> {
  _$MirkStyleCopyWithImpl(this._self, this._then);

  final MirkStyle _self;
  final $Res Function(MirkStyle) _then;

/// Create a copy of MirkStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? config = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MirkStyleId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as MirkStyleConfig,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of MirkStyle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MirkStyleConfigCopyWith<$Res> get config {
  
  return $MirkStyleConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// Adds pattern-matching-related methods to [MirkStyle].
extension MirkStylePatterns on MirkStyle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MirkStyle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MirkStyle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MirkStyle value)  $default,){
final _that = this;
switch (_that) {
case _MirkStyle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MirkStyle value)?  $default,){
final _that = this;
switch (_that) {
case _MirkStyle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson)  MirkStyleId id,  String displayName,  MirkStyleConfig config,  DateTime createdAtUtc,  int createdAtOffsetMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MirkStyle() when $default != null:
return $default(_that.id,_that.displayName,_that.config,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson)  MirkStyleId id,  String displayName,  MirkStyleConfig config,  DateTime createdAtUtc,  int createdAtOffsetMinutes)  $default,) {final _that = this;
switch (_that) {
case _MirkStyle():
return $default(_that.id,_that.displayName,_that.config,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson)  MirkStyleId id,  String displayName,  MirkStyleConfig config,  DateTime createdAtUtc,  int createdAtOffsetMinutes)?  $default,) {final _that = this;
switch (_that) {
case _MirkStyle() when $default != null:
return $default(_that.id,_that.displayName,_that.config,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MirkStyle implements MirkStyle {
   _MirkStyle({@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson) required this.id, required this.displayName, required this.config, required this.createdAtUtc, required this.createdAtOffsetMinutes}): assert(displayName.trim().isNotEmpty, 'MirkStyle.displayName must be non-empty');
  factory _MirkStyle.fromJson(Map<String, dynamic> json) => _$MirkStyleFromJson(json);

@override@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson) final  MirkStyleId id;
@override final  String displayName;
@override final  MirkStyleConfig config;
@override final  DateTime createdAtUtc;
@override final  int createdAtOffsetMinutes;

/// Create a copy of MirkStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MirkStyleCopyWith<_MirkStyle> get copyWith => __$MirkStyleCopyWithImpl<_MirkStyle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MirkStyleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MirkStyle&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.config, config) || other.config == config)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,config,createdAtUtc,createdAtOffsetMinutes);

@override
String toString() {
  return 'MirkStyle(id: $id, displayName: $displayName, config: $config, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$MirkStyleCopyWith<$Res> implements $MirkStyleCopyWith<$Res> {
  factory _$MirkStyleCopyWith(_MirkStyle value, $Res Function(_MirkStyle) _then) = __$MirkStyleCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: mirkStyleIdFromJson, toJson: mirkStyleIdToJson) MirkStyleId id, String displayName, MirkStyleConfig config, DateTime createdAtUtc, int createdAtOffsetMinutes
});


@override $MirkStyleConfigCopyWith<$Res> get config;

}
/// @nodoc
class __$MirkStyleCopyWithImpl<$Res>
    implements _$MirkStyleCopyWith<$Res> {
  __$MirkStyleCopyWithImpl(this._self, this._then);

  final _MirkStyle _self;
  final $Res Function(_MirkStyle) _then;

/// Create a copy of MirkStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? config = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,}) {
  return _then(_MirkStyle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MirkStyleId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as MirkStyleConfig,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of MirkStyle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MirkStyleConfigCopyWith<$Res> get config {
  
  return $MirkStyleConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}

// dart format on

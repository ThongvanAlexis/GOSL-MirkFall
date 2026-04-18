// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'revealed_tile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RevealedTile {

 RevealedTileId get id; SessionId get sessionId; int get parentX; int get parentY; int get parentZoom; Uint8List get bitmap; int get setBitCount; DateTime get updatedAtUtc;
/// Create a copy of RevealedTile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RevealedTileCopyWith<RevealedTile> get copyWith => _$RevealedTileCopyWithImpl<RevealedTile>(this as RevealedTile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RevealedTile&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.parentX, parentX) || other.parentX == parentX)&&(identical(other.parentY, parentY) || other.parentY == parentY)&&(identical(other.parentZoom, parentZoom) || other.parentZoom == parentZoom)&&const DeepCollectionEquality().equals(other.bitmap, bitmap)&&(identical(other.setBitCount, setBitCount) || other.setBitCount == setBitCount)&&(identical(other.updatedAtUtc, updatedAtUtc) || other.updatedAtUtc == updatedAtUtc));
}


@override
int get hashCode => Object.hash(runtimeType,id,sessionId,parentX,parentY,parentZoom,const DeepCollectionEquality().hash(bitmap),setBitCount,updatedAtUtc);

@override
String toString() {
  return 'RevealedTile(id: $id, sessionId: $sessionId, parentX: $parentX, parentY: $parentY, parentZoom: $parentZoom, bitmap: $bitmap, setBitCount: $setBitCount, updatedAtUtc: $updatedAtUtc)';
}


}

/// @nodoc
abstract mixin class $RevealedTileCopyWith<$Res>  {
  factory $RevealedTileCopyWith(RevealedTile value, $Res Function(RevealedTile) _then) = _$RevealedTileCopyWithImpl;
@useResult
$Res call({
 RevealedTileId id, SessionId sessionId, int parentX, int parentY, int parentZoom, Uint8List bitmap, int setBitCount, DateTime updatedAtUtc
});




}
/// @nodoc
class _$RevealedTileCopyWithImpl<$Res>
    implements $RevealedTileCopyWith<$Res> {
  _$RevealedTileCopyWithImpl(this._self, this._then);

  final RevealedTile _self;
  final $Res Function(RevealedTile) _then;

/// Create a copy of RevealedTile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionId = null,Object? parentX = null,Object? parentY = null,Object? parentZoom = null,Object? bitmap = null,Object? setBitCount = null,Object? updatedAtUtc = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as RevealedTileId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,parentX: null == parentX ? _self.parentX : parentX // ignore: cast_nullable_to_non_nullable
as int,parentY: null == parentY ? _self.parentY : parentY // ignore: cast_nullable_to_non_nullable
as int,parentZoom: null == parentZoom ? _self.parentZoom : parentZoom // ignore: cast_nullable_to_non_nullable
as int,bitmap: null == bitmap ? _self.bitmap : bitmap // ignore: cast_nullable_to_non_nullable
as Uint8List,setBitCount: null == setBitCount ? _self.setBitCount : setBitCount // ignore: cast_nullable_to_non_nullable
as int,updatedAtUtc: null == updatedAtUtc ? _self.updatedAtUtc : updatedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RevealedTile].
extension RevealedTilePatterns on RevealedTile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RevealedTile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RevealedTile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RevealedTile value)  $default,){
final _that = this;
switch (_that) {
case _RevealedTile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RevealedTile value)?  $default,){
final _that = this;
switch (_that) {
case _RevealedTile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RevealedTileId id,  SessionId sessionId,  int parentX,  int parentY,  int parentZoom,  Uint8List bitmap,  int setBitCount,  DateTime updatedAtUtc)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RevealedTile() when $default != null:
return $default(_that.id,_that.sessionId,_that.parentX,_that.parentY,_that.parentZoom,_that.bitmap,_that.setBitCount,_that.updatedAtUtc);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RevealedTileId id,  SessionId sessionId,  int parentX,  int parentY,  int parentZoom,  Uint8List bitmap,  int setBitCount,  DateTime updatedAtUtc)  $default,) {final _that = this;
switch (_that) {
case _RevealedTile():
return $default(_that.id,_that.sessionId,_that.parentX,_that.parentY,_that.parentZoom,_that.bitmap,_that.setBitCount,_that.updatedAtUtc);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RevealedTileId id,  SessionId sessionId,  int parentX,  int parentY,  int parentZoom,  Uint8List bitmap,  int setBitCount,  DateTime updatedAtUtc)?  $default,) {final _that = this;
switch (_that) {
case _RevealedTile() when $default != null:
return $default(_that.id,_that.sessionId,_that.parentX,_that.parentY,_that.parentZoom,_that.bitmap,_that.setBitCount,_that.updatedAtUtc);case _:
  return null;

}
}

}

/// @nodoc


class _RevealedTile implements RevealedTile {
  const _RevealedTile({required this.id, required this.sessionId, required this.parentX, required this.parentY, this.parentZoom = 14, required this.bitmap, required this.setBitCount, required this.updatedAtUtc}): assert(parentX >= 0, 'RevealedTile.parentX must be >= 0'),assert(parentY >= 0, 'RevealedTile.parentY must be >= 0'),assert(parentZoom == 14, 'RevealedTile.parentZoom must equal kRevealedTileParentZoom (14)'),assert(bitmap.length == 512, 'RevealedTile.bitmap must be exactly 512 bytes (64x64 sub-grid)'),assert(setBitCount >= 0 && setBitCount <= 4096, 'RevealedTile.setBitCount must be in [0..4096] (64x64 bits)');
  

@override final  RevealedTileId id;
@override final  SessionId sessionId;
@override final  int parentX;
@override final  int parentY;
@override@JsonKey() final  int parentZoom;
@override final  Uint8List bitmap;
@override final  int setBitCount;
@override final  DateTime updatedAtUtc;

/// Create a copy of RevealedTile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RevealedTileCopyWith<_RevealedTile> get copyWith => __$RevealedTileCopyWithImpl<_RevealedTile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RevealedTile&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.parentX, parentX) || other.parentX == parentX)&&(identical(other.parentY, parentY) || other.parentY == parentY)&&(identical(other.parentZoom, parentZoom) || other.parentZoom == parentZoom)&&const DeepCollectionEquality().equals(other.bitmap, bitmap)&&(identical(other.setBitCount, setBitCount) || other.setBitCount == setBitCount)&&(identical(other.updatedAtUtc, updatedAtUtc) || other.updatedAtUtc == updatedAtUtc));
}


@override
int get hashCode => Object.hash(runtimeType,id,sessionId,parentX,parentY,parentZoom,const DeepCollectionEquality().hash(bitmap),setBitCount,updatedAtUtc);

@override
String toString() {
  return 'RevealedTile(id: $id, sessionId: $sessionId, parentX: $parentX, parentY: $parentY, parentZoom: $parentZoom, bitmap: $bitmap, setBitCount: $setBitCount, updatedAtUtc: $updatedAtUtc)';
}


}

/// @nodoc
abstract mixin class _$RevealedTileCopyWith<$Res> implements $RevealedTileCopyWith<$Res> {
  factory _$RevealedTileCopyWith(_RevealedTile value, $Res Function(_RevealedTile) _then) = __$RevealedTileCopyWithImpl;
@override @useResult
$Res call({
 RevealedTileId id, SessionId sessionId, int parentX, int parentY, int parentZoom, Uint8List bitmap, int setBitCount, DateTime updatedAtUtc
});




}
/// @nodoc
class __$RevealedTileCopyWithImpl<$Res>
    implements _$RevealedTileCopyWith<$Res> {
  __$RevealedTileCopyWithImpl(this._self, this._then);

  final _RevealedTile _self;
  final $Res Function(_RevealedTile) _then;

/// Create a copy of RevealedTile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionId = null,Object? parentX = null,Object? parentY = null,Object? parentZoom = null,Object? bitmap = null,Object? setBitCount = null,Object? updatedAtUtc = null,}) {
  return _then(_RevealedTile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as RevealedTileId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,parentX: null == parentX ? _self.parentX : parentX // ignore: cast_nullable_to_non_nullable
as int,parentY: null == parentY ? _self.parentY : parentY // ignore: cast_nullable_to_non_nullable
as int,parentZoom: null == parentZoom ? _self.parentZoom : parentZoom // ignore: cast_nullable_to_non_nullable
as int,bitmap: null == bitmap ? _self.bitmap : bitmap // ignore: cast_nullable_to_non_nullable
as Uint8List,setBitCount: null == setBitCount ? _self.setBitCount : setBitCount // ignore: cast_nullable_to_non_nullable
as int,updatedAtUtc: null == updatedAtUtc ? _self.updatedAtUtc : updatedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

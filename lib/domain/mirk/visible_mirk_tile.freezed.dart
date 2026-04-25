// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'visible_mirk_tile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VisibleMirkTile {

 int get parentX; int get parentY; Uint8List get bitmap; double get tileNorthLat; double get tileWestLon; double get tileSouthLat; double get tileEastLon;
/// Create a copy of VisibleMirkTile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VisibleMirkTileCopyWith<VisibleMirkTile> get copyWith => _$VisibleMirkTileCopyWithImpl<VisibleMirkTile>(this as VisibleMirkTile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VisibleMirkTile&&(identical(other.parentX, parentX) || other.parentX == parentX)&&(identical(other.parentY, parentY) || other.parentY == parentY)&&const DeepCollectionEquality().equals(other.bitmap, bitmap)&&(identical(other.tileNorthLat, tileNorthLat) || other.tileNorthLat == tileNorthLat)&&(identical(other.tileWestLon, tileWestLon) || other.tileWestLon == tileWestLon)&&(identical(other.tileSouthLat, tileSouthLat) || other.tileSouthLat == tileSouthLat)&&(identical(other.tileEastLon, tileEastLon) || other.tileEastLon == tileEastLon));
}


@override
int get hashCode => Object.hash(runtimeType,parentX,parentY,const DeepCollectionEquality().hash(bitmap),tileNorthLat,tileWestLon,tileSouthLat,tileEastLon);

@override
String toString() {
  return 'VisibleMirkTile(parentX: $parentX, parentY: $parentY, bitmap: $bitmap, tileNorthLat: $tileNorthLat, tileWestLon: $tileWestLon, tileSouthLat: $tileSouthLat, tileEastLon: $tileEastLon)';
}


}

/// @nodoc
abstract mixin class $VisibleMirkTileCopyWith<$Res>  {
  factory $VisibleMirkTileCopyWith(VisibleMirkTile value, $Res Function(VisibleMirkTile) _then) = _$VisibleMirkTileCopyWithImpl;
@useResult
$Res call({
 int parentX, int parentY, Uint8List bitmap, double tileNorthLat, double tileWestLon, double tileSouthLat, double tileEastLon
});




}
/// @nodoc
class _$VisibleMirkTileCopyWithImpl<$Res>
    implements $VisibleMirkTileCopyWith<$Res> {
  _$VisibleMirkTileCopyWithImpl(this._self, this._then);

  final VisibleMirkTile _self;
  final $Res Function(VisibleMirkTile) _then;

/// Create a copy of VisibleMirkTile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? parentX = null,Object? parentY = null,Object? bitmap = null,Object? tileNorthLat = null,Object? tileWestLon = null,Object? tileSouthLat = null,Object? tileEastLon = null,}) {
  return _then(_self.copyWith(
parentX: null == parentX ? _self.parentX : parentX // ignore: cast_nullable_to_non_nullable
as int,parentY: null == parentY ? _self.parentY : parentY // ignore: cast_nullable_to_non_nullable
as int,bitmap: null == bitmap ? _self.bitmap : bitmap // ignore: cast_nullable_to_non_nullable
as Uint8List,tileNorthLat: null == tileNorthLat ? _self.tileNorthLat : tileNorthLat // ignore: cast_nullable_to_non_nullable
as double,tileWestLon: null == tileWestLon ? _self.tileWestLon : tileWestLon // ignore: cast_nullable_to_non_nullable
as double,tileSouthLat: null == tileSouthLat ? _self.tileSouthLat : tileSouthLat // ignore: cast_nullable_to_non_nullable
as double,tileEastLon: null == tileEastLon ? _self.tileEastLon : tileEastLon // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [VisibleMirkTile].
extension VisibleMirkTilePatterns on VisibleMirkTile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VisibleMirkTile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VisibleMirkTile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VisibleMirkTile value)  $default,){
final _that = this;
switch (_that) {
case _VisibleMirkTile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VisibleMirkTile value)?  $default,){
final _that = this;
switch (_that) {
case _VisibleMirkTile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int parentX,  int parentY,  Uint8List bitmap,  double tileNorthLat,  double tileWestLon,  double tileSouthLat,  double tileEastLon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VisibleMirkTile() when $default != null:
return $default(_that.parentX,_that.parentY,_that.bitmap,_that.tileNorthLat,_that.tileWestLon,_that.tileSouthLat,_that.tileEastLon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int parentX,  int parentY,  Uint8List bitmap,  double tileNorthLat,  double tileWestLon,  double tileSouthLat,  double tileEastLon)  $default,) {final _that = this;
switch (_that) {
case _VisibleMirkTile():
return $default(_that.parentX,_that.parentY,_that.bitmap,_that.tileNorthLat,_that.tileWestLon,_that.tileSouthLat,_that.tileEastLon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int parentX,  int parentY,  Uint8List bitmap,  double tileNorthLat,  double tileWestLon,  double tileSouthLat,  double tileEastLon)?  $default,) {final _that = this;
switch (_that) {
case _VisibleMirkTile() when $default != null:
return $default(_that.parentX,_that.parentY,_that.bitmap,_that.tileNorthLat,_that.tileWestLon,_that.tileSouthLat,_that.tileEastLon);case _:
  return null;

}
}

}

/// @nodoc


class _VisibleMirkTile implements VisibleMirkTile {
  const _VisibleMirkTile({required this.parentX, required this.parentY, required this.bitmap, required this.tileNorthLat, required this.tileWestLon, required this.tileSouthLat, required this.tileEastLon});
  

@override final  int parentX;
@override final  int parentY;
@override final  Uint8List bitmap;
@override final  double tileNorthLat;
@override final  double tileWestLon;
@override final  double tileSouthLat;
@override final  double tileEastLon;

/// Create a copy of VisibleMirkTile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VisibleMirkTileCopyWith<_VisibleMirkTile> get copyWith => __$VisibleMirkTileCopyWithImpl<_VisibleMirkTile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VisibleMirkTile&&(identical(other.parentX, parentX) || other.parentX == parentX)&&(identical(other.parentY, parentY) || other.parentY == parentY)&&const DeepCollectionEquality().equals(other.bitmap, bitmap)&&(identical(other.tileNorthLat, tileNorthLat) || other.tileNorthLat == tileNorthLat)&&(identical(other.tileWestLon, tileWestLon) || other.tileWestLon == tileWestLon)&&(identical(other.tileSouthLat, tileSouthLat) || other.tileSouthLat == tileSouthLat)&&(identical(other.tileEastLon, tileEastLon) || other.tileEastLon == tileEastLon));
}


@override
int get hashCode => Object.hash(runtimeType,parentX,parentY,const DeepCollectionEquality().hash(bitmap),tileNorthLat,tileWestLon,tileSouthLat,tileEastLon);

@override
String toString() {
  return 'VisibleMirkTile(parentX: $parentX, parentY: $parentY, bitmap: $bitmap, tileNorthLat: $tileNorthLat, tileWestLon: $tileWestLon, tileSouthLat: $tileSouthLat, tileEastLon: $tileEastLon)';
}


}

/// @nodoc
abstract mixin class _$VisibleMirkTileCopyWith<$Res> implements $VisibleMirkTileCopyWith<$Res> {
  factory _$VisibleMirkTileCopyWith(_VisibleMirkTile value, $Res Function(_VisibleMirkTile) _then) = __$VisibleMirkTileCopyWithImpl;
@override @useResult
$Res call({
 int parentX, int parentY, Uint8List bitmap, double tileNorthLat, double tileWestLon, double tileSouthLat, double tileEastLon
});




}
/// @nodoc
class __$VisibleMirkTileCopyWithImpl<$Res>
    implements _$VisibleMirkTileCopyWith<$Res> {
  __$VisibleMirkTileCopyWithImpl(this._self, this._then);

  final _VisibleMirkTile _self;
  final $Res Function(_VisibleMirkTile) _then;

/// Create a copy of VisibleMirkTile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? parentX = null,Object? parentY = null,Object? bitmap = null,Object? tileNorthLat = null,Object? tileWestLon = null,Object? tileSouthLat = null,Object? tileEastLon = null,}) {
  return _then(_VisibleMirkTile(
parentX: null == parentX ? _self.parentX : parentX // ignore: cast_nullable_to_non_nullable
as int,parentY: null == parentY ? _self.parentY : parentY // ignore: cast_nullable_to_non_nullable
as int,bitmap: null == bitmap ? _self.bitmap : bitmap // ignore: cast_nullable_to_non_nullable
as Uint8List,tileNorthLat: null == tileNorthLat ? _self.tileNorthLat : tileNorthLat // ignore: cast_nullable_to_non_nullable
as double,tileWestLon: null == tileWestLon ? _self.tileWestLon : tileWestLon // ignore: cast_nullable_to_non_nullable
as double,tileSouthLat: null == tileSouthLat ? _self.tileSouthLat : tileSouthLat // ignore: cast_nullable_to_non_nullable
as double,tileEastLon: null == tileEastLon ? _self.tileEastLon : tileEastLon // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on

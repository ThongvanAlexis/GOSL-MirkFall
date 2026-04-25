// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mirk_viewport_bbox.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MirkViewportBbox {

 double get south; double get west; double get north; double get east;
/// Create a copy of MirkViewportBbox
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MirkViewportBboxCopyWith<MirkViewportBbox> get copyWith => _$MirkViewportBboxCopyWithImpl<MirkViewportBbox>(this as MirkViewportBbox, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MirkViewportBbox&&(identical(other.south, south) || other.south == south)&&(identical(other.west, west) || other.west == west)&&(identical(other.north, north) || other.north == north)&&(identical(other.east, east) || other.east == east));
}


@override
int get hashCode => Object.hash(runtimeType,south,west,north,east);

@override
String toString() {
  return 'MirkViewportBbox(south: $south, west: $west, north: $north, east: $east)';
}


}

/// @nodoc
abstract mixin class $MirkViewportBboxCopyWith<$Res>  {
  factory $MirkViewportBboxCopyWith(MirkViewportBbox value, $Res Function(MirkViewportBbox) _then) = _$MirkViewportBboxCopyWithImpl;
@useResult
$Res call({
 double south, double west, double north, double east
});




}
/// @nodoc
class _$MirkViewportBboxCopyWithImpl<$Res>
    implements $MirkViewportBboxCopyWith<$Res> {
  _$MirkViewportBboxCopyWithImpl(this._self, this._then);

  final MirkViewportBbox _self;
  final $Res Function(MirkViewportBbox) _then;

/// Create a copy of MirkViewportBbox
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? south = null,Object? west = null,Object? north = null,Object? east = null,}) {
  return _then(_self.copyWith(
south: null == south ? _self.south : south // ignore: cast_nullable_to_non_nullable
as double,west: null == west ? _self.west : west // ignore: cast_nullable_to_non_nullable
as double,north: null == north ? _self.north : north // ignore: cast_nullable_to_non_nullable
as double,east: null == east ? _self.east : east // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [MirkViewportBbox].
extension MirkViewportBboxPatterns on MirkViewportBbox {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MirkViewportBbox value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MirkViewportBbox() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MirkViewportBbox value)  $default,){
final _that = this;
switch (_that) {
case _MirkViewportBbox():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MirkViewportBbox value)?  $default,){
final _that = this;
switch (_that) {
case _MirkViewportBbox() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double south,  double west,  double north,  double east)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MirkViewportBbox() when $default != null:
return $default(_that.south,_that.west,_that.north,_that.east);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double south,  double west,  double north,  double east)  $default,) {final _that = this;
switch (_that) {
case _MirkViewportBbox():
return $default(_that.south,_that.west,_that.north,_that.east);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double south,  double west,  double north,  double east)?  $default,) {final _that = this;
switch (_that) {
case _MirkViewportBbox() when $default != null:
return $default(_that.south,_that.west,_that.north,_that.east);case _:
  return null;

}
}

}

/// @nodoc


class _MirkViewportBbox implements MirkViewportBbox {
   _MirkViewportBbox({required this.south, required this.west, required this.north, required this.east}): assert(south <= north, 'MirkViewportBbox: south must be <= north (got south=$south, north=$north)'),assert(west <= east || (west > 0 && east < 0), 'MirkViewportBbox: east < west only permitted on antimeridian wrap');
  

@override final  double south;
@override final  double west;
@override final  double north;
@override final  double east;

/// Create a copy of MirkViewportBbox
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MirkViewportBboxCopyWith<_MirkViewportBbox> get copyWith => __$MirkViewportBboxCopyWithImpl<_MirkViewportBbox>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MirkViewportBbox&&(identical(other.south, south) || other.south == south)&&(identical(other.west, west) || other.west == west)&&(identical(other.north, north) || other.north == north)&&(identical(other.east, east) || other.east == east));
}


@override
int get hashCode => Object.hash(runtimeType,south,west,north,east);

@override
String toString() {
  return 'MirkViewportBbox(south: $south, west: $west, north: $north, east: $east)';
}


}

/// @nodoc
abstract mixin class _$MirkViewportBboxCopyWith<$Res> implements $MirkViewportBboxCopyWith<$Res> {
  factory _$MirkViewportBboxCopyWith(_MirkViewportBbox value, $Res Function(_MirkViewportBbox) _then) = __$MirkViewportBboxCopyWithImpl;
@override @useResult
$Res call({
 double south, double west, double north, double east
});




}
/// @nodoc
class __$MirkViewportBboxCopyWithImpl<$Res>
    implements _$MirkViewportBboxCopyWith<$Res> {
  __$MirkViewportBboxCopyWithImpl(this._self, this._then);

  final _MirkViewportBbox _self;
  final $Res Function(_MirkViewportBbox) _then;

/// Create a copy of MirkViewportBbox
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? south = null,Object? west = null,Object? north = null,Object? east = null,}) {
  return _then(_MirkViewportBbox(
south: null == south ? _self.south : south // ignore: cast_nullable_to_non_nullable
as double,west: null == west ? _self.west : west // ignore: cast_nullable_to_non_nullable
as double,north: null == north ? _self.north : north // ignore: cast_nullable_to_non_nullable
as double,east: null == east ? _self.east : east // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on

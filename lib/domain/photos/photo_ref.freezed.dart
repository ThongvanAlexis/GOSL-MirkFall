// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PhotoRef {

@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson) PhotoRefId get id;@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) MarkerId get markerId; String get relativeBasename; int get widthPx; int get heightPx; int get fileSizeBytes; DateTime get createdAtUtc; int get createdAtOffsetMinutes;
/// Create a copy of PhotoRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoRefCopyWith<PhotoRef> get copyWith => _$PhotoRefCopyWithImpl<PhotoRef>(this as PhotoRef, _$identity);

  /// Serializes this PhotoRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoRef&&(identical(other.id, id) || other.id == id)&&(identical(other.markerId, markerId) || other.markerId == markerId)&&(identical(other.relativeBasename, relativeBasename) || other.relativeBasename == relativeBasename)&&(identical(other.widthPx, widthPx) || other.widthPx == widthPx)&&(identical(other.heightPx, heightPx) || other.heightPx == heightPx)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,markerId,relativeBasename,widthPx,heightPx,fileSizeBytes,createdAtUtc,createdAtOffsetMinutes);

@override
String toString() {
  return 'PhotoRef(id: $id, markerId: $markerId, relativeBasename: $relativeBasename, widthPx: $widthPx, heightPx: $heightPx, fileSizeBytes: $fileSizeBytes, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class $PhotoRefCopyWith<$Res>  {
  factory $PhotoRefCopyWith(PhotoRef value, $Res Function(PhotoRef) _then) = _$PhotoRefCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson) PhotoRefId id,@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) MarkerId markerId, String relativeBasename, int widthPx, int heightPx, int fileSizeBytes, DateTime createdAtUtc, int createdAtOffsetMinutes
});




}
/// @nodoc
class _$PhotoRefCopyWithImpl<$Res>
    implements $PhotoRefCopyWith<$Res> {
  _$PhotoRefCopyWithImpl(this._self, this._then);

  final PhotoRef _self;
  final $Res Function(PhotoRef) _then;

/// Create a copy of PhotoRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? markerId = null,Object? relativeBasename = null,Object? widthPx = null,Object? heightPx = null,Object? fileSizeBytes = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as PhotoRefId,markerId: null == markerId ? _self.markerId : markerId // ignore: cast_nullable_to_non_nullable
as MarkerId,relativeBasename: null == relativeBasename ? _self.relativeBasename : relativeBasename // ignore: cast_nullable_to_non_nullable
as String,widthPx: null == widthPx ? _self.widthPx : widthPx // ignore: cast_nullable_to_non_nullable
as int,heightPx: null == heightPx ? _self.heightPx : heightPx // ignore: cast_nullable_to_non_nullable
as int,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoRef].
extension PhotoRefPatterns on PhotoRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoRef value)  $default,){
final _that = this;
switch (_that) {
case _PhotoRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoRef value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson)  PhotoRefId id, @JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson)  MarkerId markerId,  String relativeBasename,  int widthPx,  int heightPx,  int fileSizeBytes,  DateTime createdAtUtc,  int createdAtOffsetMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoRef() when $default != null:
return $default(_that.id,_that.markerId,_that.relativeBasename,_that.widthPx,_that.heightPx,_that.fileSizeBytes,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson)  PhotoRefId id, @JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson)  MarkerId markerId,  String relativeBasename,  int widthPx,  int heightPx,  int fileSizeBytes,  DateTime createdAtUtc,  int createdAtOffsetMinutes)  $default,) {final _that = this;
switch (_that) {
case _PhotoRef():
return $default(_that.id,_that.markerId,_that.relativeBasename,_that.widthPx,_that.heightPx,_that.fileSizeBytes,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson)  PhotoRefId id, @JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson)  MarkerId markerId,  String relativeBasename,  int widthPx,  int heightPx,  int fileSizeBytes,  DateTime createdAtUtc,  int createdAtOffsetMinutes)?  $default,) {final _that = this;
switch (_that) {
case _PhotoRef() when $default != null:
return $default(_that.id,_that.markerId,_that.relativeBasename,_that.widthPx,_that.heightPx,_that.fileSizeBytes,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PhotoRef implements PhotoRef {
  const _PhotoRef({@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson) required this.id, @JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) required this.markerId, required this.relativeBasename, required this.widthPx, required this.heightPx, required this.fileSizeBytes, required this.createdAtUtc, required this.createdAtOffsetMinutes});
  factory _PhotoRef.fromJson(Map<String, dynamic> json) => _$PhotoRefFromJson(json);

@override@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson) final  PhotoRefId id;
@override@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) final  MarkerId markerId;
@override final  String relativeBasename;
@override final  int widthPx;
@override final  int heightPx;
@override final  int fileSizeBytes;
@override final  DateTime createdAtUtc;
@override final  int createdAtOffsetMinutes;

/// Create a copy of PhotoRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoRefCopyWith<_PhotoRef> get copyWith => __$PhotoRefCopyWithImpl<_PhotoRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhotoRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoRef&&(identical(other.id, id) || other.id == id)&&(identical(other.markerId, markerId) || other.markerId == markerId)&&(identical(other.relativeBasename, relativeBasename) || other.relativeBasename == relativeBasename)&&(identical(other.widthPx, widthPx) || other.widthPx == widthPx)&&(identical(other.heightPx, heightPx) || other.heightPx == heightPx)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,markerId,relativeBasename,widthPx,heightPx,fileSizeBytes,createdAtUtc,createdAtOffsetMinutes);

@override
String toString() {
  return 'PhotoRef(id: $id, markerId: $markerId, relativeBasename: $relativeBasename, widthPx: $widthPx, heightPx: $heightPx, fileSizeBytes: $fileSizeBytes, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$PhotoRefCopyWith<$Res> implements $PhotoRefCopyWith<$Res> {
  factory _$PhotoRefCopyWith(_PhotoRef value, $Res Function(_PhotoRef) _then) = __$PhotoRefCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: photoRefIdFromJson, toJson: photoRefIdToJson) PhotoRefId id,@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) MarkerId markerId, String relativeBasename, int widthPx, int heightPx, int fileSizeBytes, DateTime createdAtUtc, int createdAtOffsetMinutes
});




}
/// @nodoc
class __$PhotoRefCopyWithImpl<$Res>
    implements _$PhotoRefCopyWith<$Res> {
  __$PhotoRefCopyWithImpl(this._self, this._then);

  final _PhotoRef _self;
  final $Res Function(_PhotoRef) _then;

/// Create a copy of PhotoRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? markerId = null,Object? relativeBasename = null,Object? widthPx = null,Object? heightPx = null,Object? fileSizeBytes = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,}) {
  return _then(_PhotoRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as PhotoRefId,markerId: null == markerId ? _self.markerId : markerId // ignore: cast_nullable_to_non_nullable
as MarkerId,relativeBasename: null == relativeBasename ? _self.relativeBasename : relativeBasename // ignore: cast_nullable_to_non_nullable
as String,widthPx: null == widthPx ? _self.widthPx : widthPx // ignore: cast_nullable_to_non_nullable
as int,heightPx: null == heightPx ? _self.heightPx : heightPx // ignore: cast_nullable_to_non_nullable
as int,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

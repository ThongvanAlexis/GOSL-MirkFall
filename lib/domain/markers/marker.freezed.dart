// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marker.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Marker {

@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) MarkerId get id;@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId get sessionId;@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) CategoryId get categoryId; double get lat; double get lon; String get title; DateTime get createdAtUtc; int get createdAtOffsetMinutes; String? get notes; List<PhotoRef> get photos;
/// Create a copy of Marker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarkerCopyWith<Marker> get copyWith => _$MarkerCopyWithImpl<Marker>(this as Marker, _$identity);

  /// Serializes this Marker to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Marker&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lon, lon) || other.lon == lon)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.photos, photos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionId,categoryId,lat,lon,title,createdAtUtc,createdAtOffsetMinutes,notes,const DeepCollectionEquality().hash(photos));

@override
String toString() {
  return 'Marker(id: $id, sessionId: $sessionId, categoryId: $categoryId, lat: $lat, lon: $lon, title: $title, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes, notes: $notes, photos: $photos)';
}


}

/// @nodoc
abstract mixin class $MarkerCopyWith<$Res>  {
  factory $MarkerCopyWith(Marker value, $Res Function(Marker) _then) = _$MarkerCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) MarkerId id,@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId sessionId,@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) CategoryId categoryId, double lat, double lon, String title, DateTime createdAtUtc, int createdAtOffsetMinutes, String? notes, List<PhotoRef> photos
});




}
/// @nodoc
class _$MarkerCopyWithImpl<$Res>
    implements $MarkerCopyWith<$Res> {
  _$MarkerCopyWithImpl(this._self, this._then);

  final Marker _self;
  final $Res Function(Marker) _then;

/// Create a copy of Marker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionId = null,Object? categoryId = null,Object? lat = null,Object? lon = null,Object? title = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,Object? notes = freezed,Object? photos = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MarkerId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as CategoryId,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lon: null == lon ? _self.lon : lon // ignore: cast_nullable_to_non_nullable
as double,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<PhotoRef>,
  ));
}

}


/// Adds pattern-matching-related methods to [Marker].
extension MarkerPatterns on Marker {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Marker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Marker() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Marker value)  $default,){
final _that = this;
switch (_that) {
case _Marker():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Marker value)?  $default,){
final _that = this;
switch (_that) {
case _Marker() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson)  MarkerId id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId sessionId, @JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson)  CategoryId categoryId,  double lat,  double lon,  String title,  DateTime createdAtUtc,  int createdAtOffsetMinutes,  String? notes,  List<PhotoRef> photos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Marker() when $default != null:
return $default(_that.id,_that.sessionId,_that.categoryId,_that.lat,_that.lon,_that.title,_that.createdAtUtc,_that.createdAtOffsetMinutes,_that.notes,_that.photos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson)  MarkerId id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId sessionId, @JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson)  CategoryId categoryId,  double lat,  double lon,  String title,  DateTime createdAtUtc,  int createdAtOffsetMinutes,  String? notes,  List<PhotoRef> photos)  $default,) {final _that = this;
switch (_that) {
case _Marker():
return $default(_that.id,_that.sessionId,_that.categoryId,_that.lat,_that.lon,_that.title,_that.createdAtUtc,_that.createdAtOffsetMinutes,_that.notes,_that.photos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson)  MarkerId id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId sessionId, @JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson)  CategoryId categoryId,  double lat,  double lon,  String title,  DateTime createdAtUtc,  int createdAtOffsetMinutes,  String? notes,  List<PhotoRef> photos)?  $default,) {final _that = this;
switch (_that) {
case _Marker() when $default != null:
return $default(_that.id,_that.sessionId,_that.categoryId,_that.lat,_that.lon,_that.title,_that.createdAtUtc,_that.createdAtOffsetMinutes,_that.notes,_that.photos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Marker implements Marker {
   _Marker({@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) required this.id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) required this.sessionId, @JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) required this.categoryId, required this.lat, required this.lon, required this.title, required this.createdAtUtc, required this.createdAtOffsetMinutes, this.notes, final  List<PhotoRef> photos = const <PhotoRef>[]}): assert(title.trim().isNotEmpty, 'Marker.title must be non-empty'),_photos = photos;
  factory _Marker.fromJson(Map<String, dynamic> json) => _$MarkerFromJson(json);

@override@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) final  MarkerId id;
@override@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) final  SessionId sessionId;
@override@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) final  CategoryId categoryId;
@override final  double lat;
@override final  double lon;
@override final  String title;
@override final  DateTime createdAtUtc;
@override final  int createdAtOffsetMinutes;
@override final  String? notes;
 final  List<PhotoRef> _photos;
@override@JsonKey() List<PhotoRef> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}


/// Create a copy of Marker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarkerCopyWith<_Marker> get copyWith => __$MarkerCopyWithImpl<_Marker>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MarkerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Marker&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lon, lon) || other.lon == lon)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other._photos, _photos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionId,categoryId,lat,lon,title,createdAtUtc,createdAtOffsetMinutes,notes,const DeepCollectionEquality().hash(_photos));

@override
String toString() {
  return 'Marker(id: $id, sessionId: $sessionId, categoryId: $categoryId, lat: $lat, lon: $lon, title: $title, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes, notes: $notes, photos: $photos)';
}


}

/// @nodoc
abstract mixin class _$MarkerCopyWith<$Res> implements $MarkerCopyWith<$Res> {
  factory _$MarkerCopyWith(_Marker value, $Res Function(_Marker) _then) = __$MarkerCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: markerIdFromJson, toJson: markerIdToJson) MarkerId id,@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId sessionId,@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) CategoryId categoryId, double lat, double lon, String title, DateTime createdAtUtc, int createdAtOffsetMinutes, String? notes, List<PhotoRef> photos
});




}
/// @nodoc
class __$MarkerCopyWithImpl<$Res>
    implements _$MarkerCopyWith<$Res> {
  __$MarkerCopyWithImpl(this._self, this._then);

  final _Marker _self;
  final $Res Function(_Marker) _then;

/// Create a copy of Marker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionId = null,Object? categoryId = null,Object? lat = null,Object? lon = null,Object? title = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,Object? notes = freezed,Object? photos = null,}) {
  return _then(_Marker(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MarkerId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as CategoryId,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lon: null == lon ? _self.lon : lon // ignore: cast_nullable_to_non_nullable
as double,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<PhotoRef>,
  ));
}


}

// dart format on

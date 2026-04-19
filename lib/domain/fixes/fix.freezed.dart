// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fix.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Fix {

@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson) FixId get id;@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId get sessionId; DateTime get recordedAtUtc; int get recordedAtOffsetMinutes; double get latitude; double get longitude; double get accuracyMeters; double? get altitudeMeters; double? get speedMps; double? get headingDegrees;
/// Create a copy of Fix
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FixCopyWith<Fix> get copyWith => _$FixCopyWithImpl<Fix>(this as Fix, _$identity);

  /// Serializes this Fix to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Fix&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.recordedAtUtc, recordedAtUtc) || other.recordedAtUtc == recordedAtUtc)&&(identical(other.recordedAtOffsetMinutes, recordedAtOffsetMinutes) || other.recordedAtOffsetMinutes == recordedAtOffsetMinutes)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.accuracyMeters, accuracyMeters) || other.accuracyMeters == accuracyMeters)&&(identical(other.altitudeMeters, altitudeMeters) || other.altitudeMeters == altitudeMeters)&&(identical(other.speedMps, speedMps) || other.speedMps == speedMps)&&(identical(other.headingDegrees, headingDegrees) || other.headingDegrees == headingDegrees));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionId,recordedAtUtc,recordedAtOffsetMinutes,latitude,longitude,accuracyMeters,altitudeMeters,speedMps,headingDegrees);

@override
String toString() {
  return 'Fix(id: $id, sessionId: $sessionId, recordedAtUtc: $recordedAtUtc, recordedAtOffsetMinutes: $recordedAtOffsetMinutes, latitude: $latitude, longitude: $longitude, accuracyMeters: $accuracyMeters, altitudeMeters: $altitudeMeters, speedMps: $speedMps, headingDegrees: $headingDegrees)';
}


}

/// @nodoc
abstract mixin class $FixCopyWith<$Res>  {
  factory $FixCopyWith(Fix value, $Res Function(Fix) _then) = _$FixCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson) FixId id,@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId sessionId, DateTime recordedAtUtc, int recordedAtOffsetMinutes, double latitude, double longitude, double accuracyMeters, double? altitudeMeters, double? speedMps, double? headingDegrees
});




}
/// @nodoc
class _$FixCopyWithImpl<$Res>
    implements $FixCopyWith<$Res> {
  _$FixCopyWithImpl(this._self, this._then);

  final Fix _self;
  final $Res Function(Fix) _then;

/// Create a copy of Fix
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionId = null,Object? recordedAtUtc = null,Object? recordedAtOffsetMinutes = null,Object? latitude = null,Object? longitude = null,Object? accuracyMeters = null,Object? altitudeMeters = freezed,Object? speedMps = freezed,Object? headingDegrees = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as FixId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,recordedAtUtc: null == recordedAtUtc ? _self.recordedAtUtc : recordedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,recordedAtOffsetMinutes: null == recordedAtOffsetMinutes ? _self.recordedAtOffsetMinutes : recordedAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,accuracyMeters: null == accuracyMeters ? _self.accuracyMeters : accuracyMeters // ignore: cast_nullable_to_non_nullable
as double,altitudeMeters: freezed == altitudeMeters ? _self.altitudeMeters : altitudeMeters // ignore: cast_nullable_to_non_nullable
as double?,speedMps: freezed == speedMps ? _self.speedMps : speedMps // ignore: cast_nullable_to_non_nullable
as double?,headingDegrees: freezed == headingDegrees ? _self.headingDegrees : headingDegrees // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [Fix].
extension FixPatterns on Fix {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Fix value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Fix() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Fix value)  $default,){
final _that = this;
switch (_that) {
case _Fix():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Fix value)?  $default,){
final _that = this;
switch (_that) {
case _Fix() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson)  FixId id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId sessionId,  DateTime recordedAtUtc,  int recordedAtOffsetMinutes,  double latitude,  double longitude,  double accuracyMeters,  double? altitudeMeters,  double? speedMps,  double? headingDegrees)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Fix() when $default != null:
return $default(_that.id,_that.sessionId,_that.recordedAtUtc,_that.recordedAtOffsetMinutes,_that.latitude,_that.longitude,_that.accuracyMeters,_that.altitudeMeters,_that.speedMps,_that.headingDegrees);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson)  FixId id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId sessionId,  DateTime recordedAtUtc,  int recordedAtOffsetMinutes,  double latitude,  double longitude,  double accuracyMeters,  double? altitudeMeters,  double? speedMps,  double? headingDegrees)  $default,) {final _that = this;
switch (_that) {
case _Fix():
return $default(_that.id,_that.sessionId,_that.recordedAtUtc,_that.recordedAtOffsetMinutes,_that.latitude,_that.longitude,_that.accuracyMeters,_that.altitudeMeters,_that.speedMps,_that.headingDegrees);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson)  FixId id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)  SessionId sessionId,  DateTime recordedAtUtc,  int recordedAtOffsetMinutes,  double latitude,  double longitude,  double accuracyMeters,  double? altitudeMeters,  double? speedMps,  double? headingDegrees)?  $default,) {final _that = this;
switch (_that) {
case _Fix() when $default != null:
return $default(_that.id,_that.sessionId,_that.recordedAtUtc,_that.recordedAtOffsetMinutes,_that.latitude,_that.longitude,_that.accuracyMeters,_that.altitudeMeters,_that.speedMps,_that.headingDegrees);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Fix implements Fix {
   _Fix({@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson) required this.id, @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) required this.sessionId, required this.recordedAtUtc, required this.recordedAtOffsetMinutes, required this.latitude, required this.longitude, required this.accuracyMeters, this.altitudeMeters, this.speedMps, this.headingDegrees}): assert(latitude >= -90.0 && latitude <= 90.0, 'Fix.latitude out of [-90, 90]'),assert(longitude >= -180.0 && longitude <= 180.0, 'Fix.longitude out of [-180, 180]'),assert(accuracyMeters >= 0.0, 'Fix.accuracyMeters must be non-negative'),assert(recordedAtOffsetMinutes >= -720 && recordedAtOffsetMinutes <= 840, 'Fix.recordedAtOffsetMinutes out of range (UTC-12 to UTC+14)');
  factory _Fix.fromJson(Map<String, dynamic> json) => _$FixFromJson(json);

@override@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson) final  FixId id;
@override@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) final  SessionId sessionId;
@override final  DateTime recordedAtUtc;
@override final  int recordedAtOffsetMinutes;
@override final  double latitude;
@override final  double longitude;
@override final  double accuracyMeters;
@override final  double? altitudeMeters;
@override final  double? speedMps;
@override final  double? headingDegrees;

/// Create a copy of Fix
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FixCopyWith<_Fix> get copyWith => __$FixCopyWithImpl<_Fix>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FixToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Fix&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.recordedAtUtc, recordedAtUtc) || other.recordedAtUtc == recordedAtUtc)&&(identical(other.recordedAtOffsetMinutes, recordedAtOffsetMinutes) || other.recordedAtOffsetMinutes == recordedAtOffsetMinutes)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.accuracyMeters, accuracyMeters) || other.accuracyMeters == accuracyMeters)&&(identical(other.altitudeMeters, altitudeMeters) || other.altitudeMeters == altitudeMeters)&&(identical(other.speedMps, speedMps) || other.speedMps == speedMps)&&(identical(other.headingDegrees, headingDegrees) || other.headingDegrees == headingDegrees));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionId,recordedAtUtc,recordedAtOffsetMinutes,latitude,longitude,accuracyMeters,altitudeMeters,speedMps,headingDegrees);

@override
String toString() {
  return 'Fix(id: $id, sessionId: $sessionId, recordedAtUtc: $recordedAtUtc, recordedAtOffsetMinutes: $recordedAtOffsetMinutes, latitude: $latitude, longitude: $longitude, accuracyMeters: $accuracyMeters, altitudeMeters: $altitudeMeters, speedMps: $speedMps, headingDegrees: $headingDegrees)';
}


}

/// @nodoc
abstract mixin class _$FixCopyWith<$Res> implements $FixCopyWith<$Res> {
  factory _$FixCopyWith(_Fix value, $Res Function(_Fix) _then) = __$FixCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson) FixId id,@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) SessionId sessionId, DateTime recordedAtUtc, int recordedAtOffsetMinutes, double latitude, double longitude, double accuracyMeters, double? altitudeMeters, double? speedMps, double? headingDegrees
});




}
/// @nodoc
class __$FixCopyWithImpl<$Res>
    implements _$FixCopyWith<$Res> {
  __$FixCopyWithImpl(this._self, this._then);

  final _Fix _self;
  final $Res Function(_Fix) _then;

/// Create a copy of Fix
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionId = null,Object? recordedAtUtc = null,Object? recordedAtOffsetMinutes = null,Object? latitude = null,Object? longitude = null,Object? accuracyMeters = null,Object? altitudeMeters = freezed,Object? speedMps = freezed,Object? headingDegrees = freezed,}) {
  return _then(_Fix(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as FixId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,recordedAtUtc: null == recordedAtUtc ? _self.recordedAtUtc : recordedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,recordedAtOffsetMinutes: null == recordedAtOffsetMinutes ? _self.recordedAtOffsetMinutes : recordedAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,accuracyMeters: null == accuracyMeters ? _self.accuracyMeters : accuracyMeters // ignore: cast_nullable_to_non_nullable
as double,altitudeMeters: freezed == altitudeMeters ? _self.altitudeMeters : altitudeMeters // ignore: cast_nullable_to_non_nullable
as double?,speedMps: freezed == speedMps ? _self.speedMps : speedMps // ignore: cast_nullable_to_non_nullable
as double?,headingDegrees: freezed == headingDegrees ? _self.headingDegrees : headingDegrees // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on

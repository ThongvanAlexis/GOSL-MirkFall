// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Envelope {

 int get schemaVersion; String get type;@JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson) Map<String, Object?> get payload;
/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnvelopeCopyWith<Envelope> get copyWith => _$EnvelopeCopyWithImpl<Envelope>(this as Envelope, _$identity);

  /// Serializes this Envelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Envelope&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.payload, payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,type,const DeepCollectionEquality().hash(payload));

@override
String toString() {
  return 'Envelope(schemaVersion: $schemaVersion, type: $type, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $EnvelopeCopyWith<$Res>  {
  factory $EnvelopeCopyWith(Envelope value, $Res Function(Envelope) _then) = _$EnvelopeCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String type,@JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson) Map<String, Object?> payload
});




}
/// @nodoc
class _$EnvelopeCopyWithImpl<$Res>
    implements $EnvelopeCopyWith<$Res> {
  _$EnvelopeCopyWithImpl(this._self, this._then);

  final Envelope _self;
  final $Res Function(Envelope) _then;

/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? type = null,Object? payload = null,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [Envelope].
extension EnvelopePatterns on Envelope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Envelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Envelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Envelope value)  $default,){
final _that = this;
switch (_that) {
case _Envelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Envelope value)?  $default,){
final _that = this;
switch (_that) {
case _Envelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String type, @JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson)  Map<String, Object?> payload)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Envelope() when $default != null:
return $default(_that.schemaVersion,_that.type,_that.payload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String type, @JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson)  Map<String, Object?> payload)  $default,) {final _that = this;
switch (_that) {
case _Envelope():
return $default(_that.schemaVersion,_that.type,_that.payload);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String type, @JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson)  Map<String, Object?> payload)?  $default,) {final _that = this;
switch (_that) {
case _Envelope() when $default != null:
return $default(_that.schemaVersion,_that.type,_that.payload);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Envelope implements Envelope {
  const _Envelope({required this.schemaVersion, required this.type, @JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson) required final  Map<String, Object?> payload}): _payload = payload;
  factory _Envelope.fromJson(Map<String, dynamic> json) => _$EnvelopeFromJson(json);

@override final  int schemaVersion;
@override final  String type;
 final  Map<String, Object?> _payload;
@override@JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson) Map<String, Object?> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}


/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnvelopeCopyWith<_Envelope> get copyWith => __$EnvelopeCopyWithImpl<_Envelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Envelope&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._payload, _payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,type,const DeepCollectionEquality().hash(_payload));

@override
String toString() {
  return 'Envelope(schemaVersion: $schemaVersion, type: $type, payload: $payload)';
}


}

/// @nodoc
abstract mixin class _$EnvelopeCopyWith<$Res> implements $EnvelopeCopyWith<$Res> {
  factory _$EnvelopeCopyWith(_Envelope value, $Res Function(_Envelope) _then) = __$EnvelopeCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String type,@JsonKey(fromJson: _payloadFromJson, toJson: _payloadToJson) Map<String, Object?> payload
});




}
/// @nodoc
class __$EnvelopeCopyWithImpl<$Res>
    implements _$EnvelopeCopyWith<$Res> {
  __$EnvelopeCopyWithImpl(this._self, this._then);

  final _Envelope _self;
  final $Res Function(_Envelope) _then;

/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? type = null,Object? payload = null,}) {
  return _then(_Envelope(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on

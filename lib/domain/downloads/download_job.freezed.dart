// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DownloadJob {

@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode get alpha3; CountryEntry get entry; DateTime get enqueuedAtUtc; bool get userPausedFlag;
/// Create a copy of DownloadJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadJobCopyWith<DownloadJob> get copyWith => _$DownloadJobCopyWithImpl<DownloadJob>(this as DownloadJob, _$identity);

  /// Serializes this DownloadJob to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadJob&&(identical(other.alpha3, alpha3) || other.alpha3 == alpha3)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.enqueuedAtUtc, enqueuedAtUtc) || other.enqueuedAtUtc == enqueuedAtUtc)&&(identical(other.userPausedFlag, userPausedFlag) || other.userPausedFlag == userPausedFlag));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alpha3,entry,enqueuedAtUtc,userPausedFlag);

@override
String toString() {
  return 'DownloadJob(alpha3: $alpha3, entry: $entry, enqueuedAtUtc: $enqueuedAtUtc, userPausedFlag: $userPausedFlag)';
}


}

/// @nodoc
abstract mixin class $DownloadJobCopyWith<$Res>  {
  factory $DownloadJobCopyWith(DownloadJob value, $Res Function(DownloadJob) _then) = _$DownloadJobCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode alpha3, CountryEntry entry, DateTime enqueuedAtUtc, bool userPausedFlag
});


$CountryEntryCopyWith<$Res> get entry;

}
/// @nodoc
class _$DownloadJobCopyWithImpl<$Res>
    implements $DownloadJobCopyWith<$Res> {
  _$DownloadJobCopyWithImpl(this._self, this._then);

  final DownloadJob _self;
  final $Res Function(DownloadJob) _then;

/// Create a copy of DownloadJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? alpha3 = null,Object? entry = null,Object? enqueuedAtUtc = null,Object? userPausedFlag = null,}) {
  return _then(_self.copyWith(
alpha3: null == alpha3 ? _self.alpha3 : alpha3 // ignore: cast_nullable_to_non_nullable
as CountryCode,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as CountryEntry,enqueuedAtUtc: null == enqueuedAtUtc ? _self.enqueuedAtUtc : enqueuedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,userPausedFlag: null == userPausedFlag ? _self.userPausedFlag : userPausedFlag // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of DownloadJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CountryEntryCopyWith<$Res> get entry {
  
  return $CountryEntryCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}
}


/// Adds pattern-matching-related methods to [DownloadJob].
extension DownloadJobPatterns on DownloadJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadJob value)  $default,){
final _that = this;
switch (_that) {
case _DownloadJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadJob value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadJob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  CountryEntry entry,  DateTime enqueuedAtUtc,  bool userPausedFlag)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadJob() when $default != null:
return $default(_that.alpha3,_that.entry,_that.enqueuedAtUtc,_that.userPausedFlag);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  CountryEntry entry,  DateTime enqueuedAtUtc,  bool userPausedFlag)  $default,) {final _that = this;
switch (_that) {
case _DownloadJob():
return $default(_that.alpha3,_that.entry,_that.enqueuedAtUtc,_that.userPausedFlag);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  CountryEntry entry,  DateTime enqueuedAtUtc,  bool userPausedFlag)?  $default,) {final _that = this;
switch (_that) {
case _DownloadJob() when $default != null:
return $default(_that.alpha3,_that.entry,_that.enqueuedAtUtc,_that.userPausedFlag);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DownloadJob implements DownloadJob {
   _DownloadJob({@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) required this.alpha3, required this.entry, required this.enqueuedAtUtc, this.userPausedFlag = false});
  factory _DownloadJob.fromJson(Map<String, dynamic> json) => _$DownloadJobFromJson(json);

@override@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) final  CountryCode alpha3;
@override final  CountryEntry entry;
@override final  DateTime enqueuedAtUtc;
@override@JsonKey() final  bool userPausedFlag;

/// Create a copy of DownloadJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadJobCopyWith<_DownloadJob> get copyWith => __$DownloadJobCopyWithImpl<_DownloadJob>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DownloadJobToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadJob&&(identical(other.alpha3, alpha3) || other.alpha3 == alpha3)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.enqueuedAtUtc, enqueuedAtUtc) || other.enqueuedAtUtc == enqueuedAtUtc)&&(identical(other.userPausedFlag, userPausedFlag) || other.userPausedFlag == userPausedFlag));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alpha3,entry,enqueuedAtUtc,userPausedFlag);

@override
String toString() {
  return 'DownloadJob(alpha3: $alpha3, entry: $entry, enqueuedAtUtc: $enqueuedAtUtc, userPausedFlag: $userPausedFlag)';
}


}

/// @nodoc
abstract mixin class _$DownloadJobCopyWith<$Res> implements $DownloadJobCopyWith<$Res> {
  factory _$DownloadJobCopyWith(_DownloadJob value, $Res Function(_DownloadJob) _then) = __$DownloadJobCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode alpha3, CountryEntry entry, DateTime enqueuedAtUtc, bool userPausedFlag
});


@override $CountryEntryCopyWith<$Res> get entry;

}
/// @nodoc
class __$DownloadJobCopyWithImpl<$Res>
    implements _$DownloadJobCopyWith<$Res> {
  __$DownloadJobCopyWithImpl(this._self, this._then);

  final _DownloadJob _self;
  final $Res Function(_DownloadJob) _then;

/// Create a copy of DownloadJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? alpha3 = null,Object? entry = null,Object? enqueuedAtUtc = null,Object? userPausedFlag = null,}) {
  return _then(_DownloadJob(
alpha3: null == alpha3 ? _self.alpha3 : alpha3 // ignore: cast_nullable_to_non_nullable
as CountryCode,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as CountryEntry,enqueuedAtUtc: null == enqueuedAtUtc ? _self.enqueuedAtUtc : enqueuedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,userPausedFlag: null == userPausedFlag ? _self.userPausedFlag : userPausedFlag // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of DownloadJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CountryEntryCopyWith<$Res> get entry {
  
  return $CountryEntryCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}
}

// dart format on

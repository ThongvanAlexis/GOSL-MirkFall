// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'installed_country.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InstalledCountry {

@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode get alpha3; DateTime get installedAtUtc; int get fileSize; String get pmtilesVersion; String get sha256; String get filePath;
/// Create a copy of InstalledCountry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstalledCountryCopyWith<InstalledCountry> get copyWith => _$InstalledCountryCopyWithImpl<InstalledCountry>(this as InstalledCountry, _$identity);

  /// Serializes this InstalledCountry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstalledCountry&&(identical(other.alpha3, alpha3) || other.alpha3 == alpha3)&&(identical(other.installedAtUtc, installedAtUtc) || other.installedAtUtc == installedAtUtc)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.pmtilesVersion, pmtilesVersion) || other.pmtilesVersion == pmtilesVersion)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.filePath, filePath) || other.filePath == filePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alpha3,installedAtUtc,fileSize,pmtilesVersion,sha256,filePath);

@override
String toString() {
  return 'InstalledCountry(alpha3: $alpha3, installedAtUtc: $installedAtUtc, fileSize: $fileSize, pmtilesVersion: $pmtilesVersion, sha256: $sha256, filePath: $filePath)';
}


}

/// @nodoc
abstract mixin class $InstalledCountryCopyWith<$Res>  {
  factory $InstalledCountryCopyWith(InstalledCountry value, $Res Function(InstalledCountry) _then) = _$InstalledCountryCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode alpha3, DateTime installedAtUtc, int fileSize, String pmtilesVersion, String sha256, String filePath
});




}
/// @nodoc
class _$InstalledCountryCopyWithImpl<$Res>
    implements $InstalledCountryCopyWith<$Res> {
  _$InstalledCountryCopyWithImpl(this._self, this._then);

  final InstalledCountry _self;
  final $Res Function(InstalledCountry) _then;

/// Create a copy of InstalledCountry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? alpha3 = null,Object? installedAtUtc = null,Object? fileSize = null,Object? pmtilesVersion = null,Object? sha256 = null,Object? filePath = null,}) {
  return _then(_self.copyWith(
alpha3: null == alpha3 ? _self.alpha3 : alpha3 // ignore: cast_nullable_to_non_nullable
as CountryCode,installedAtUtc: null == installedAtUtc ? _self.installedAtUtc : installedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,pmtilesVersion: null == pmtilesVersion ? _self.pmtilesVersion : pmtilesVersion // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InstalledCountry].
extension InstalledCountryPatterns on InstalledCountry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstalledCountry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstalledCountry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstalledCountry value)  $default,){
final _that = this;
switch (_that) {
case _InstalledCountry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstalledCountry value)?  $default,){
final _that = this;
switch (_that) {
case _InstalledCountry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  DateTime installedAtUtc,  int fileSize,  String pmtilesVersion,  String sha256,  String filePath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstalledCountry() when $default != null:
return $default(_that.alpha3,_that.installedAtUtc,_that.fileSize,_that.pmtilesVersion,_that.sha256,_that.filePath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  DateTime installedAtUtc,  int fileSize,  String pmtilesVersion,  String sha256,  String filePath)  $default,) {final _that = this;
switch (_that) {
case _InstalledCountry():
return $default(_that.alpha3,_that.installedAtUtc,_that.fileSize,_that.pmtilesVersion,_that.sha256,_that.filePath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  DateTime installedAtUtc,  int fileSize,  String pmtilesVersion,  String sha256,  String filePath)?  $default,) {final _that = this;
switch (_that) {
case _InstalledCountry() when $default != null:
return $default(_that.alpha3,_that.installedAtUtc,_that.fileSize,_that.pmtilesVersion,_that.sha256,_that.filePath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InstalledCountry implements InstalledCountry {
   _InstalledCountry({@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) required this.alpha3, required this.installedAtUtc, required this.fileSize, required this.pmtilesVersion, required this.sha256, required this.filePath}): assert(fileSize > 0, 'InstalledCountry.fileSize must be positive'),assert(sha256.length == 64, 'InstalledCountry.sha256 must be 64 hex chars'),assert(pmtilesVersion.length > 0, 'InstalledCountry.pmtilesVersion must be non-empty'),assert(filePath.length > 0, 'InstalledCountry.filePath must be non-empty');
  factory _InstalledCountry.fromJson(Map<String, dynamic> json) => _$InstalledCountryFromJson(json);

@override@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) final  CountryCode alpha3;
@override final  DateTime installedAtUtc;
@override final  int fileSize;
@override final  String pmtilesVersion;
@override final  String sha256;
@override final  String filePath;

/// Create a copy of InstalledCountry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstalledCountryCopyWith<_InstalledCountry> get copyWith => __$InstalledCountryCopyWithImpl<_InstalledCountry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InstalledCountryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstalledCountry&&(identical(other.alpha3, alpha3) || other.alpha3 == alpha3)&&(identical(other.installedAtUtc, installedAtUtc) || other.installedAtUtc == installedAtUtc)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.pmtilesVersion, pmtilesVersion) || other.pmtilesVersion == pmtilesVersion)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.filePath, filePath) || other.filePath == filePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alpha3,installedAtUtc,fileSize,pmtilesVersion,sha256,filePath);

@override
String toString() {
  return 'InstalledCountry(alpha3: $alpha3, installedAtUtc: $installedAtUtc, fileSize: $fileSize, pmtilesVersion: $pmtilesVersion, sha256: $sha256, filePath: $filePath)';
}


}

/// @nodoc
abstract mixin class _$InstalledCountryCopyWith<$Res> implements $InstalledCountryCopyWith<$Res> {
  factory _$InstalledCountryCopyWith(_InstalledCountry value, $Res Function(_InstalledCountry) _then) = __$InstalledCountryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode alpha3, DateTime installedAtUtc, int fileSize, String pmtilesVersion, String sha256, String filePath
});




}
/// @nodoc
class __$InstalledCountryCopyWithImpl<$Res>
    implements _$InstalledCountryCopyWith<$Res> {
  __$InstalledCountryCopyWithImpl(this._self, this._then);

  final _InstalledCountry _self;
  final $Res Function(_InstalledCountry) _then;

/// Create a copy of InstalledCountry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? alpha3 = null,Object? installedAtUtc = null,Object? fileSize = null,Object? pmtilesVersion = null,Object? sha256 = null,Object? filePath = null,}) {
  return _then(_InstalledCountry(
alpha3: null == alpha3 ? _self.alpha3 : alpha3 // ignore: cast_nullable_to_non_nullable
as CountryCode,installedAtUtc: null == installedAtUtc ? _self.installedAtUtc : installedAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,pmtilesVersion: null == pmtilesVersion ? _self.pmtilesVersion : pmtilesVersion // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

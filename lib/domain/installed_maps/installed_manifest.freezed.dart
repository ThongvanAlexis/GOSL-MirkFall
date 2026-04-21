// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'installed_manifest.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InstalledManifest {

 int get schemaVersion; String get catalogVersion; Map<String, InstalledCountry> get installed;
/// Create a copy of InstalledManifest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstalledManifestCopyWith<InstalledManifest> get copyWith => _$InstalledManifestCopyWithImpl<InstalledManifest>(this as InstalledManifest, _$identity);

  /// Serializes this InstalledManifest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstalledManifest&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.catalogVersion, catalogVersion) || other.catalogVersion == catalogVersion)&&const DeepCollectionEquality().equals(other.installed, installed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,catalogVersion,const DeepCollectionEquality().hash(installed));

@override
String toString() {
  return 'InstalledManifest(schemaVersion: $schemaVersion, catalogVersion: $catalogVersion, installed: $installed)';
}


}

/// @nodoc
abstract mixin class $InstalledManifestCopyWith<$Res>  {
  factory $InstalledManifestCopyWith(InstalledManifest value, $Res Function(InstalledManifest) _then) = _$InstalledManifestCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String catalogVersion, Map<String, InstalledCountry> installed
});




}
/// @nodoc
class _$InstalledManifestCopyWithImpl<$Res>
    implements $InstalledManifestCopyWith<$Res> {
  _$InstalledManifestCopyWithImpl(this._self, this._then);

  final InstalledManifest _self;
  final $Res Function(InstalledManifest) _then;

/// Create a copy of InstalledManifest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? catalogVersion = null,Object? installed = null,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,catalogVersion: null == catalogVersion ? _self.catalogVersion : catalogVersion // ignore: cast_nullable_to_non_nullable
as String,installed: null == installed ? _self.installed : installed // ignore: cast_nullable_to_non_nullable
as Map<String, InstalledCountry>,
  ));
}

}


/// Adds pattern-matching-related methods to [InstalledManifest].
extension InstalledManifestPatterns on InstalledManifest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstalledManifest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstalledManifest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstalledManifest value)  $default,){
final _that = this;
switch (_that) {
case _InstalledManifest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstalledManifest value)?  $default,){
final _that = this;
switch (_that) {
case _InstalledManifest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String catalogVersion,  Map<String, InstalledCountry> installed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstalledManifest() when $default != null:
return $default(_that.schemaVersion,_that.catalogVersion,_that.installed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String catalogVersion,  Map<String, InstalledCountry> installed)  $default,) {final _that = this;
switch (_that) {
case _InstalledManifest():
return $default(_that.schemaVersion,_that.catalogVersion,_that.installed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String catalogVersion,  Map<String, InstalledCountry> installed)?  $default,) {final _that = this;
switch (_that) {
case _InstalledManifest() when $default != null:
return $default(_that.schemaVersion,_that.catalogVersion,_that.installed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InstalledManifest implements InstalledManifest {
   _InstalledManifest({required this.schemaVersion, required this.catalogVersion, required final  Map<String, InstalledCountry> installed}): assert(schemaVersion == 1, 'InstalledManifest.schemaVersion must be 1 in Phase 07'),_installed = installed;
  factory _InstalledManifest.fromJson(Map<String, dynamic> json) => _$InstalledManifestFromJson(json);

@override final  int schemaVersion;
@override final  String catalogVersion;
 final  Map<String, InstalledCountry> _installed;
@override Map<String, InstalledCountry> get installed {
  if (_installed is EqualUnmodifiableMapView) return _installed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_installed);
}


/// Create a copy of InstalledManifest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstalledManifestCopyWith<_InstalledManifest> get copyWith => __$InstalledManifestCopyWithImpl<_InstalledManifest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InstalledManifestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstalledManifest&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.catalogVersion, catalogVersion) || other.catalogVersion == catalogVersion)&&const DeepCollectionEquality().equals(other._installed, _installed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,catalogVersion,const DeepCollectionEquality().hash(_installed));

@override
String toString() {
  return 'InstalledManifest(schemaVersion: $schemaVersion, catalogVersion: $catalogVersion, installed: $installed)';
}


}

/// @nodoc
abstract mixin class _$InstalledManifestCopyWith<$Res> implements $InstalledManifestCopyWith<$Res> {
  factory _$InstalledManifestCopyWith(_InstalledManifest value, $Res Function(_InstalledManifest) _then) = __$InstalledManifestCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String catalogVersion, Map<String, InstalledCountry> installed
});




}
/// @nodoc
class __$InstalledManifestCopyWithImpl<$Res>
    implements _$InstalledManifestCopyWith<$Res> {
  __$InstalledManifestCopyWithImpl(this._self, this._then);

  final _InstalledManifest _self;
  final $Res Function(_InstalledManifest) _then;

/// Create a copy of InstalledManifest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? catalogVersion = null,Object? installed = null,}) {
  return _then(_InstalledManifest(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,catalogVersion: null == catalogVersion ? _self.catalogVersion : catalogVersion // ignore: cast_nullable_to_non_nullable
as String,installed: null == installed ? _self._installed : installed // ignore: cast_nullable_to_non_nullable
as Map<String, InstalledCountry>,
  ));
}


}

// dart format on

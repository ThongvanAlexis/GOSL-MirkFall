// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mirk_style_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
MirkStyleConfig _$MirkStyleConfigFromJson(
  Map<String, dynamic> json
) {
        switch (json['rendererType']) {
                  case 'atmospheric':
          return AtmosphericConfig.fromJson(
            json
          );
                case 'shader':
          return ShaderConfig.fromJson(
            json
          );
        
          default:
            return UnknownConfig.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$MirkStyleConfig {



  /// Serializes this MirkStyleConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MirkStyleConfig);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MirkStyleConfig()';
}


}

/// @nodoc
class $MirkStyleConfigCopyWith<$Res>  {
$MirkStyleConfigCopyWith(MirkStyleConfig _, $Res Function(MirkStyleConfig) __);
}


/// Adds pattern-matching-related methods to [MirkStyleConfig].
extension MirkStyleConfigPatterns on MirkStyleConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AtmosphericConfig value)?  atmospheric,TResult Function( ShaderConfig value)?  shader,TResult Function( UnknownConfig value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that);case ShaderConfig() when shader != null:
return shader(_that);case UnknownConfig() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AtmosphericConfig value)  atmospheric,required TResult Function( ShaderConfig value)  shader,required TResult Function( UnknownConfig value)  unknown,}){
final _that = this;
switch (_that) {
case AtmosphericConfig():
return atmospheric(_that);case ShaderConfig():
return shader(_that);case UnknownConfig():
return unknown(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AtmosphericConfig value)?  atmospheric,TResult? Function( ShaderConfig value)?  shader,TResult? Function( UnknownConfig value)?  unknown,}){
final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that);case ShaderConfig() when shader != null:
return shader(_that);case UnknownConfig() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int baseColorArgb,  double noiseScale)?  atmospheric,TResult Function( String shaderAssetPath)?  shader,TResult Function(@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap)  Map<String, Object?> raw)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that.baseColorArgb,_that.noiseScale);case ShaderConfig() when shader != null:
return shader(_that.shaderAssetPath);case UnknownConfig() when unknown != null:
return unknown(_that.raw);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int baseColorArgb,  double noiseScale)  atmospheric,required TResult Function( String shaderAssetPath)  shader,required TResult Function(@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap)  Map<String, Object?> raw)  unknown,}) {final _that = this;
switch (_that) {
case AtmosphericConfig():
return atmospheric(_that.baseColorArgb,_that.noiseScale);case ShaderConfig():
return shader(_that.shaderAssetPath);case UnknownConfig():
return unknown(_that.raw);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int baseColorArgb,  double noiseScale)?  atmospheric,TResult? Function( String shaderAssetPath)?  shader,TResult? Function(@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap)  Map<String, Object?> raw)?  unknown,}) {final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that.baseColorArgb,_that.noiseScale);case ShaderConfig() when shader != null:
return shader(_that.shaderAssetPath);case UnknownConfig() when unknown != null:
return unknown(_that.raw);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class AtmosphericConfig implements MirkStyleConfig {
  const AtmosphericConfig({this.baseColorArgb = 0xFF000000, this.noiseScale = 0.5, final  String? $type}): $type = $type ?? 'atmospheric';
  factory AtmosphericConfig.fromJson(Map<String, dynamic> json) => _$AtmosphericConfigFromJson(json);

@JsonKey() final  int baseColorArgb;
@JsonKey() final  double noiseScale;

@JsonKey(name: 'rendererType')
final String $type;


/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AtmosphericConfigCopyWith<AtmosphericConfig> get copyWith => _$AtmosphericConfigCopyWithImpl<AtmosphericConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AtmosphericConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AtmosphericConfig&&(identical(other.baseColorArgb, baseColorArgb) || other.baseColorArgb == baseColorArgb)&&(identical(other.noiseScale, noiseScale) || other.noiseScale == noiseScale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseColorArgb,noiseScale);

@override
String toString() {
  return 'MirkStyleConfig.atmospheric(baseColorArgb: $baseColorArgb, noiseScale: $noiseScale)';
}


}

/// @nodoc
abstract mixin class $AtmosphericConfigCopyWith<$Res> implements $MirkStyleConfigCopyWith<$Res> {
  factory $AtmosphericConfigCopyWith(AtmosphericConfig value, $Res Function(AtmosphericConfig) _then) = _$AtmosphericConfigCopyWithImpl;
@useResult
$Res call({
 int baseColorArgb, double noiseScale
});




}
/// @nodoc
class _$AtmosphericConfigCopyWithImpl<$Res>
    implements $AtmosphericConfigCopyWith<$Res> {
  _$AtmosphericConfigCopyWithImpl(this._self, this._then);

  final AtmosphericConfig _self;
  final $Res Function(AtmosphericConfig) _then;

/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? baseColorArgb = null,Object? noiseScale = null,}) {
  return _then(AtmosphericConfig(
baseColorArgb: null == baseColorArgb ? _self.baseColorArgb : baseColorArgb // ignore: cast_nullable_to_non_nullable
as int,noiseScale: null == noiseScale ? _self.noiseScale : noiseScale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ShaderConfig implements MirkStyleConfig {
  const ShaderConfig({required this.shaderAssetPath, final  String? $type}): $type = $type ?? 'shader';
  factory ShaderConfig.fromJson(Map<String, dynamic> json) => _$ShaderConfigFromJson(json);

 final  String shaderAssetPath;

@JsonKey(name: 'rendererType')
final String $type;


/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShaderConfigCopyWith<ShaderConfig> get copyWith => _$ShaderConfigCopyWithImpl<ShaderConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShaderConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShaderConfig&&(identical(other.shaderAssetPath, shaderAssetPath) || other.shaderAssetPath == shaderAssetPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,shaderAssetPath);

@override
String toString() {
  return 'MirkStyleConfig.shader(shaderAssetPath: $shaderAssetPath)';
}


}

/// @nodoc
abstract mixin class $ShaderConfigCopyWith<$Res> implements $MirkStyleConfigCopyWith<$Res> {
  factory $ShaderConfigCopyWith(ShaderConfig value, $Res Function(ShaderConfig) _then) = _$ShaderConfigCopyWithImpl;
@useResult
$Res call({
 String shaderAssetPath
});




}
/// @nodoc
class _$ShaderConfigCopyWithImpl<$Res>
    implements $ShaderConfigCopyWith<$Res> {
  _$ShaderConfigCopyWithImpl(this._self, this._then);

  final ShaderConfig _self;
  final $Res Function(ShaderConfig) _then;

/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? shaderAssetPath = null,}) {
  return _then(ShaderConfig(
shaderAssetPath: null == shaderAssetPath ? _self.shaderAssetPath : shaderAssetPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UnknownConfig implements MirkStyleConfig {
  const UnknownConfig({@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap) required final  Map<String, Object?> raw, final  String? $type}): _raw = raw,$type = $type ?? 'unknown';
  factory UnknownConfig.fromJson(Map<String, dynamic> json) => _$UnknownConfigFromJson(json);

 final  Map<String, Object?> _raw;
@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap) Map<String, Object?> get raw {
  if (_raw is EqualUnmodifiableMapView) return _raw;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_raw);
}


@JsonKey(name: 'rendererType')
final String $type;


/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnknownConfigCopyWith<UnknownConfig> get copyWith => _$UnknownConfigCopyWithImpl<UnknownConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnknownConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownConfig&&const DeepCollectionEquality().equals(other._raw, _raw));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_raw));

@override
String toString() {
  return 'MirkStyleConfig.unknown(raw: $raw)';
}


}

/// @nodoc
abstract mixin class $UnknownConfigCopyWith<$Res> implements $MirkStyleConfigCopyWith<$Res> {
  factory $UnknownConfigCopyWith(UnknownConfig value, $Res Function(UnknownConfig) _then) = _$UnknownConfigCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap) Map<String, Object?> raw
});




}
/// @nodoc
class _$UnknownConfigCopyWithImpl<$Res>
    implements $UnknownConfigCopyWith<$Res> {
  _$UnknownConfigCopyWithImpl(this._self, this._then);

  final UnknownConfig _self;
  final $Res Function(UnknownConfig) _then;

/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? raw = null,}) {
  return _then(UnknownConfig(
raw: null == raw ? _self._raw : raw // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on

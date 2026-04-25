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
                case 'solid':
          return SolidConfig.fromJson(
            json
          );
                case 'candlelight':
          return CandlelightConfig.fromJson(
            json
          );
                case 'heavenly':
          return HeavenlyCloudsConfig.fromJson(
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AtmosphericConfig value)?  atmospheric,TResult Function( SolidConfig value)?  solid,TResult Function( CandlelightConfig value)?  candlelight,TResult Function( HeavenlyCloudsConfig value)?  heavenly,TResult Function( ShaderConfig value)?  shader,TResult Function( UnknownConfig value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that);case SolidConfig() when solid != null:
return solid(_that);case CandlelightConfig() when candlelight != null:
return candlelight(_that);case HeavenlyCloudsConfig() when heavenly != null:
return heavenly(_that);case ShaderConfig() when shader != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AtmosphericConfig value)  atmospheric,required TResult Function( SolidConfig value)  solid,required TResult Function( CandlelightConfig value)  candlelight,required TResult Function( HeavenlyCloudsConfig value)  heavenly,required TResult Function( ShaderConfig value)  shader,required TResult Function( UnknownConfig value)  unknown,}){
final _that = this;
switch (_that) {
case AtmosphericConfig():
return atmospheric(_that);case SolidConfig():
return solid(_that);case CandlelightConfig():
return candlelight(_that);case HeavenlyCloudsConfig():
return heavenly(_that);case ShaderConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AtmosphericConfig value)?  atmospheric,TResult? Function( SolidConfig value)?  solid,TResult? Function( CandlelightConfig value)?  candlelight,TResult? Function( HeavenlyCloudsConfig value)?  heavenly,TResult? Function( ShaderConfig value)?  shader,TResult? Function( UnknownConfig value)?  unknown,}){
final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that);case SolidConfig() when solid != null:
return solid(_that);case CandlelightConfig() when candlelight != null:
return candlelight(_that);case HeavenlyCloudsConfig() when heavenly != null:
return heavenly(_that);case ShaderConfig() when shader != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int baseColorArgb,  int? secondaryColorArgb,  double noiseScale,  double noiseSpeed,  double driftDirectionDeg,  double densityBaselineAlpha,  double featherRadiusFraction,  double edgeSoftness)?  atmospheric,TResult Function( int colorArgb,  double baselineAlpha)?  solid,TResult Function( int centerColorArgb,  int peripheryColorArgb,  double noiseScale,  double noiseSpeed,  double baselineAlpha,  double featherRadiusFraction)?  candlelight,TResult Function( int colorArgb,  double noiseScale,  double noiseSpeed,  double driftDirectionDeg,  double baselineAlpha)?  heavenly,TResult Function( String shaderAssetPath)?  shader,TResult Function(@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap)  Map<String, Object?> raw)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that.baseColorArgb,_that.secondaryColorArgb,_that.noiseScale,_that.noiseSpeed,_that.driftDirectionDeg,_that.densityBaselineAlpha,_that.featherRadiusFraction,_that.edgeSoftness);case SolidConfig() when solid != null:
return solid(_that.colorArgb,_that.baselineAlpha);case CandlelightConfig() when candlelight != null:
return candlelight(_that.centerColorArgb,_that.peripheryColorArgb,_that.noiseScale,_that.noiseSpeed,_that.baselineAlpha,_that.featherRadiusFraction);case HeavenlyCloudsConfig() when heavenly != null:
return heavenly(_that.colorArgb,_that.noiseScale,_that.noiseSpeed,_that.driftDirectionDeg,_that.baselineAlpha);case ShaderConfig() when shader != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int baseColorArgb,  int? secondaryColorArgb,  double noiseScale,  double noiseSpeed,  double driftDirectionDeg,  double densityBaselineAlpha,  double featherRadiusFraction,  double edgeSoftness)  atmospheric,required TResult Function( int colorArgb,  double baselineAlpha)  solid,required TResult Function( int centerColorArgb,  int peripheryColorArgb,  double noiseScale,  double noiseSpeed,  double baselineAlpha,  double featherRadiusFraction)  candlelight,required TResult Function( int colorArgb,  double noiseScale,  double noiseSpeed,  double driftDirectionDeg,  double baselineAlpha)  heavenly,required TResult Function( String shaderAssetPath)  shader,required TResult Function(@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap)  Map<String, Object?> raw)  unknown,}) {final _that = this;
switch (_that) {
case AtmosphericConfig():
return atmospheric(_that.baseColorArgb,_that.secondaryColorArgb,_that.noiseScale,_that.noiseSpeed,_that.driftDirectionDeg,_that.densityBaselineAlpha,_that.featherRadiusFraction,_that.edgeSoftness);case SolidConfig():
return solid(_that.colorArgb,_that.baselineAlpha);case CandlelightConfig():
return candlelight(_that.centerColorArgb,_that.peripheryColorArgb,_that.noiseScale,_that.noiseSpeed,_that.baselineAlpha,_that.featherRadiusFraction);case HeavenlyCloudsConfig():
return heavenly(_that.colorArgb,_that.noiseScale,_that.noiseSpeed,_that.driftDirectionDeg,_that.baselineAlpha);case ShaderConfig():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int baseColorArgb,  int? secondaryColorArgb,  double noiseScale,  double noiseSpeed,  double driftDirectionDeg,  double densityBaselineAlpha,  double featherRadiusFraction,  double edgeSoftness)?  atmospheric,TResult? Function( int colorArgb,  double baselineAlpha)?  solid,TResult? Function( int centerColorArgb,  int peripheryColorArgb,  double noiseScale,  double noiseSpeed,  double baselineAlpha,  double featherRadiusFraction)?  candlelight,TResult? Function( int colorArgb,  double noiseScale,  double noiseSpeed,  double driftDirectionDeg,  double baselineAlpha)?  heavenly,TResult? Function( String shaderAssetPath)?  shader,TResult? Function(@JsonKey(fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true, readValue: _readWholeMap)  Map<String, Object?> raw)?  unknown,}) {final _that = this;
switch (_that) {
case AtmosphericConfig() when atmospheric != null:
return atmospheric(_that.baseColorArgb,_that.secondaryColorArgb,_that.noiseScale,_that.noiseSpeed,_that.driftDirectionDeg,_that.densityBaselineAlpha,_that.featherRadiusFraction,_that.edgeSoftness);case SolidConfig() when solid != null:
return solid(_that.colorArgb,_that.baselineAlpha);case CandlelightConfig() when candlelight != null:
return candlelight(_that.centerColorArgb,_that.peripheryColorArgb,_that.noiseScale,_that.noiseSpeed,_that.baselineAlpha,_that.featherRadiusFraction);case HeavenlyCloudsConfig() when heavenly != null:
return heavenly(_that.colorArgb,_that.noiseScale,_that.noiseSpeed,_that.driftDirectionDeg,_that.baselineAlpha);case ShaderConfig() when shader != null:
return shader(_that.shaderAssetPath);case UnknownConfig() when unknown != null:
return unknown(_that.raw);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class AtmosphericConfig implements MirkStyleConfig {
  const AtmosphericConfig({this.baseColorArgb = 0xFF000000, this.secondaryColorArgb, this.noiseScale = 0.5, this.noiseSpeed = 0.05, this.driftDirectionDeg = 0.0, this.densityBaselineAlpha = 0.99, this.featherRadiusFraction = 0.1, this.edgeSoftness = 0.5, final  String? $type}): $type = $type ?? 'atmospheric';
  factory AtmosphericConfig.fromJson(Map<String, dynamic> json) => _$AtmosphericConfigFromJson(json);

@JsonKey() final  int baseColorArgb;
 final  int? secondaryColorArgb;
@JsonKey() final  double noiseScale;
@JsonKey() final  double noiseSpeed;
@JsonKey() final  double driftDirectionDeg;
@JsonKey() final  double densityBaselineAlpha;
@JsonKey() final  double featherRadiusFraction;
@JsonKey() final  double edgeSoftness;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AtmosphericConfig&&(identical(other.baseColorArgb, baseColorArgb) || other.baseColorArgb == baseColorArgb)&&(identical(other.secondaryColorArgb, secondaryColorArgb) || other.secondaryColorArgb == secondaryColorArgb)&&(identical(other.noiseScale, noiseScale) || other.noiseScale == noiseScale)&&(identical(other.noiseSpeed, noiseSpeed) || other.noiseSpeed == noiseSpeed)&&(identical(other.driftDirectionDeg, driftDirectionDeg) || other.driftDirectionDeg == driftDirectionDeg)&&(identical(other.densityBaselineAlpha, densityBaselineAlpha) || other.densityBaselineAlpha == densityBaselineAlpha)&&(identical(other.featherRadiusFraction, featherRadiusFraction) || other.featherRadiusFraction == featherRadiusFraction)&&(identical(other.edgeSoftness, edgeSoftness) || other.edgeSoftness == edgeSoftness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseColorArgb,secondaryColorArgb,noiseScale,noiseSpeed,driftDirectionDeg,densityBaselineAlpha,featherRadiusFraction,edgeSoftness);

@override
String toString() {
  return 'MirkStyleConfig.atmospheric(baseColorArgb: $baseColorArgb, secondaryColorArgb: $secondaryColorArgb, noiseScale: $noiseScale, noiseSpeed: $noiseSpeed, driftDirectionDeg: $driftDirectionDeg, densityBaselineAlpha: $densityBaselineAlpha, featherRadiusFraction: $featherRadiusFraction, edgeSoftness: $edgeSoftness)';
}


}

/// @nodoc
abstract mixin class $AtmosphericConfigCopyWith<$Res> implements $MirkStyleConfigCopyWith<$Res> {
  factory $AtmosphericConfigCopyWith(AtmosphericConfig value, $Res Function(AtmosphericConfig) _then) = _$AtmosphericConfigCopyWithImpl;
@useResult
$Res call({
 int baseColorArgb, int? secondaryColorArgb, double noiseScale, double noiseSpeed, double driftDirectionDeg, double densityBaselineAlpha, double featherRadiusFraction, double edgeSoftness
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
@pragma('vm:prefer-inline') $Res call({Object? baseColorArgb = null,Object? secondaryColorArgb = freezed,Object? noiseScale = null,Object? noiseSpeed = null,Object? driftDirectionDeg = null,Object? densityBaselineAlpha = null,Object? featherRadiusFraction = null,Object? edgeSoftness = null,}) {
  return _then(AtmosphericConfig(
baseColorArgb: null == baseColorArgb ? _self.baseColorArgb : baseColorArgb // ignore: cast_nullable_to_non_nullable
as int,secondaryColorArgb: freezed == secondaryColorArgb ? _self.secondaryColorArgb : secondaryColorArgb // ignore: cast_nullable_to_non_nullable
as int?,noiseScale: null == noiseScale ? _self.noiseScale : noiseScale // ignore: cast_nullable_to_non_nullable
as double,noiseSpeed: null == noiseSpeed ? _self.noiseSpeed : noiseSpeed // ignore: cast_nullable_to_non_nullable
as double,driftDirectionDeg: null == driftDirectionDeg ? _self.driftDirectionDeg : driftDirectionDeg // ignore: cast_nullable_to_non_nullable
as double,densityBaselineAlpha: null == densityBaselineAlpha ? _self.densityBaselineAlpha : densityBaselineAlpha // ignore: cast_nullable_to_non_nullable
as double,featherRadiusFraction: null == featherRadiusFraction ? _self.featherRadiusFraction : featherRadiusFraction // ignore: cast_nullable_to_non_nullable
as double,edgeSoftness: null == edgeSoftness ? _self.edgeSoftness : edgeSoftness // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SolidConfig implements MirkStyleConfig {
  const SolidConfig({this.colorArgb = 0xFF1A1A1A, this.baselineAlpha = 0.99, final  String? $type}): $type = $type ?? 'solid';
  factory SolidConfig.fromJson(Map<String, dynamic> json) => _$SolidConfigFromJson(json);

@JsonKey() final  int colorArgb;
@JsonKey() final  double baselineAlpha;

@JsonKey(name: 'rendererType')
final String $type;


/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SolidConfigCopyWith<SolidConfig> get copyWith => _$SolidConfigCopyWithImpl<SolidConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SolidConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolidConfig&&(identical(other.colorArgb, colorArgb) || other.colorArgb == colorArgb)&&(identical(other.baselineAlpha, baselineAlpha) || other.baselineAlpha == baselineAlpha));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,colorArgb,baselineAlpha);

@override
String toString() {
  return 'MirkStyleConfig.solid(colorArgb: $colorArgb, baselineAlpha: $baselineAlpha)';
}


}

/// @nodoc
abstract mixin class $SolidConfigCopyWith<$Res> implements $MirkStyleConfigCopyWith<$Res> {
  factory $SolidConfigCopyWith(SolidConfig value, $Res Function(SolidConfig) _then) = _$SolidConfigCopyWithImpl;
@useResult
$Res call({
 int colorArgb, double baselineAlpha
});




}
/// @nodoc
class _$SolidConfigCopyWithImpl<$Res>
    implements $SolidConfigCopyWith<$Res> {
  _$SolidConfigCopyWithImpl(this._self, this._then);

  final SolidConfig _self;
  final $Res Function(SolidConfig) _then;

/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? colorArgb = null,Object? baselineAlpha = null,}) {
  return _then(SolidConfig(
colorArgb: null == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int,baselineAlpha: null == baselineAlpha ? _self.baselineAlpha : baselineAlpha // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CandlelightConfig implements MirkStyleConfig {
  const CandlelightConfig({this.centerColorArgb = 0xFFFF8F6A, this.peripheryColorArgb = 0xFFC2542E, this.noiseScale = 0.8, this.noiseSpeed = 0.1, this.baselineAlpha = 0.85, this.featherRadiusFraction = 0.1, final  String? $type}): $type = $type ?? 'candlelight';
  factory CandlelightConfig.fromJson(Map<String, dynamic> json) => _$CandlelightConfigFromJson(json);

@JsonKey() final  int centerColorArgb;
@JsonKey() final  int peripheryColorArgb;
@JsonKey() final  double noiseScale;
@JsonKey() final  double noiseSpeed;
@JsonKey() final  double baselineAlpha;
@JsonKey() final  double featherRadiusFraction;

@JsonKey(name: 'rendererType')
final String $type;


/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CandlelightConfigCopyWith<CandlelightConfig> get copyWith => _$CandlelightConfigCopyWithImpl<CandlelightConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CandlelightConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CandlelightConfig&&(identical(other.centerColorArgb, centerColorArgb) || other.centerColorArgb == centerColorArgb)&&(identical(other.peripheryColorArgb, peripheryColorArgb) || other.peripheryColorArgb == peripheryColorArgb)&&(identical(other.noiseScale, noiseScale) || other.noiseScale == noiseScale)&&(identical(other.noiseSpeed, noiseSpeed) || other.noiseSpeed == noiseSpeed)&&(identical(other.baselineAlpha, baselineAlpha) || other.baselineAlpha == baselineAlpha)&&(identical(other.featherRadiusFraction, featherRadiusFraction) || other.featherRadiusFraction == featherRadiusFraction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,centerColorArgb,peripheryColorArgb,noiseScale,noiseSpeed,baselineAlpha,featherRadiusFraction);

@override
String toString() {
  return 'MirkStyleConfig.candlelight(centerColorArgb: $centerColorArgb, peripheryColorArgb: $peripheryColorArgb, noiseScale: $noiseScale, noiseSpeed: $noiseSpeed, baselineAlpha: $baselineAlpha, featherRadiusFraction: $featherRadiusFraction)';
}


}

/// @nodoc
abstract mixin class $CandlelightConfigCopyWith<$Res> implements $MirkStyleConfigCopyWith<$Res> {
  factory $CandlelightConfigCopyWith(CandlelightConfig value, $Res Function(CandlelightConfig) _then) = _$CandlelightConfigCopyWithImpl;
@useResult
$Res call({
 int centerColorArgb, int peripheryColorArgb, double noiseScale, double noiseSpeed, double baselineAlpha, double featherRadiusFraction
});




}
/// @nodoc
class _$CandlelightConfigCopyWithImpl<$Res>
    implements $CandlelightConfigCopyWith<$Res> {
  _$CandlelightConfigCopyWithImpl(this._self, this._then);

  final CandlelightConfig _self;
  final $Res Function(CandlelightConfig) _then;

/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? centerColorArgb = null,Object? peripheryColorArgb = null,Object? noiseScale = null,Object? noiseSpeed = null,Object? baselineAlpha = null,Object? featherRadiusFraction = null,}) {
  return _then(CandlelightConfig(
centerColorArgb: null == centerColorArgb ? _self.centerColorArgb : centerColorArgb // ignore: cast_nullable_to_non_nullable
as int,peripheryColorArgb: null == peripheryColorArgb ? _self.peripheryColorArgb : peripheryColorArgb // ignore: cast_nullable_to_non_nullable
as int,noiseScale: null == noiseScale ? _self.noiseScale : noiseScale // ignore: cast_nullable_to_non_nullable
as double,noiseSpeed: null == noiseSpeed ? _self.noiseSpeed : noiseSpeed // ignore: cast_nullable_to_non_nullable
as double,baselineAlpha: null == baselineAlpha ? _self.baselineAlpha : baselineAlpha // ignore: cast_nullable_to_non_nullable
as double,featherRadiusFraction: null == featherRadiusFraction ? _self.featherRadiusFraction : featherRadiusFraction // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class HeavenlyCloudsConfig implements MirkStyleConfig {
  const HeavenlyCloudsConfig({this.colorArgb = 0xFFE8E8EE, this.noiseScale = 0.3, this.noiseSpeed = 0.08, this.driftDirectionDeg = 45.0, this.baselineAlpha = 0.80, final  String? $type}): $type = $type ?? 'heavenly';
  factory HeavenlyCloudsConfig.fromJson(Map<String, dynamic> json) => _$HeavenlyCloudsConfigFromJson(json);

@JsonKey() final  int colorArgb;
@JsonKey() final  double noiseScale;
@JsonKey() final  double noiseSpeed;
@JsonKey() final  double driftDirectionDeg;
@JsonKey() final  double baselineAlpha;

@JsonKey(name: 'rendererType')
final String $type;


/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeavenlyCloudsConfigCopyWith<HeavenlyCloudsConfig> get copyWith => _$HeavenlyCloudsConfigCopyWithImpl<HeavenlyCloudsConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HeavenlyCloudsConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeavenlyCloudsConfig&&(identical(other.colorArgb, colorArgb) || other.colorArgb == colorArgb)&&(identical(other.noiseScale, noiseScale) || other.noiseScale == noiseScale)&&(identical(other.noiseSpeed, noiseSpeed) || other.noiseSpeed == noiseSpeed)&&(identical(other.driftDirectionDeg, driftDirectionDeg) || other.driftDirectionDeg == driftDirectionDeg)&&(identical(other.baselineAlpha, baselineAlpha) || other.baselineAlpha == baselineAlpha));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,colorArgb,noiseScale,noiseSpeed,driftDirectionDeg,baselineAlpha);

@override
String toString() {
  return 'MirkStyleConfig.heavenly(colorArgb: $colorArgb, noiseScale: $noiseScale, noiseSpeed: $noiseSpeed, driftDirectionDeg: $driftDirectionDeg, baselineAlpha: $baselineAlpha)';
}


}

/// @nodoc
abstract mixin class $HeavenlyCloudsConfigCopyWith<$Res> implements $MirkStyleConfigCopyWith<$Res> {
  factory $HeavenlyCloudsConfigCopyWith(HeavenlyCloudsConfig value, $Res Function(HeavenlyCloudsConfig) _then) = _$HeavenlyCloudsConfigCopyWithImpl;
@useResult
$Res call({
 int colorArgb, double noiseScale, double noiseSpeed, double driftDirectionDeg, double baselineAlpha
});




}
/// @nodoc
class _$HeavenlyCloudsConfigCopyWithImpl<$Res>
    implements $HeavenlyCloudsConfigCopyWith<$Res> {
  _$HeavenlyCloudsConfigCopyWithImpl(this._self, this._then);

  final HeavenlyCloudsConfig _self;
  final $Res Function(HeavenlyCloudsConfig) _then;

/// Create a copy of MirkStyleConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? colorArgb = null,Object? noiseScale = null,Object? noiseSpeed = null,Object? driftDirectionDeg = null,Object? baselineAlpha = null,}) {
  return _then(HeavenlyCloudsConfig(
colorArgb: null == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int,noiseScale: null == noiseScale ? _self.noiseScale : noiseScale // ignore: cast_nullable_to_non_nullable
as double,noiseSpeed: null == noiseSpeed ? _self.noiseSpeed : noiseSpeed // ignore: cast_nullable_to_non_nullable
as double,driftDirectionDeg: null == driftDirectionDeg ? _self.driftDirectionDeg : driftDirectionDeg // ignore: cast_nullable_to_non_nullable
as double,baselineAlpha: null == baselineAlpha ? _self.baselineAlpha : baselineAlpha // ignore: cast_nullable_to_non_nullable
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

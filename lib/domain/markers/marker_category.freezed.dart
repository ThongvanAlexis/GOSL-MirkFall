// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marker_category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MarkerCategory {

@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) CategoryId get id; String get displayName; String get iconName; DateTime get createdAtUtc; int get createdAtOffsetMinutes;
/// Create a copy of MarkerCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarkerCategoryCopyWith<MarkerCategory> get copyWith => _$MarkerCategoryCopyWithImpl<MarkerCategory>(this as MarkerCategory, _$identity);

  /// Serializes this MarkerCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MarkerCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.iconName, iconName) || other.iconName == iconName)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,iconName,createdAtUtc,createdAtOffsetMinutes);

@override
String toString() {
  return 'MarkerCategory(id: $id, displayName: $displayName, iconName: $iconName, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class $MarkerCategoryCopyWith<$Res>  {
  factory $MarkerCategoryCopyWith(MarkerCategory value, $Res Function(MarkerCategory) _then) = _$MarkerCategoryCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) CategoryId id, String displayName, String iconName, DateTime createdAtUtc, int createdAtOffsetMinutes
});




}
/// @nodoc
class _$MarkerCategoryCopyWithImpl<$Res>
    implements $MarkerCategoryCopyWith<$Res> {
  _$MarkerCategoryCopyWithImpl(this._self, this._then);

  final MarkerCategory _self;
  final $Res Function(MarkerCategory) _then;

/// Create a copy of MarkerCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? iconName = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as CategoryId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,iconName: null == iconName ? _self.iconName : iconName // ignore: cast_nullable_to_non_nullable
as String,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MarkerCategory].
extension MarkerCategoryPatterns on MarkerCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MarkerCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MarkerCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MarkerCategory value)  $default,){
final _that = this;
switch (_that) {
case _MarkerCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MarkerCategory value)?  $default,){
final _that = this;
switch (_that) {
case _MarkerCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson)  CategoryId id,  String displayName,  String iconName,  DateTime createdAtUtc,  int createdAtOffsetMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MarkerCategory() when $default != null:
return $default(_that.id,_that.displayName,_that.iconName,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson)  CategoryId id,  String displayName,  String iconName,  DateTime createdAtUtc,  int createdAtOffsetMinutes)  $default,) {final _that = this;
switch (_that) {
case _MarkerCategory():
return $default(_that.id,_that.displayName,_that.iconName,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson)  CategoryId id,  String displayName,  String iconName,  DateTime createdAtUtc,  int createdAtOffsetMinutes)?  $default,) {final _that = this;
switch (_that) {
case _MarkerCategory() when $default != null:
return $default(_that.id,_that.displayName,_that.iconName,_that.createdAtUtc,_that.createdAtOffsetMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MarkerCategory implements MarkerCategory {
   _MarkerCategory({@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) required this.id, required this.displayName, required this.iconName, required this.createdAtUtc, required this.createdAtOffsetMinutes}): assert(displayName.trim().isNotEmpty, 'MarkerCategory.displayName must be non-empty');
  factory _MarkerCategory.fromJson(Map<String, dynamic> json) => _$MarkerCategoryFromJson(json);

@override@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) final  CategoryId id;
@override final  String displayName;
@override final  String iconName;
@override final  DateTime createdAtUtc;
@override final  int createdAtOffsetMinutes;

/// Create a copy of MarkerCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarkerCategoryCopyWith<_MarkerCategory> get copyWith => __$MarkerCategoryCopyWithImpl<_MarkerCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MarkerCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MarkerCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.iconName, iconName) || other.iconName == iconName)&&(identical(other.createdAtUtc, createdAtUtc) || other.createdAtUtc == createdAtUtc)&&(identical(other.createdAtOffsetMinutes, createdAtOffsetMinutes) || other.createdAtOffsetMinutes == createdAtOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,iconName,createdAtUtc,createdAtOffsetMinutes);

@override
String toString() {
  return 'MarkerCategory(id: $id, displayName: $displayName, iconName: $iconName, createdAtUtc: $createdAtUtc, createdAtOffsetMinutes: $createdAtOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$MarkerCategoryCopyWith<$Res> implements $MarkerCategoryCopyWith<$Res> {
  factory _$MarkerCategoryCopyWith(_MarkerCategory value, $Res Function(_MarkerCategory) _then) = __$MarkerCategoryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: categoryIdFromJson, toJson: categoryIdToJson) CategoryId id, String displayName, String iconName, DateTime createdAtUtc, int createdAtOffsetMinutes
});




}
/// @nodoc
class __$MarkerCategoryCopyWithImpl<$Res>
    implements _$MarkerCategoryCopyWith<$Res> {
  __$MarkerCategoryCopyWithImpl(this._self, this._then);

  final _MarkerCategory _self;
  final $Res Function(_MarkerCategory) _then;

/// Create a copy of MarkerCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? iconName = null,Object? createdAtUtc = null,Object? createdAtOffsetMinutes = null,}) {
  return _then(_MarkerCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as CategoryId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,iconName: null == iconName ? _self.iconName : iconName // ignore: cast_nullable_to_non_nullable
as String,createdAtUtc: null == createdAtUtc ? _self.createdAtUtc : createdAtUtc // ignore: cast_nullable_to_non_nullable
as DateTime,createdAtOffsetMinutes: null == createdAtOffsetMinutes ? _self.createdAtOffsetMinutes : createdAtOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

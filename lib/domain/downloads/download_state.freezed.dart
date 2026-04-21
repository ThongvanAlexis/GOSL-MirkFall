// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DownloadProgress {

 int get bytesDownloaded; int get totalBytes; int get currentPartIndex; int get totalParts;
/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadProgressCopyWith<DownloadProgress> get copyWith => _$DownloadProgressCopyWithImpl<DownloadProgress>(this as DownloadProgress, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadProgress&&(identical(other.bytesDownloaded, bytesDownloaded) || other.bytesDownloaded == bytesDownloaded)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.currentPartIndex, currentPartIndex) || other.currentPartIndex == currentPartIndex)&&(identical(other.totalParts, totalParts) || other.totalParts == totalParts));
}


@override
int get hashCode => Object.hash(runtimeType,bytesDownloaded,totalBytes,currentPartIndex,totalParts);

@override
String toString() {
  return 'DownloadProgress(bytesDownloaded: $bytesDownloaded, totalBytes: $totalBytes, currentPartIndex: $currentPartIndex, totalParts: $totalParts)';
}


}

/// @nodoc
abstract mixin class $DownloadProgressCopyWith<$Res>  {
  factory $DownloadProgressCopyWith(DownloadProgress value, $Res Function(DownloadProgress) _then) = _$DownloadProgressCopyWithImpl;
@useResult
$Res call({
 int bytesDownloaded, int totalBytes, int currentPartIndex, int totalParts
});




}
/// @nodoc
class _$DownloadProgressCopyWithImpl<$Res>
    implements $DownloadProgressCopyWith<$Res> {
  _$DownloadProgressCopyWithImpl(this._self, this._then);

  final DownloadProgress _self;
  final $Res Function(DownloadProgress) _then;

/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bytesDownloaded = null,Object? totalBytes = null,Object? currentPartIndex = null,Object? totalParts = null,}) {
  return _then(_self.copyWith(
bytesDownloaded: null == bytesDownloaded ? _self.bytesDownloaded : bytesDownloaded // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,currentPartIndex: null == currentPartIndex ? _self.currentPartIndex : currentPartIndex // ignore: cast_nullable_to_non_nullable
as int,totalParts: null == totalParts ? _self.totalParts : totalParts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DownloadProgress].
extension DownloadProgressPatterns on DownloadProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadProgress value)  $default,){
final _that = this;
switch (_that) {
case _DownloadProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadProgress value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int bytesDownloaded,  int totalBytes,  int currentPartIndex,  int totalParts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadProgress() when $default != null:
return $default(_that.bytesDownloaded,_that.totalBytes,_that.currentPartIndex,_that.totalParts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int bytesDownloaded,  int totalBytes,  int currentPartIndex,  int totalParts)  $default,) {final _that = this;
switch (_that) {
case _DownloadProgress():
return $default(_that.bytesDownloaded,_that.totalBytes,_that.currentPartIndex,_that.totalParts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int bytesDownloaded,  int totalBytes,  int currentPartIndex,  int totalParts)?  $default,) {final _that = this;
switch (_that) {
case _DownloadProgress() when $default != null:
return $default(_that.bytesDownloaded,_that.totalBytes,_that.currentPartIndex,_that.totalParts);case _:
  return null;

}
}

}

/// @nodoc


class _DownloadProgress implements DownloadProgress {
   _DownloadProgress({required this.bytesDownloaded, required this.totalBytes, required this.currentPartIndex, required this.totalParts}): assert(bytesDownloaded >= 0, 'DownloadProgress.bytesDownloaded must be >= 0'),assert(totalBytes > 0, 'DownloadProgress.totalBytes must be > 0'),assert(bytesDownloaded <= totalBytes, 'DownloadProgress.bytesDownloaded must be <= totalBytes'),assert(currentPartIndex >= 0, 'DownloadProgress.currentPartIndex must be >= 0'),assert(totalParts > 0, 'DownloadProgress.totalParts must be > 0'),assert(currentPartIndex < totalParts, 'DownloadProgress.currentPartIndex must be < totalParts');
  

@override final  int bytesDownloaded;
@override final  int totalBytes;
@override final  int currentPartIndex;
@override final  int totalParts;

/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadProgressCopyWith<_DownloadProgress> get copyWith => __$DownloadProgressCopyWithImpl<_DownloadProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadProgress&&(identical(other.bytesDownloaded, bytesDownloaded) || other.bytesDownloaded == bytesDownloaded)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.currentPartIndex, currentPartIndex) || other.currentPartIndex == currentPartIndex)&&(identical(other.totalParts, totalParts) || other.totalParts == totalParts));
}


@override
int get hashCode => Object.hash(runtimeType,bytesDownloaded,totalBytes,currentPartIndex,totalParts);

@override
String toString() {
  return 'DownloadProgress(bytesDownloaded: $bytesDownloaded, totalBytes: $totalBytes, currentPartIndex: $currentPartIndex, totalParts: $totalParts)';
}


}

/// @nodoc
abstract mixin class _$DownloadProgressCopyWith<$Res> implements $DownloadProgressCopyWith<$Res> {
  factory _$DownloadProgressCopyWith(_DownloadProgress value, $Res Function(_DownloadProgress) _then) = __$DownloadProgressCopyWithImpl;
@override @useResult
$Res call({
 int bytesDownloaded, int totalBytes, int currentPartIndex, int totalParts
});




}
/// @nodoc
class __$DownloadProgressCopyWithImpl<$Res>
    implements _$DownloadProgressCopyWith<$Res> {
  __$DownloadProgressCopyWithImpl(this._self, this._then);

  final _DownloadProgress _self;
  final $Res Function(_DownloadProgress) _then;

/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bytesDownloaded = null,Object? totalBytes = null,Object? currentPartIndex = null,Object? totalParts = null,}) {
  return _then(_DownloadProgress(
bytesDownloaded: null == bytesDownloaded ? _self.bytesDownloaded : bytesDownloaded // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,currentPartIndex: null == currentPartIndex ? _self.currentPartIndex : currentPartIndex // ignore: cast_nullable_to_non_nullable
as int,totalParts: null == totalParts ? _self.totalParts : totalParts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

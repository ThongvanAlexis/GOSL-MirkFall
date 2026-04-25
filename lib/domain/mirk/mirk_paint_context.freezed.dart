// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mirk_paint_context.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MirkPaintContext {

 double get zoomLevel; double get pixelRatio; Duration get sessionElapsed; MirkViewportBbox get viewportBbox; List<VisibleMirkTile> get visibleTiles; Fix? get currentFix;
/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MirkPaintContextCopyWith<MirkPaintContext> get copyWith => _$MirkPaintContextCopyWithImpl<MirkPaintContext>(this as MirkPaintContext, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MirkPaintContext&&(identical(other.zoomLevel, zoomLevel) || other.zoomLevel == zoomLevel)&&(identical(other.pixelRatio, pixelRatio) || other.pixelRatio == pixelRatio)&&(identical(other.sessionElapsed, sessionElapsed) || other.sessionElapsed == sessionElapsed)&&(identical(other.viewportBbox, viewportBbox) || other.viewportBbox == viewportBbox)&&const DeepCollectionEquality().equals(other.visibleTiles, visibleTiles)&&(identical(other.currentFix, currentFix) || other.currentFix == currentFix));
}


@override
int get hashCode => Object.hash(runtimeType,zoomLevel,pixelRatio,sessionElapsed,viewportBbox,const DeepCollectionEquality().hash(visibleTiles),currentFix);

@override
String toString() {
  return 'MirkPaintContext(zoomLevel: $zoomLevel, pixelRatio: $pixelRatio, sessionElapsed: $sessionElapsed, viewportBbox: $viewportBbox, visibleTiles: $visibleTiles, currentFix: $currentFix)';
}


}

/// @nodoc
abstract mixin class $MirkPaintContextCopyWith<$Res>  {
  factory $MirkPaintContextCopyWith(MirkPaintContext value, $Res Function(MirkPaintContext) _then) = _$MirkPaintContextCopyWithImpl;
@useResult
$Res call({
 double zoomLevel, double pixelRatio, Duration sessionElapsed, MirkViewportBbox viewportBbox, List<VisibleMirkTile> visibleTiles, Fix? currentFix
});


$MirkViewportBboxCopyWith<$Res> get viewportBbox;$FixCopyWith<$Res>? get currentFix;

}
/// @nodoc
class _$MirkPaintContextCopyWithImpl<$Res>
    implements $MirkPaintContextCopyWith<$Res> {
  _$MirkPaintContextCopyWithImpl(this._self, this._then);

  final MirkPaintContext _self;
  final $Res Function(MirkPaintContext) _then;

/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? zoomLevel = null,Object? pixelRatio = null,Object? sessionElapsed = null,Object? viewportBbox = null,Object? visibleTiles = null,Object? currentFix = freezed,}) {
  return _then(_self.copyWith(
zoomLevel: null == zoomLevel ? _self.zoomLevel : zoomLevel // ignore: cast_nullable_to_non_nullable
as double,pixelRatio: null == pixelRatio ? _self.pixelRatio : pixelRatio // ignore: cast_nullable_to_non_nullable
as double,sessionElapsed: null == sessionElapsed ? _self.sessionElapsed : sessionElapsed // ignore: cast_nullable_to_non_nullable
as Duration,viewportBbox: null == viewportBbox ? _self.viewportBbox : viewportBbox // ignore: cast_nullable_to_non_nullable
as MirkViewportBbox,visibleTiles: null == visibleTiles ? _self.visibleTiles : visibleTiles // ignore: cast_nullable_to_non_nullable
as List<VisibleMirkTile>,currentFix: freezed == currentFix ? _self.currentFix : currentFix // ignore: cast_nullable_to_non_nullable
as Fix?,
  ));
}
/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MirkViewportBboxCopyWith<$Res> get viewportBbox {
  
  return $MirkViewportBboxCopyWith<$Res>(_self.viewportBbox, (value) {
    return _then(_self.copyWith(viewportBbox: value));
  });
}/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FixCopyWith<$Res>? get currentFix {
    if (_self.currentFix == null) {
    return null;
  }

  return $FixCopyWith<$Res>(_self.currentFix!, (value) {
    return _then(_self.copyWith(currentFix: value));
  });
}
}


/// Adds pattern-matching-related methods to [MirkPaintContext].
extension MirkPaintContextPatterns on MirkPaintContext {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MirkPaintContext value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MirkPaintContext() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MirkPaintContext value)  $default,){
final _that = this;
switch (_that) {
case _MirkPaintContext():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MirkPaintContext value)?  $default,){
final _that = this;
switch (_that) {
case _MirkPaintContext() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double zoomLevel,  double pixelRatio,  Duration sessionElapsed,  MirkViewportBbox viewportBbox,  List<VisibleMirkTile> visibleTiles,  Fix? currentFix)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MirkPaintContext() when $default != null:
return $default(_that.zoomLevel,_that.pixelRatio,_that.sessionElapsed,_that.viewportBbox,_that.visibleTiles,_that.currentFix);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double zoomLevel,  double pixelRatio,  Duration sessionElapsed,  MirkViewportBbox viewportBbox,  List<VisibleMirkTile> visibleTiles,  Fix? currentFix)  $default,) {final _that = this;
switch (_that) {
case _MirkPaintContext():
return $default(_that.zoomLevel,_that.pixelRatio,_that.sessionElapsed,_that.viewportBbox,_that.visibleTiles,_that.currentFix);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double zoomLevel,  double pixelRatio,  Duration sessionElapsed,  MirkViewportBbox viewportBbox,  List<VisibleMirkTile> visibleTiles,  Fix? currentFix)?  $default,) {final _that = this;
switch (_that) {
case _MirkPaintContext() when $default != null:
return $default(_that.zoomLevel,_that.pixelRatio,_that.sessionElapsed,_that.viewportBbox,_that.visibleTiles,_that.currentFix);case _:
  return null;

}
}

}

/// @nodoc


class _MirkPaintContext implements MirkPaintContext {
   _MirkPaintContext({required this.zoomLevel, required this.pixelRatio, required this.sessionElapsed, required this.viewportBbox, required final  List<VisibleMirkTile> visibleTiles, this.currentFix}): assert(zoomLevel >= 0.0, 'MirkPaintContext.zoomLevel must be >= 0'),assert(pixelRatio > 0.0, 'MirkPaintContext.pixelRatio must be > 0'),_visibleTiles = visibleTiles;
  

@override final  double zoomLevel;
@override final  double pixelRatio;
@override final  Duration sessionElapsed;
@override final  MirkViewportBbox viewportBbox;
 final  List<VisibleMirkTile> _visibleTiles;
@override List<VisibleMirkTile> get visibleTiles {
  if (_visibleTiles is EqualUnmodifiableListView) return _visibleTiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_visibleTiles);
}

@override final  Fix? currentFix;

/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MirkPaintContextCopyWith<_MirkPaintContext> get copyWith => __$MirkPaintContextCopyWithImpl<_MirkPaintContext>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MirkPaintContext&&(identical(other.zoomLevel, zoomLevel) || other.zoomLevel == zoomLevel)&&(identical(other.pixelRatio, pixelRatio) || other.pixelRatio == pixelRatio)&&(identical(other.sessionElapsed, sessionElapsed) || other.sessionElapsed == sessionElapsed)&&(identical(other.viewportBbox, viewportBbox) || other.viewportBbox == viewportBbox)&&const DeepCollectionEquality().equals(other._visibleTiles, _visibleTiles)&&(identical(other.currentFix, currentFix) || other.currentFix == currentFix));
}


@override
int get hashCode => Object.hash(runtimeType,zoomLevel,pixelRatio,sessionElapsed,viewportBbox,const DeepCollectionEquality().hash(_visibleTiles),currentFix);

@override
String toString() {
  return 'MirkPaintContext(zoomLevel: $zoomLevel, pixelRatio: $pixelRatio, sessionElapsed: $sessionElapsed, viewportBbox: $viewportBbox, visibleTiles: $visibleTiles, currentFix: $currentFix)';
}


}

/// @nodoc
abstract mixin class _$MirkPaintContextCopyWith<$Res> implements $MirkPaintContextCopyWith<$Res> {
  factory _$MirkPaintContextCopyWith(_MirkPaintContext value, $Res Function(_MirkPaintContext) _then) = __$MirkPaintContextCopyWithImpl;
@override @useResult
$Res call({
 double zoomLevel, double pixelRatio, Duration sessionElapsed, MirkViewportBbox viewportBbox, List<VisibleMirkTile> visibleTiles, Fix? currentFix
});


@override $MirkViewportBboxCopyWith<$Res> get viewportBbox;@override $FixCopyWith<$Res>? get currentFix;

}
/// @nodoc
class __$MirkPaintContextCopyWithImpl<$Res>
    implements _$MirkPaintContextCopyWith<$Res> {
  __$MirkPaintContextCopyWithImpl(this._self, this._then);

  final _MirkPaintContext _self;
  final $Res Function(_MirkPaintContext) _then;

/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? zoomLevel = null,Object? pixelRatio = null,Object? sessionElapsed = null,Object? viewportBbox = null,Object? visibleTiles = null,Object? currentFix = freezed,}) {
  return _then(_MirkPaintContext(
zoomLevel: null == zoomLevel ? _self.zoomLevel : zoomLevel // ignore: cast_nullable_to_non_nullable
as double,pixelRatio: null == pixelRatio ? _self.pixelRatio : pixelRatio // ignore: cast_nullable_to_non_nullable
as double,sessionElapsed: null == sessionElapsed ? _self.sessionElapsed : sessionElapsed // ignore: cast_nullable_to_non_nullable
as Duration,viewportBbox: null == viewportBbox ? _self.viewportBbox : viewportBbox // ignore: cast_nullable_to_non_nullable
as MirkViewportBbox,visibleTiles: null == visibleTiles ? _self._visibleTiles : visibleTiles // ignore: cast_nullable_to_non_nullable
as List<VisibleMirkTile>,currentFix: freezed == currentFix ? _self.currentFix : currentFix // ignore: cast_nullable_to_non_nullable
as Fix?,
  ));
}

/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MirkViewportBboxCopyWith<$Res> get viewportBbox {
  
  return $MirkViewportBboxCopyWith<$Res>(_self.viewportBbox, (value) {
    return _then(_self.copyWith(viewportBbox: value));
  });
}/// Create a copy of MirkPaintContext
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FixCopyWith<$Res>? get currentFix {
    if (_self.currentFix == null) {
    return null;
  }

  return $FixCopyWith<$Res>(_self.currentFix!, (value) {
    return _then(_self.copyWith(currentFix: value));
  });
}
}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'country_catalog.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CountryCatalog {

 List<CountryEntry> get countries;
/// Create a copy of CountryCatalog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CountryCatalogCopyWith<CountryCatalog> get copyWith => _$CountryCatalogCopyWithImpl<CountryCatalog>(this as CountryCatalog, _$identity);

  /// Serializes this CountryCatalog to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CountryCatalog&&const DeepCollectionEquality().equals(other.countries, countries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(countries));

@override
String toString() {
  return 'CountryCatalog(countries: $countries)';
}


}

/// @nodoc
abstract mixin class $CountryCatalogCopyWith<$Res>  {
  factory $CountryCatalogCopyWith(CountryCatalog value, $Res Function(CountryCatalog) _then) = _$CountryCatalogCopyWithImpl;
@useResult
$Res call({
 List<CountryEntry> countries
});




}
/// @nodoc
class _$CountryCatalogCopyWithImpl<$Res>
    implements $CountryCatalogCopyWith<$Res> {
  _$CountryCatalogCopyWithImpl(this._self, this._then);

  final CountryCatalog _self;
  final $Res Function(CountryCatalog) _then;

/// Create a copy of CountryCatalog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? countries = null,}) {
  return _then(_self.copyWith(
countries: null == countries ? _self.countries : countries // ignore: cast_nullable_to_non_nullable
as List<CountryEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [CountryCatalog].
extension CountryCatalogPatterns on CountryCatalog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CountryCatalog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CountryCatalog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CountryCatalog value)  $default,){
final _that = this;
switch (_that) {
case _CountryCatalog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CountryCatalog value)?  $default,){
final _that = this;
switch (_that) {
case _CountryCatalog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CountryEntry> countries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CountryCatalog() when $default != null:
return $default(_that.countries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CountryEntry> countries)  $default,) {final _that = this;
switch (_that) {
case _CountryCatalog():
return $default(_that.countries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CountryEntry> countries)?  $default,) {final _that = this;
switch (_that) {
case _CountryCatalog() when $default != null:
return $default(_that.countries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CountryCatalog implements CountryCatalog {
   _CountryCatalog({required final  List<CountryEntry> countries}): assert(countries.length > 0, 'CountryCatalog.countries must not be empty'),_countries = countries;
  factory _CountryCatalog.fromJson(Map<String, dynamic> json) => _$CountryCatalogFromJson(json);

 final  List<CountryEntry> _countries;
@override List<CountryEntry> get countries {
  if (_countries is EqualUnmodifiableListView) return _countries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_countries);
}


/// Create a copy of CountryCatalog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CountryCatalogCopyWith<_CountryCatalog> get copyWith => __$CountryCatalogCopyWithImpl<_CountryCatalog>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CountryCatalogToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CountryCatalog&&const DeepCollectionEquality().equals(other._countries, _countries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_countries));

@override
String toString() {
  return 'CountryCatalog(countries: $countries)';
}


}

/// @nodoc
abstract mixin class _$CountryCatalogCopyWith<$Res> implements $CountryCatalogCopyWith<$Res> {
  factory _$CountryCatalogCopyWith(_CountryCatalog value, $Res Function(_CountryCatalog) _then) = __$CountryCatalogCopyWithImpl;
@override @useResult
$Res call({
 List<CountryEntry> countries
});




}
/// @nodoc
class __$CountryCatalogCopyWithImpl<$Res>
    implements _$CountryCatalogCopyWith<$Res> {
  __$CountryCatalogCopyWithImpl(this._self, this._then);

  final _CountryCatalog _self;
  final $Res Function(_CountryCatalog) _then;

/// Create a copy of CountryCatalog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? countries = null,}) {
  return _then(_CountryCatalog(
countries: null == countries ? _self._countries : countries // ignore: cast_nullable_to_non_nullable
as List<CountryEntry>,
  ));
}


}


/// @nodoc
mixin _$CountryEntry {

@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode get alpha3; String get name; List<ChunkPart> get parts; ReassembledMeta get reassembled;
/// Create a copy of CountryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CountryEntryCopyWith<CountryEntry> get copyWith => _$CountryEntryCopyWithImpl<CountryEntry>(this as CountryEntry, _$identity);

  /// Serializes this CountryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CountryEntry&&(identical(other.alpha3, alpha3) || other.alpha3 == alpha3)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.parts, parts)&&(identical(other.reassembled, reassembled) || other.reassembled == reassembled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alpha3,name,const DeepCollectionEquality().hash(parts),reassembled);

@override
String toString() {
  return 'CountryEntry(alpha3: $alpha3, name: $name, parts: $parts, reassembled: $reassembled)';
}


}

/// @nodoc
abstract mixin class $CountryEntryCopyWith<$Res>  {
  factory $CountryEntryCopyWith(CountryEntry value, $Res Function(CountryEntry) _then) = _$CountryEntryCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode alpha3, String name, List<ChunkPart> parts, ReassembledMeta reassembled
});


$ReassembledMetaCopyWith<$Res> get reassembled;

}
/// @nodoc
class _$CountryEntryCopyWithImpl<$Res>
    implements $CountryEntryCopyWith<$Res> {
  _$CountryEntryCopyWithImpl(this._self, this._then);

  final CountryEntry _self;
  final $Res Function(CountryEntry) _then;

/// Create a copy of CountryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? alpha3 = null,Object? name = null,Object? parts = null,Object? reassembled = null,}) {
  return _then(_self.copyWith(
alpha3: null == alpha3 ? _self.alpha3 : alpha3 // ignore: cast_nullable_to_non_nullable
as CountryCode,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parts: null == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<ChunkPart>,reassembled: null == reassembled ? _self.reassembled : reassembled // ignore: cast_nullable_to_non_nullable
as ReassembledMeta,
  ));
}
/// Create a copy of CountryEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReassembledMetaCopyWith<$Res> get reassembled {
  
  return $ReassembledMetaCopyWith<$Res>(_self.reassembled, (value) {
    return _then(_self.copyWith(reassembled: value));
  });
}
}


/// Adds pattern-matching-related methods to [CountryEntry].
extension CountryEntryPatterns on CountryEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CountryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CountryEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CountryEntry value)  $default,){
final _that = this;
switch (_that) {
case _CountryEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CountryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _CountryEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  String name,  List<ChunkPart> parts,  ReassembledMeta reassembled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CountryEntry() when $default != null:
return $default(_that.alpha3,_that.name,_that.parts,_that.reassembled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  String name,  List<ChunkPart> parts,  ReassembledMeta reassembled)  $default,) {final _that = this;
switch (_that) {
case _CountryEntry():
return $default(_that.alpha3,_that.name,_that.parts,_that.reassembled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)  CountryCode alpha3,  String name,  List<ChunkPart> parts,  ReassembledMeta reassembled)?  $default,) {final _that = this;
switch (_that) {
case _CountryEntry() when $default != null:
return $default(_that.alpha3,_that.name,_that.parts,_that.reassembled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CountryEntry implements CountryEntry {
   _CountryEntry({@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) required this.alpha3, required this.name, required final  List<ChunkPart> parts, required this.reassembled}): assert(name.trim().isNotEmpty, 'CountryEntry.name must be non-empty'),assert(parts.length > 0, 'CountryEntry.parts must not be empty'),_parts = parts;
  factory _CountryEntry.fromJson(Map<String, dynamic> json) => _$CountryEntryFromJson(json);

@override@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) final  CountryCode alpha3;
@override final  String name;
 final  List<ChunkPart> _parts;
@override List<ChunkPart> get parts {
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parts);
}

@override final  ReassembledMeta reassembled;

/// Create a copy of CountryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CountryEntryCopyWith<_CountryEntry> get copyWith => __$CountryEntryCopyWithImpl<_CountryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CountryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CountryEntry&&(identical(other.alpha3, alpha3) || other.alpha3 == alpha3)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._parts, _parts)&&(identical(other.reassembled, reassembled) || other.reassembled == reassembled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alpha3,name,const DeepCollectionEquality().hash(_parts),reassembled);

@override
String toString() {
  return 'CountryEntry(alpha3: $alpha3, name: $name, parts: $parts, reassembled: $reassembled)';
}


}

/// @nodoc
abstract mixin class _$CountryEntryCopyWith<$Res> implements $CountryEntryCopyWith<$Res> {
  factory _$CountryEntryCopyWith(_CountryEntry value, $Res Function(_CountryEntry) _then) = __$CountryEntryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) CountryCode alpha3, String name, List<ChunkPart> parts, ReassembledMeta reassembled
});


@override $ReassembledMetaCopyWith<$Res> get reassembled;

}
/// @nodoc
class __$CountryEntryCopyWithImpl<$Res>
    implements _$CountryEntryCopyWith<$Res> {
  __$CountryEntryCopyWithImpl(this._self, this._then);

  final _CountryEntry _self;
  final $Res Function(_CountryEntry) _then;

/// Create a copy of CountryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? alpha3 = null,Object? name = null,Object? parts = null,Object? reassembled = null,}) {
  return _then(_CountryEntry(
alpha3: null == alpha3 ? _self.alpha3 : alpha3 // ignore: cast_nullable_to_non_nullable
as CountryCode,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parts: null == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<ChunkPart>,reassembled: null == reassembled ? _self.reassembled : reassembled // ignore: cast_nullable_to_non_nullable
as ReassembledMeta,
  ));
}

/// Create a copy of CountryEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReassembledMetaCopyWith<$Res> get reassembled {
  
  return $ReassembledMetaCopyWith<$Res>(_self.reassembled, (value) {
    return _then(_self.copyWith(reassembled: value));
  });
}
}


/// @nodoc
mixin _$ChunkPart {

 String get sha256; int get size; String get url;
/// Create a copy of ChunkPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChunkPartCopyWith<ChunkPart> get copyWith => _$ChunkPartCopyWithImpl<ChunkPart>(this as ChunkPart, _$identity);

  /// Serializes this ChunkPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChunkPart&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.size, size) || other.size == size)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sha256,size,url);

@override
String toString() {
  return 'ChunkPart(sha256: $sha256, size: $size, url: $url)';
}


}

/// @nodoc
abstract mixin class $ChunkPartCopyWith<$Res>  {
  factory $ChunkPartCopyWith(ChunkPart value, $Res Function(ChunkPart) _then) = _$ChunkPartCopyWithImpl;
@useResult
$Res call({
 String sha256, int size, String url
});




}
/// @nodoc
class _$ChunkPartCopyWithImpl<$Res>
    implements $ChunkPartCopyWith<$Res> {
  _$ChunkPartCopyWithImpl(this._self, this._then);

  final ChunkPart _self;
  final $Res Function(ChunkPart) _then;

/// Create a copy of ChunkPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sha256 = null,Object? size = null,Object? url = null,}) {
  return _then(_self.copyWith(
sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChunkPart].
extension ChunkPartPatterns on ChunkPart {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChunkPart value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChunkPart() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChunkPart value)  $default,){
final _that = this;
switch (_that) {
case _ChunkPart():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChunkPart value)?  $default,){
final _that = this;
switch (_that) {
case _ChunkPart() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sha256,  int size,  String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChunkPart() when $default != null:
return $default(_that.sha256,_that.size,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sha256,  int size,  String url)  $default,) {final _that = this;
switch (_that) {
case _ChunkPart():
return $default(_that.sha256,_that.size,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sha256,  int size,  String url)?  $default,) {final _that = this;
switch (_that) {
case _ChunkPart() when $default != null:
return $default(_that.sha256,_that.size,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChunkPart implements ChunkPart {
   _ChunkPart({required this.sha256, required this.size, required this.url}): assert(sha256.length == 64, 'ChunkPart.sha256 must be exactly 64 hex chars'),assert(size > 0, 'ChunkPart.size must be positive'),assert(url.length > 0, 'ChunkPart.url must be non-empty');
  factory _ChunkPart.fromJson(Map<String, dynamic> json) => _$ChunkPartFromJson(json);

@override final  String sha256;
@override final  int size;
@override final  String url;

/// Create a copy of ChunkPart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChunkPartCopyWith<_ChunkPart> get copyWith => __$ChunkPartCopyWithImpl<_ChunkPart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChunkPartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChunkPart&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.size, size) || other.size == size)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sha256,size,url);

@override
String toString() {
  return 'ChunkPart(sha256: $sha256, size: $size, url: $url)';
}


}

/// @nodoc
abstract mixin class _$ChunkPartCopyWith<$Res> implements $ChunkPartCopyWith<$Res> {
  factory _$ChunkPartCopyWith(_ChunkPart value, $Res Function(_ChunkPart) _then) = __$ChunkPartCopyWithImpl;
@override @useResult
$Res call({
 String sha256, int size, String url
});




}
/// @nodoc
class __$ChunkPartCopyWithImpl<$Res>
    implements _$ChunkPartCopyWith<$Res> {
  __$ChunkPartCopyWithImpl(this._self, this._then);

  final _ChunkPart _self;
  final $Res Function(_ChunkPart) _then;

/// Create a copy of ChunkPart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sha256 = null,Object? size = null,Object? url = null,}) {
  return _then(_ChunkPart(
sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ReassembledMeta {

 String get sha256; int get size;
/// Create a copy of ReassembledMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReassembledMetaCopyWith<ReassembledMeta> get copyWith => _$ReassembledMetaCopyWithImpl<ReassembledMeta>(this as ReassembledMeta, _$identity);

  /// Serializes this ReassembledMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReassembledMeta&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sha256,size);

@override
String toString() {
  return 'ReassembledMeta(sha256: $sha256, size: $size)';
}


}

/// @nodoc
abstract mixin class $ReassembledMetaCopyWith<$Res>  {
  factory $ReassembledMetaCopyWith(ReassembledMeta value, $Res Function(ReassembledMeta) _then) = _$ReassembledMetaCopyWithImpl;
@useResult
$Res call({
 String sha256, int size
});




}
/// @nodoc
class _$ReassembledMetaCopyWithImpl<$Res>
    implements $ReassembledMetaCopyWith<$Res> {
  _$ReassembledMetaCopyWithImpl(this._self, this._then);

  final ReassembledMeta _self;
  final $Res Function(ReassembledMeta) _then;

/// Create a copy of ReassembledMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sha256 = null,Object? size = null,}) {
  return _then(_self.copyWith(
sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReassembledMeta].
extension ReassembledMetaPatterns on ReassembledMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReassembledMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReassembledMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReassembledMeta value)  $default,){
final _that = this;
switch (_that) {
case _ReassembledMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReassembledMeta value)?  $default,){
final _that = this;
switch (_that) {
case _ReassembledMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sha256,  int size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReassembledMeta() when $default != null:
return $default(_that.sha256,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sha256,  int size)  $default,) {final _that = this;
switch (_that) {
case _ReassembledMeta():
return $default(_that.sha256,_that.size);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sha256,  int size)?  $default,) {final _that = this;
switch (_that) {
case _ReassembledMeta() when $default != null:
return $default(_that.sha256,_that.size);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReassembledMeta implements ReassembledMeta {
   _ReassembledMeta({required this.sha256, required this.size}): assert(sha256.length == 64, 'ReassembledMeta.sha256 must be exactly 64 hex chars'),assert(size > 0, 'ReassembledMeta.size must be positive');
  factory _ReassembledMeta.fromJson(Map<String, dynamic> json) => _$ReassembledMetaFromJson(json);

@override final  String sha256;
@override final  int size;

/// Create a copy of ReassembledMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReassembledMetaCopyWith<_ReassembledMeta> get copyWith => __$ReassembledMetaCopyWithImpl<_ReassembledMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReassembledMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReassembledMeta&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sha256,size);

@override
String toString() {
  return 'ReassembledMeta(sha256: $sha256, size: $size)';
}


}

/// @nodoc
abstract mixin class _$ReassembledMetaCopyWith<$Res> implements $ReassembledMetaCopyWith<$Res> {
  factory _$ReassembledMetaCopyWith(_ReassembledMeta value, $Res Function(_ReassembledMeta) _then) = __$ReassembledMetaCopyWithImpl;
@override @useResult
$Res call({
 String sha256, int size
});




}
/// @nodoc
class __$ReassembledMetaCopyWithImpl<$Res>
    implements _$ReassembledMetaCopyWith<$Res> {
  __$ReassembledMetaCopyWithImpl(this._self, this._then);

  final _ReassembledMeta _self;
  final $Res Function(_ReassembledMeta) _then;

/// Create a copy of ReassembledMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sha256 = null,Object? size = null,}) {
  return _then(_ReassembledMeta(
sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

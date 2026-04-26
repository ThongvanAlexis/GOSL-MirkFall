// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'category_id.dart';
import 'fix_id.dart';
import 'marker_id.dart';
import 'mirk_style_id.dart';
import 'photo_ref_id.dart';
import 'session_id.dart';

/// Bridge between json_serializable and the Dart-3 extension-type IDs.
///
/// Extension types are zero-cost at runtime but opaque to json_serializable:
/// the generator sees the wrapper name (`SessionId`) and has no built-in rule
/// for converting it to/from the underlying `String`. The top-level pairs
/// below fill that gap. They are wired on each Freezed ID field via:
///
/// ```
/// @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)
/// required SessionId id,
/// ```
///
/// One pair per ID type keeps the wire shape explicit (no reflection, no
/// `JsonConverter` class instance), and the functions are tree-shakable.
///
/// A class-based `JsonConverter<SessionId, String>` annotation does NOT
/// work here: json_serializable requires `T extends Object` and resolves
/// `T` through the declared type in the constructor, but extension types
/// collapse to their underlying representation at that resolution boundary
/// and the generator rejects them with a "Could not generate fromJson code"
/// error. Top-level `@JsonKey` converter functions bypass that resolution
/// because the generator then only needs to call the function by name.

SessionId sessionIdFromJson(String json) => SessionId(json);
String sessionIdToJson(SessionId value) => value.value;

MarkerId markerIdFromJson(String json) => MarkerId(json);
String markerIdToJson(MarkerId value) => value.value;

CategoryId categoryIdFromJson(String json) => CategoryId(json);
String categoryIdToJson(CategoryId value) => value.value;

MirkStyleId mirkStyleIdFromJson(String json) => MirkStyleId(json);
String mirkStyleIdToJson(MirkStyleId value) => value.value;

PhotoRefId photoRefIdFromJson(String json) => PhotoRefId(json);
String photoRefIdToJson(PhotoRefId value) => value.value;

FixId fixIdFromJson(String json) => FixId(json);
String fixIdToJson(FixId value) => value.value;

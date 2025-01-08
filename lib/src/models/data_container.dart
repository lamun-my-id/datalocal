// ignore_for_file: no_wildcard_variable_uses

import 'dart:convert';

import 'package:datalocal/utils/date_time.dart';

/// Container to save data path for your datalocal
class DataContainer {
  String name;
  String? path;
  int seq;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? lastDataCreatedAt;
  DateTime? lastDataUpdatedAt;
  List<String> ids;
  Map<String, dynamic> params;

  /// Container to save data path for your datalocal
  /// [name] is unique, like key, or will broken with other data.
  DataContainer({
    required this.name,
    this.path,
    this.seq = 0,
    this.createdAt,
    this.updatedAt,
    this.lastDataCreatedAt,
    this.lastDataUpdatedAt,
    required this.ids,
    Map<String, dynamic>? param,
  }) : params = param ?? {};

  /// Creating data container from map object
  factory DataContainer.fromMap(Map<String, dynamic> value) {
    return DataContainer(
      name: value['name'],
      path: value['path'],
      seq: value['seq'] ?? 0,
      createdAt: DateTimeUtils.toDateTime(value['createdAt']),
      updatedAt: DateTimeUtils.toDateTime(value['createdAt']),
      lastDataCreatedAt: DateTimeUtils.toDateTime(value['lastDataCreatedAt']),
      lastDataUpdatedAt: DateTimeUtils.toDateTime(value['lastDataUpdatedAt']),
      ids: List<String>.from(value['ids'] ?? []),
      param: value['param'],
    );
  }

  /// Creating data container to json
  String toJson() {
    return jsonEncode(
      toMap(),
      toEncodable: (_) {
        if (_ is DateTime) {
          return DateTimeUtils.toDateTime(_).toString();
        } else {
          return "";
        }
      },
    );
  }

  /// Creating data container to map object
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "path": path,
      "seq": seq,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
      "lastDataCreatedAt": lastDataCreatedAt,
      "lastDataUpdatedAt": lastDataUpdatedAt,
      "ids": ids,
      "param": params,
    };
  }
}

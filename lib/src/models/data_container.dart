import 'dart:convert';

import 'package:datalocal/utils/date_time.dart';

class DataContainer {
  String name;
  String? path;
  DateTime? createdAt;
  DateTime? updatedAt;
  List<String> ids;

  DataContainer({
    required this.name,
    this.path,
    this.createdAt,
    this.updatedAt,
    required this.ids,
  });

  factory DataContainer.fromMap(Map<String, dynamic> value) {
    return DataContainer(
      name: value['name'],
      path: value['path'],
      createdAt: DateTimeUtils.toDateTime(value['createdAt']),
      updatedAt: DateTimeUtils.toDateTime(value['createdAt']),
      ids: List<String>.from(value['ids'] ?? []),
    );
  }

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

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "path": path,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
      "ids": ids,
    };
  }
}

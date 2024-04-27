import 'dart:convert';

import 'package:datalocal/utils/date_time.dart';

import '../models/data_item.dart';

extension DataItemExtension on DataItem {
  dynamic get(String key) {
    try {
      dynamic value = {};
      switch (key) {
        case "#id":
          value = id;
          break;
        default:
          {
            List<String> path = key.split(".");
            value = data;
            for (String p in path) {
              value = value[p];
            }
          }
      }
      return value;
    } catch (e) {
      return null;
    }
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
}

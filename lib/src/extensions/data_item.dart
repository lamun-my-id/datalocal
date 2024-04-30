import 'dart:convert';

import 'package:datalocal/src/models/data_key.dart';
import 'package:datalocal/utils/date_time.dart';

import '../models/data_item.dart';

extension DataItemExtension on DataItem {
  dynamic get(DataKey key) {
    try {
      dynamic value = {};
      switch (key.key) {
        case "#id":
          value = id;
          break;
        default:
          {
            List<String> path = key.key.split(".");
            value = data;
            for (String p in path) {
              value = value[p];
            }
          }
      }
      return value;
    } catch (e) {
      if (key.onKeyCatch != null) {
        get(DataKey(key.onKeyCatch!));
      }
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

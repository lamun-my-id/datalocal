// part of "../models/data_item.dart";

import 'dart:convert';

import 'package:datalocal/src/models/data_item.dart';
import 'package:datalocal/src/models/data_key.dart';
import 'package:datalocal/src/models/data_row.dart';
import 'package:datalocal/utils/date_time.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension DataItemExtension on DataItem {
  dynamic get(Object key) {
    DataKey k;

    if (key is String) {
      k = DataKey(key);
    } else {
      if (key is DataSelectDate) {
        return DateTimeUtils.dateFormat(get(key.key), format: key.format);
      }
      if ((key is! DataKey)) {
        throw "Please fill key with String or DataKey value not ${key.runtimeType}";
      }
      k = key;
    }
    try {
      dynamic value = {};
      switch (k.key) {
        case "#id":
          value = id;
          break;
        case "#createdAt":
          value = createdAt;
          break;
        case "#updatedAt":
          value = updatedAt;
          break;
        default:
          {
            List<String> path = k.key.split(".");
            value = data;
            for (String p in path) {
              value = value[p];
            }
          }
      }
      if (value == null) throw "value null";
      return value;
    } catch (e) {
      if (k.onKeyCatch != null) {
        get(k.onKeyCatch!);
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

  // Future<void> load() async {}
  // Future<void> update() async {}

  // Future<void> update(Map<String, dynamic> value) async {
  //   _data = {..._data, ...value};
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     prefs.setString(
  //         EncryptUtil().encript(path()), EncryptUtil().encript(toJson()));
  //   } catch (e) {
  //     //
  //   }
  // }

  // Future<void> set(Map<String, dynamic> value) async {
  //   _data = value;
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     prefs.setString(
  //         EncryptUtil().encript(path()), EncryptUtil().encript(toJson()));
  //   } catch (e) {
  //     //
  //   }
  // }

  Future<void> delete() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.remove(EncryptUtil().encript(path()));
    } catch (e) {
      //
    }
  }

  // Map<String, dynamic> toMap() {
  //   return {
  //     "id": _id,
  //     "data": _data,
  //     "parent": _parent,
  //     "name": _name,
  //     "createdAt": createdAt,
  //     "updatedAt": updatedAt,
  //   };
  // }
}

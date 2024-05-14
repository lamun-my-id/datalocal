// part of "../models/data_item.dart";

import 'dart:convert';

import 'package:datalocal/src/models/data_item.dart';
import 'package:datalocal/src/models/data_key.dart';
import 'package:datalocal/utils/date_time.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      if (value == null) throw "value null";
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

// part of "../models/data_item.dart";

// import 'package:datalocal/datalocal.dart';
import 'package:datalocal/src/extensions/data_local.dart';
import 'package:datalocal/src/models/data_key.dart';

extension DataRowExtension on DataItemRow {
  dynamic get(Object key) {
    DataKey k;
    if (key is String) {
      k = DataKey(key);
    } else {
      if ((key is! DataKey)) {
        throw "Please fill key with String or DataKey value";
      }
      k = key;
    }
    try {
      dynamic value = {};
      switch (k.key) {
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
}

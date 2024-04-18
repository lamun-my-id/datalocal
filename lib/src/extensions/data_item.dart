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
}

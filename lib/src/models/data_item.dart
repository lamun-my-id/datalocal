import 'package:data_state/utils/date_time.dart';

class DataItem {
  String id;
  Map<String, dynamic> data;
  bool selected = false;
  String parent;
  bool isLoading = false;

  DataItem({
    required this.id,
    required this.data,
    required this.parent,
  });

  factory DataItem.fromMap(Map<String, dynamic> value) {
    Map<String, dynamic> data = Map<String, dynamic>.from(value['data']);
    try {
      data["createdAt"] = DateTimeUtils.toDateTime(data['createdAt']);
      data["updatedAt"] = DateTimeUtils.toDateTime(data['updatedAt']);
      data["deletedAt"] = DateTimeUtils.toDateTime(data['deletedAt']);
    } catch (e) {
      //
    }

    return DataItem(
      id: value['id'] ?? "",
      data: data,
      parent: value['parent'] ?? "",
    );
  }

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
              switch (data[key].runtimeType) {
                default:
                  value = value[p];
              }
            }
          }
      }
      return value;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "data": data,
      "parent": parent,
    };
  }

  Future<void> updateForce(Map<Object, dynamic> value) async {
    try {
      data = {...data, ...Map<String, dynamic>.from(value)};
    } catch (e) {}
    data['updatedAt'] = DateTime.now();
  }
}

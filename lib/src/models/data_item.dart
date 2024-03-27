import 'package:datalocal/utils/date_time.dart';

class DataItem {
  late String _id;
  String get id => _id;

  late Map<String, dynamic> _data;
  Map<String, dynamic> get data => _data;
  // bool selected = false;
  late String _parent;
  String get parent => _parent;
  // bool isLoading = false;
  late DateTime _createdAt;
  DateTime? get createdAt => _createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;

  /// Used by [DataLocal] data
  DataItem() {
    _createdAt = DateTime.now();
    _updatedAt = null;
  }

  // Generate new DataItem
  static DataItem create(String id,
      {Map<String, dynamic>? value, String? parent}) {
    DataItem result = DataItem();
    result._id = id;
    result._data = value ?? {};
    result._parent = parent ?? "";
    return result;
  }

  factory DataItem.fromMap(Map<String, dynamic> value) {
    Map<String, dynamic> data = Map<String, dynamic>.from(value['data']);
    try {
      data["createdAt"] =
          DateTimeUtils.toDateTime(value['createdAt'] ?? data['createdAt']);
      data["updatedAt"] =
          DateTimeUtils.toDateTime(value['updatedAt'] ?? data['updatedAt']);
      data["deletedAt"] =
          DateTimeUtils.toDateTime(value['deletedAt'] ?? data['deletedAt']);
    } catch (e) {
      //
    }

    DataItem result = DataItem();
    result._id = value['id'] ?? "";
    result._data = data;
    result._parent = value['parent'] ?? "";
    result._createdAt = data["createdAt"];
    result._updatedAt = data["updatedAt"];

    return result;
  }

  dynamic get(String key) {
    try {
      dynamic value = {};
      switch (key) {
        case "#id":
          value = _id;
          break;
        default:
          {
            List<String> path = key.split(".");
            value = _data;
            for (String p in path) {
              switch (_data[key].runtimeType) {
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
      "id": _id,
      "data": _data,
      "parent": _parent,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
    };
  }

  update(Map<String, dynamic> value) {
    _data = {..._data, ...value};
    _updatedAt = DateTime.now();
  }

  // Future<void> updateForce(Map<Object, dynamic> value) async {
  //   try {
  //     data = {...data, ...Map<String, dynamic>.from(value)};
  //   } catch (e) {
  //     //
  //   }
  //   data['updatedAt'] = DateTime.now();
  // }
}

import 'package:datalocal/utils/date_time.dart';

class DataItem {
  late String _id;
  String get id => _id;

  late Map<String, dynamic> _data;
  Map<String, dynamic> get data => _data;

  late String _parent;
  String get parent => _parent;
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
    result._createdAt = data["createdAt"] ?? DateTime.now();
    result._updatedAt = data["updatedAt"];

    return result;
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

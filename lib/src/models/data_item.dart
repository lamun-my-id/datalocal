import 'dart:convert';
import 'dart:typed_data';

import 'package:datalocal/datalocal.dart';
import 'package:datalocal/src/extensions/data_item.dart';
import 'package:datalocal/utils/compute.dart';
import 'package:datalocal/utils/date_time.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

// part '../extensions/data_item.dart';

class DataItem {
  late String _id;
  String get id => _id;

  late Map<String, dynamic> _data;
  Map<String, dynamic> get data => _data;

  late String _name;
  String get name => _name;

  late String _parent;
  String get parent => _parent;

  late DateTime _createdAt;
  DateTime? get createdAt => _createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;

  int? _seq;
  int? get seq => _seq;

  /// Used by [DataLocal] data
  DataItem() {
    _createdAt = DateTime.now();
    _updatedAt = null;
  }

  // Generate new DataItem
  static DataItem create(String id,
      {Map<String, dynamic>? value, String? parent, String? name, int? seq}) {
    DataItem result = DataItem();
    result._id = id;
    result._data = value ?? {};
    result._parent = parent ?? "";
    result._name = name ?? "";
    result._seq = seq;
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
      data["seq"] = DateTimeUtils.toDateTime(value['seq'] ?? data['seq']);
    } catch (e) {
      //
    }

    DataItem result = DataItem();
    result._id = value['id'] ?? "";
    result._data = data;
    result._parent = value['parent'] ?? "";
    result._name = value['name'] ?? "";
    result._createdAt = data["createdAt"] ?? DateTime.now();
    result._updatedAt = data["updatedAt"];
    result._seq = data["seq"];

    return result;
  }

  // updateData(Map<String, dynamic> value) {
  //   _data = {..._data, ...value};
  //   try {
  //     if (value['updatedAt']) {
  //       _updatedAt = DateTimeUtils.toDateTime(value['updatedAt']);
  //     } else {
  //       throw "tidak ada updatedAt";
  //     }
  //   } catch (e) {
  //     _updatedAt = DateTime.now();
  //   }
  // }

  // Future<void> updateForce(Map<Object, dynamic> value) async {
  //   try {
  //     data = {...data, ...Map<String, dynamic>.from(value)};
  //   } catch (e) {
  //     //
  //   }
  //   data['updatedAt'] = DateTime.now();
  // }

  Future<void> saveFile(Uint8List value,
      {String? name, DataLocal? datalocal}) async {
    String id =
        EncryptUtil().encript("${path()}-${files.length}-${DateTime.now()}");
    DataFile file = DataFile.create(id);
    files.add(file);
    await save({}, datalocal: datalocal);
    await file.saveBytes(value);
  }

  List<DataFile> files = [];
}

extension DataItemExtensionLocal on DataItem {
  String path() {
    return "$name-$parent-$id";
  }

  Future<void> save(Map<String, dynamic> value, {DataLocal? datalocal}) async {
    _data = {..._data, ...value};
    _updatedAt = DateTime.now();
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString(
          EncryptUtil().encript(path()), EncryptUtil().encript(toJson()));
      datalocal?.refresh();
    } catch (e) {
      //
    }
  }

  Map<String, dynamic> toMap() {
    return {
      "id": _id,
      "data": _data,
      "parent": _parent,
      "name": _name,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
      "seq": seq,
      "files": files.map((_) => _.toMap()).toList(),
    };
  }
}

class DataFile {
  late String _id;
  String get id => _id;

  late String _name;
  String get name => _name;

  late String _parent;
  String get parent => _parent;

  late DateTime _createdAt;
  DateTime? get createdAt => _createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;

  DataFile() {
    _createdAt = DateTime.now();
    _updatedAt = null;
  }

  static DataFile create(
    String id, {
    String? parent,
    String? name,
    int? seq,
  }) {
    DataFile result = DataFile();
    result._id = id;
    result._parent = parent ?? "";
    result._name = name ?? "";
    return result;
  }

  save() async {
    return await DataCompute().isolate(
      (_) async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        return prefs.getString(EncryptUtil().encript(path())) ?? "";
      },
      args: [],
    );
  }

  Future<Uint8List> getBytes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return base64Decode(
        prefs.getString(EncryptUtil().encript(pathFile())) ?? "");
    // return await DataCompute().isolate(
    //   (_) async {
    //     SharedPreferences prefs = _[0];
    //   },
    //   args: [prefs],
    // );
  }

  saveBytes(Uint8List value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(EncryptUtil().encript(pathFile()), base64Encode(value));
    // await DataCompute().isolate(
    //   (_) async {
    //     SharedPreferences prefs = _[0];
    //   },
    //   args: [prefs],
    // );
  }

  factory DataFile.fromMap(Map<String, dynamic> value) {
    Map<String, dynamic> data = Map<String, dynamic>.from(value['data']);
    try {
      data["createdAt"] =
          DateTimeUtils.toDateTime(value['createdAt'] ?? data['createdAt']);
      data["updatedAt"] =
          DateTimeUtils.toDateTime(value['updatedAt'] ?? data['updatedAt']);
      data["deletedAt"] =
          DateTimeUtils.toDateTime(value['deletedAt'] ?? data['deletedAt']);
      data["seq"] = DateTimeUtils.toDateTime(value['seq'] ?? data['seq']);
    } catch (e) {
      //
    }

    DataFile result = DataFile();
    result._id = value['id'] ?? "";
    result._parent = value['parent'] ?? "";
    result._name = value['name'] ?? "";
    result._createdAt = data["createdAt"] ?? DateTime.now();
    result._updatedAt = data["updatedAt"];

    return result;
  }
}

extension DataFileExtensionLocal on DataFile {
  String pathFile() {
    return "$parent-$id-file";
  }

  String path() {
    return "$parent-$id-file";
  }

  Map<String, dynamic> toMap() {
    return {
      "id": _id,
      "parent": _parent,
      "name": _name,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
    };
  }
}

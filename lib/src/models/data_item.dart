// ignore_for_file: no_wildcard_variable_uses

import 'dart:convert';
import 'dart:typed_data';

import 'package:datalocal/datalocal.dart';
import 'package:datalocal/src/extensions/data_item.dart';
import 'package:datalocal/src/models/data_compute.dart';
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

  List<DataFile> _files = [];
  List<DataFile> get files => _files;

  /// Used by [DataLocal] data
  DataItem() {
    _createdAt = DateTime.now();
    _updatedAt = null;
  }

  // Generate new DataItem
  static DataItem create(
    String id, {
    Map<String, dynamic>? value,
    String? parent,
    String? name,
    int? seq,
  }) {
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
      // data["createdAt"] =
      //     DateTimeUtils.toDateTime(value['createdAt'] ?? data['createdAt']);
      // data["updatedAt"] =
      //     DateTimeUtils.toDateTime(value['updatedAt'] ?? data['updatedAt']);
      // data["deletedAt"] =
      //     DateTimeUtils.toDateTime(value['deletedAt'] ?? data['deletedAt']);
      data["seq"] = DateTimeUtils.toDateTime(value['seq'] ?? data['seq']);
      data['files'] = List<Map<String, dynamic>>.from(value['files']);
    } catch (e) {
      //
    }

    DataItem result = DataItem();
    result._id = value['id'] ?? "";
    result._data = data;
    result._parent = value['parent'] ?? "";
    result._name = value['name'] ?? "";
    try {
      result._createdAt =
          DateTimeUtils.toDateTime(
            value['createdAt'] ?? data['#']['createdAt'],
          ) ??
          DateTime.now();
      result._updatedAt = DateTimeUtils.toDateTime(
        value['updatedAt'] ?? data['#']['#updatedAt'],
      );
    } catch (e) {
      //
    }
    result._seq = data["seq"];
    try {
      result._files = List<Map<String, dynamic>>.from(value['files'] ?? [])
          .map((file) => DataFile.fromMap(Map<String, dynamic>.from(file)))
          .toList();
    } catch (e) {
      //
    }

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

  Future<void> saveFile(
    Uint8List value, {
    String? name,
    DataLocal? datalocal,
  }) async {
    String id = EncryptUtil().encript(
      "${path()}-${files.length}-${DateTime.now()}",
    );
    DataFile file = DataFile.create(id, name: name);
    files.add(file);
    await save({}, datalocal: datalocal);
    await file.saveBytes(value);
  }
}

extension DataItemExtensionLocal on DataItem {
  String path() {
    return "$name-$parent-$id";
  }

  Future<void> save(Map<String, dynamic> value, {DataLocal? datalocal}) async {
    _data = {..._data, ...value};
    _updatedAt = DateTime.now();
    dynamic args = List<dynamic>.from(
      await DataCompute().isolate((arguments) async {
        DataItem data = arguments[0];
        return [
          EncryptUtil().encript(data.path()),
          EncryptUtil().encript(data.toJson()),
          // 2,
        ];
      }, args: [this]),
    );
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString(args[0], args[1]);
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
      "files": files.map((file) => file.toMap()).toList(),
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

  static DataFile create(String id, {String? parent, String? name, int? seq}) {
    DataFile result = DataFile();
    result._id = id;
    result._parent = parent ?? "";
    result._name = name ?? "";
    return result;
  }

  Future<String> save() async {
    return await DataCompute().isolate((_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(EncryptUtil().encript(path())) ?? "";
    }, args: []);
  }

  Future<Uint8List> getBytes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return base64Decode(
      prefs.getString(EncryptUtil().encript(pathFile())) ?? "",
    );
    // return await DataCompute().isolate(
    //   (_) async {
    //     SharedPreferences prefs = _[0];
    //   },
    //   args: [prefs],
    // );
  }

  Future<bool> saveBytes(Uint8List value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      EncryptUtil().encript(pathFile()),
      base64Encode(value),
    );
    // await DataCompute().isolate(
    //   (_) async {
    //     SharedPreferences prefs = _[0];
    //   },
    //   args: [prefs],
    // );
  }

  factory DataFile.fromMap(Map<String, dynamic> value) {
    try {
      value["createdAt"] = DateTimeUtils.toDateTime(value['createdAt']);
      value["updatedAt"] = DateTimeUtils.toDateTime(value['updatedAt']);
      value["deletedAt"] = DateTimeUtils.toDateTime(value['deletedAt']);
      value["seq"] = DateTimeUtils.toDateTime(value['seq']);
    } catch (e) {
      //
    }

    DataFile result = DataFile();
    result._id = value['id'] ?? "";
    result._parent = value['parent'] ?? "";
    result._name = value['name'] ?? "";
    result._createdAt = value["createdAt"] ?? DateTime.now();
    result._updatedAt = value["updatedAt"];

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

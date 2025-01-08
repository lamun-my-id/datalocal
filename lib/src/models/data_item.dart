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

/// DataItem your saved data in datalocal
/// use [dataitem.get(fieldname)] to get field value
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

  // Generate new DataItem from map object
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
      result._createdAt = DateTimeUtils.toDateTime(
              value['createdAt'] ?? data['#']['createdAt']) ??
          DateTime.now();
      result._updatedAt = DateTimeUtils.toDateTime(
          value['updatedAt'] ?? data['#']['#updatedAt']);
    } catch (e) {
      //
    }
    result._seq = data["seq"];
    try {
      result._files = List<Map<String, dynamic>>.from(value['files'] ?? [])
          .map((_) => DataFile.fromMap(Map<String, dynamic>.from(_)))
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

  // save file locally use bytes data
  Future<void> saveFile(Uint8List value,
      {String? name, DataLocal? datalocal}) async {
    String id =
        EncryptUtil().encript("${path()}-${files.length}-${DateTime.now()}");
    DataFile file = DataFile.create(id, name: name);
    files.add(file);
    await save({}, datalocal: datalocal);
    await file.saveBytes(value);
  }
}

extension DataItemExtensionLocal on DataItem {
  // get path for your saved data
  String path() {
    return "$name-$parent-$id";
  }

  // update data
  Future<void> save(Map<String, dynamic> value, {DataLocal? datalocal}) async {
    _data = {..._data, ...value};
    _updatedAt = DateTime.now();
    dynamic args = List<dynamic>.from(await DataCompute().isolate((_) async {
      DataItem data = _[0];
      return [
        EncryptUtil().encript(data.path()),
        EncryptUtil().encript(data.toJson()),
        // 2,
      ];
    }, args: [this]));
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString(args[0], args[1]);
      datalocal?.refresh();
    } catch (e) {
      //
    }
  }

  // convert dataitem to map object
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

// datafile model to save in dataitem
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

  // save data file to dataitem
  save() async {
    return await DataCompute().isolate(
      (_) async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        return prefs.getString(EncryptUtil().encript(path())) ?? "";
      },
      args: [],
    );
  }

  // get bytes data
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

  // save to update bytes data
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

  // creating datafile from map object
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
  // get saved file path
  String pathFile() {
    return "$parent-$id-file";
  }

  // get saved file path
  String path() {
    return "$parent-$id-file";
  }

  // convert datafile data to map object
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

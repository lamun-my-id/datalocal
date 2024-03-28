import 'dart:convert';
import 'dart:isolate';

import 'package:datalocal/src/extensions/list_data_item.dart';
import 'package:datalocal/src/models/data_filter.dart';
import 'package:datalocal/src/models/data_item.dart';
import 'package:datalocal/src/models/data_search.dart';
import 'package:datalocal/src/models/data_sort.dart';
import 'package:datalocal/utils/date_time.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataLocal {
  final String _stateName;
  String get stateName => _stateName;
  // final List<DataFilter>? filters;
  // final List<DataSort>? sorts;
  Function()? onRefresh;
  final bool _debugMode;

  DataLocal(
    String stateName, {
    // this.filters,
    // this.sorts,
    this.onRefresh,
    bool debugMode = false,
  })  : _debugMode = debugMode,
        _stateName = stateName;

  // Static Func
  /// Used for the first time initialize [DataLocal]
  static Future<DataLocal> create(
    String stateName, {
    // List<DataFilter> filters = const [],
    // List<DataSort> sorts = const [],
    Function()? onRefresh,
    bool? debugMode,
  }) async {
    DataLocal result = DataLocal(
      stateName,
      // filters: filters,
      // sorts: sorts,
      onRefresh: onRefresh,
      debugMode: debugMode ?? false,
    );
    await result._initialize();
    return result;
  }

  // Local Variable
  bool _isInit = false;
  bool get isInit => _isInit;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _count = 0;
  int get count => _count;

  List<DataItem> _data = [];
  List<DataItem> get data => _data;
  // late DateTime _lastNewestCheck;
  // late DateTime _lastUpdateCheck;
  // Local Variable Private
  late String _name;
  final int _size = 200;

  /// Log DataLocal used on debugMode
  _log(dynamic arg) async {
    if (_debugMode) {
      debugPrint('DataLocal (Debug): ${arg.toString()}');
    }
  }

  // Function
  /// Used to initialize DataLocal
  _initialize() async {
    try {
      try {
        initializeDateFormatting();
      } catch (e) {
        //
      }
      _name = EncryptUtil().encript(
        "DataLocal-$stateName",
      );
      try {
        String? res;
        try {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          res = (prefs.getString(EncryptUtil().encript("$_name-0")));
        } catch (e) {
          _log("error get res");
        }

        if (res == null) {
          _data = [];
          throw "tidak ada state (${EncryptUtil().encript("$_name-0")})";
        }
        try {
          if (kIsWeb) {
            Map<String, dynamic> value = _jsonToListDataItem([null, res]);
            data.addAll(value['data']);
            _count = data.length;
          } else {
            ReceivePort rPort = ReceivePort();
            await Isolate.spawn(_jsonToListDataItem, [rPort.sendPort, res]);
            Map<String, dynamic> value = await rPort.first;
            data.addAll(value['data']);
            _count = data.length;
            rPort.close();
          }
          _isInit = true;
          refresh();
        } catch (e) {
          _log("initialize error(3) : $e");
          //
        }
        _count = data.length;
        if (count == 0 || count == _size) {
          _loadState();
        }
      } catch (e) {
        _log("initialize error(2)#$stateName : $e");
      }
      _isInit = true;
      refresh();
    } catch (e) {
      _log("initialize error(1) : $e");
      //
    }
  }

  /// Used to save state data to shared preferences
  Future<void> _saveState() async {
    _isLoading = true;
    refresh();
    int loop = (count / _size).ceil();
    _log('state akan dibuat ${loop + 1} ($count/$_size)');
    for (int i = 0; i < loop + 1; i++) {
      _log("start savestate number : ${i + 1}");
      SharedPreferences prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        try {
          if (kIsWeb) {
            String res = _listDataItemToJson(
                [null, data.skip(i * _size).take(_size).toList()]);
            // _log((await rPort.first as String).length);
            prefs.setString(EncryptUtil().encript("$_name-$i"), res);
          } else {
            ReceivePort rPort = ReceivePort();
            _log("Isolate spawn");
            await Isolate.spawn(_listDataItemToJson,
                [rPort.sendPort, data.skip(i * _size).take(_size).toList()]);
            // _log((await rPort.first as String).length);
            String value = await rPort.first as String;
            prefs.setString(EncryptUtil().encript("$_name-$i"), value);
            rPort.close();
          }
          _log("Berhasil save data");
        } catch (e) {
          _log("gagal save state : $e");
          //
        }
        _log("end of savestate number : ${i + 1}");
      } catch (e) {
        _log("pref null");
      }
    }
    _isLoading = false;
    refresh();
  }

  /// Used to load state data from shared preferences
  Future<void> _loadState() async {
    // _log("start loadstate");
    _isLoading = true;
    refresh();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int i = 0;
    bool lanjut = true;
    List<DataItem> result = [];
    while (lanjut) {
      String? res = (prefs.getString(EncryptUtil().encript("$_name-$i")));
      if (res != null) {
        // _log("start loadstate number: ${i + 1}");
        try {
          if (kIsWeb) {
            Map<String, dynamic> value = _jsonToListDataItem([null, res]);
            result.addAll(value['data']);
          } else {
            ReceivePort rPort = ReceivePort();
            await Isolate.spawn(_jsonToListDataItem, [rPort.sendPort, res]);
            Map<String, dynamic> value = await rPort.first;
            result.addAll(value['data']);
            rPort.close();
          }
          refresh();
          // _log("Berhasil load data");
        } catch (e) {
          //
        }
        i++;
      } else {
        lanjut = false;
      }
    }
    _data = result;
    _count = data.length;
    _data = await find(
        // sorts: sorts
        );
    _isLoading = false;
    refresh();
  }

  /// Used to delete state data from shared preferences
  Future<void> _deleteState() async {
    _isLoading = true;
    refresh();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int i = 0;
    bool lanjut = true;
    List<DataItem> result = [];
    while (lanjut) {
      String? res = (prefs.getString(EncryptUtil().encript("$_name-$i")));
      if (res != null) {
        await prefs.remove(EncryptUtil().encript("$_name-$i"));
        i++;
      } else {
        lanjut = false;
      }
    }
    _data = result;
    _count = data.length;
    _data = await find(
        // sorts: sorts
        );
    _isLoading = false;
    refresh();
  }

  /// Refresh data, launch if onRefresh is include
  refresh() {
    if (onRefresh != null) {
      _log("refresh berjalan");
      onRefresh!();
    } else {
      _log("tidak ada refresh");
    }
  }

  void dispose() {}

  /// Find More Efective Data with this function
  Future<List<DataItem>> find({
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    DataSearch? search,
  }) async {
    // _log('findAsync Isolate.spawn');
    Map<String, dynamic> res = {};
    try {
      if (kIsWeb) {
        res = _listDataItemFind([null, data, filters, sorts, search]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(
            _listDataItemFind, [rPort.sendPort, data, filters, sorts, search]);
        res = await rPort.first;
        rPort.close();
      }
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }
    return res['data'];
  }

  /// Insert and save DataItem
  Future<DataItem> insertOne(Map<String, dynamic> value, {String? id}) async {
    // String id = EncryptUtil().encript(
    //     DateTimeUtils.dateFormat(DateTime.now(), format: 'yyyyMMddhhmmss') ??
    //         "");
    // _log(id);
    DataItem newData = DataItem.create(
      id ??
          EncryptUtil().encript(DateTimeUtils.dateFormat(DateTime.now(),
                  format: 'yyyyMMddhhmmss') ??
              ""),
      value: value,
      parent: stateName,
    );
    try {
      data.insert(0, newData);
      refresh();
      find(
              // sorts: sorts
              )
          .then((value) async {
        _data = value;
        _count = data.length;
        refresh();
        _log("start save state");
        await _saveState();
        _log("start save success");
      });
    } catch (e) {
      _log("error disini");
      //
    }
    return newData;
  }

  /// Update to save DataItem
  Future<DataItem> updateOne(String id,
      {required Map<String, dynamic> value}) async {
    try {
      Map<String, dynamic> res = {};
      if (kIsWeb) {
        res = _listDataItemUpdate([null, data, id, value]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(
            _listDataItemUpdate, [rPort.sendPort, data, id, value]);
        res = await rPort.first;
        rPort.close();
      }
      _data = res['data'];
      _count = data.length;
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    List<DataItem> d = await find(
      filters: [DataFilter(key: "#id", value: id)],
    );
    if (d.isEmpty) {
      throw "Tidak ada data";
    }
    refresh();
    _saveState();
    return d.first;
  }

  /// Deletion DataItem
  Future<void> deleteOne(String id) async {
    try {
      Map<String, dynamic> res = {};
      if (kIsWeb) {
        res = _listDataItemDelete([null, data, id]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(_listDataItemDelete, [rPort.sendPort, data, id]);
        res = await rPort.first;
        rPort.close();
      }
      _data = res['data'];
      _count = data.length;
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    _saveState();
  }

  /// Start from initialize, save state will not deleted
  Future<void> reboot() async {
    await _deleteState();
    _data.clear();
    await _initialize();
  }
}

// dynamic _listDataItemAddUpdate(List<dynamic> args) {
//   // _log('_listDataItemAddUpdate start');
//   List<DataItem> result = args[1];
//   DataItem newData = args[2];

//   int index = result.indexWhere((element) => element.id == newData.id);
//   if (index >= 0) {
//     result[index] = newData;
//   } else {
//     result.insert(0, newData);
//   }
//   if (kIsWeb) {
//     return {"data": result, "count": result.length};
//   } else {
//     SendPort port = args[0];
//     Isolate.exit(port, {"data": result, "count": result.length});
//   }
// }

/// Convert Json to List<DataItem>
dynamic _jsonToListDataItem(List<dynamic> args) {
  List<DataItem> result = [];
  int count = 0;
  try {
    result = List<Map<String, dynamic>>.from(
            jsonDecode(EncryptUtil().decript(args[1])))
        .map((e) => DataItem.fromMap(e))
        .toList();
    count = result.length;
  } catch (e) {
    // print(args[1]);
  }
  if (kIsWeb) {
    return {"data": result, "count": count};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": count});
  }
}

/// Update List DataItem
dynamic _listDataItemUpdate(List<dynamic> args) {
  List<DataItem> result = args[1];
  String id = args[2];
  Map<String, dynamic> update = args[3];

  int i = result.indexWhere((element) => element.id == id);
  if (i >= 0) {
    result[i].update(update);
  }

  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Delete List DataItem
dynamic _listDataItemDelete(List<dynamic> args) {
  List<DataItem> result = args[1];
  String id = args[2];

  int i = result.indexWhere((element) => element.id == id);
  if (i >= 0) {
    result.removeAt(i);
  }

  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Find List DataItem
dynamic _listDataItemFind(List<dynamic> args) {
  // _log('_listDataItemFind start');

  List<DataItem> result = args[1];
  List<DataFilter>? filters = args[2];
  List<DataSort>? sorts = args[3];
  DataSearch? search = args[4];

  if (filters != null) {
    result = result.filterData(filters);
  }
  if (sorts != null) {
    result = result.sortData(sorts);
  }
  if (search != null) {
    result = result.searchData(search);
  }
  // _log(result.length.toString());
  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Convert List<DataItem> to json
dynamic _listDataItemToJson(List<dynamic> args) {
  // _log('_listDataItemModelToJson start');
  String result = jsonEncode(
    (args[1] as List<DataItem>).map((e) => e.toMap()).toList(),
    toEncodable: (_) {
      // if (_ is Timestamp) {
      //   return DateTimeUtils.toDateTime(_).toString();
      // }
      if (_ is DateTime) {
        return DateTimeUtils.toDateTime(_).toString();
      } else {
        // _log(_.runtimeType.toString());
        return "";
      }
    },
  );
  // _log('${result.length}');
  if (kIsWeb) {
    return EncryptUtil().encript(result);
  } else {
    SendPort port = args[0];
    Isolate.exit(port, EncryptUtil().encript(result));
  }
}

import 'dart:convert';
import 'dart:isolate';

import 'package:datalocal/src/extensions/list_data_item.dart';
import 'package:datalocal/src/models/data_container.dart';
import 'package:datalocal/src/models/data_filter.dart';
import 'package:datalocal/src/models/data_item.dart';
import 'package:datalocal/src/models/data_key.dart';
import 'package:datalocal/src/models/data_search.dart';
import 'package:datalocal/src/models/data_sort.dart';
// import 'package:datalocal/utils/date_time.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataLocal {
  final String _stateName;
  String get stateName => _stateName;
  Function()? onRefresh;
  final bool _debugMode;

  DataLocal(
    String stateName, {
    this.onRefresh,
    bool debugMode = false,
  })  : _debugMode = debugMode,
        _stateName = stateName;

  // Static Func
  /// Used for the first time initialize [DataLocal]
  static Future<DataLocal> create(
    String stateName, {
    Function()? onRefresh,
    bool? debugMode,
  }) async {
    DataLocal result = DataLocal(
      stateName,
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

  int _sequence = 0;
  int get sequence => _sequence;

  late DataContainer _container;

  // List<DataItem> _data = [];
  // List<DataItem> get data => _data;

  late String _name;

  Map<String, DataItem> _raw = {};
  Map<String, DataItem> get raw => _raw;

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
      _name = EncryptUtil().encript(
        "DataLocal-$stateName",
      );
      try {
        String? res;
        try {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          res = (prefs.getString(EncryptUtil().encript(_name)));
        } catch (e) {
          _log("error get res");
        }

        if (res == null) {
          _container = DataContainer(
            name: _name,
            seq: sequence,
            ids: [],
          );
          throw "tidak ada state";
        } else {
          _container =
              DataContainer.fromMap(jsonDecode(EncryptUtil().decript(res)));
        }

        if (_container.ids.isNotEmpty) {
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
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(EncryptUtil().encript(_name),
          EncryptUtil().encript(_container.toJson()));
    } catch (e) {
      //
    }
    _isLoading = false;
    refresh();
  }

  /// Used to load state data from shared preferences
  Future<void> _loadState() async {
    _isLoading = true;
    refresh();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    for (String id in _container.ids) {
      String? ref = prefs.getString(EncryptUtil().encript(id));
      if (ref == null) {
        // Tidak ada data yang disimpan
      } else {
        DataItem d = DataItem.fromMap(jsonDecode(EncryptUtil().decript(ref)));
        _raw[d.id] = d;
        // _data.add(DataItem.fromMap(jsonDecode(EncryptUtil().decript(ref))));
      }
    }

    _count = _container.ids.length;

    _isLoading = false;
    refresh();
  }

  /// Used to delete state data from shared preferences
  Future<void> _deleteState() async {
    _isLoading = true;
    refresh();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await (prefs.remove(EncryptUtil().encript(_name)));

    for (int i = 0; i < _container.ids.length; i++) {
      await (prefs
          .remove(EncryptUtil().encript(_raw[_container.ids[i]]!.path())));
      _raw.remove(_container.ids[i]);
    }
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
        res = _listDataItemFind([null, _raw, filters, sorts, search]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(
            _listDataItemFind, [rPort.sendPort, _raw, filters, sorts, search]);
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
    _sequence++;
    DataItem newData = DataItem.create(
      id ??
          EncryptUtil()
              .encript(DateTime.now().toString() + sequence.toString()),
      value: value,
      name: stateName,
      parent: "",
    );
    try {
      _raw[newData.id] = newData;
      refresh();
      await newData.save({});
      _container.ids.add(newData.path());
      _count = _container.ids.length;
      await _saveState();
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
      _count = _container.ids.length;
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    _raw[id]!.save(value);
    refresh();
    _saveState();
    return _raw[id]!;
  }

  /// Deletion DataItem
  Future<void> deleteOne(String id) async {
    try {
      List<DataItem> d = await find(
        filters: [DataFilter(key: DataKey("#id"), value: id)],
      );
      if (d.isEmpty) {
        throw "Tidak ada data";
      }

      if (d.isEmpty) throw "Tidak ada data";

      Map<String, dynamic> res = {};

      _raw = res['data'];
      _container.ids.remove(d.first.path());
      _count = _container.ids.length;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(EncryptUtil().encript(d.first.path()));
      _saveState();
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    _saveState();
  }

  /// Start from initialize, save state will not deleted
  Future<void> reboot() async {
    await _deleteState();
    _raw.clear();
    await _initialize();
  }
}

/// Convert Json to List<DataItem>
// dynamic _jsonToListDataItem(List<dynamic> args) {
//   List<DataItem> result = [];
//   int count = 0;
//   try {
//     result = List<Map<String, dynamic>>.from(
//             jsonDecode(EncryptUtil().decript(args[1])))
//         .map((e) => DataItem.fromMap(e))
//         .toList();
//     count = result.length;
//   } catch (e) {
//     // print(args[1]);
//   }
//   if (kIsWeb) {
//     return {"data": result, "count": count};
//   } else {
//     SendPort port = args[0];
//     Isolate.exit(port, {"data": result, "count": count});
//   }
// }

/// Update List DataItem
// dynamic _listDataItemUpdate(List<dynamic> args) {
//   List<DataItem> result = args[1];
//   String id = args[2];
//   Map<String, dynamic> update = args[3];

//   int i = result.indexWhere((element) => element.id == id);
//   if (i >= 0) {
//     result[i].save(update);
//   }

//   if (kIsWeb) {
//     return {"data": result, "count": result.length};
//   } else {
//     SendPort port = args[0];
//     Isolate.exit(port, {"data": result, "count": result.length});
//   }
// }

/// Delete List DataItem
// dynamic _listDataItemDelete(List<dynamic> args) {
//   List<DataItem> result = args[1];
//   String id = args[2];

//   int i = result.indexWhere((element) => element.id == id);
//   if (i >= 0) {
//     result.removeAt(i);
//   }

//   if (kIsWeb) {
//     return {"data": result, "count": result.length};
//   } else {
//     SendPort port = args[0];
//     Isolate.exit(port, {"data": result, "count": result.length});
//   }
// }

/// Find List DataItem
dynamic _listDataItemFind(List<dynamic> args) {
  Map<String, DataItem> raw = Map<String, DataItem>.from(args[1]);
  List<DataFilter>? filters = args[2];
  List<DataSort>? sorts = args[3];
  DataSearch? search = args[4];

  List<DataItem> result = raw.entries.map((entry) => entry.value).toList();

  if (filters != null) {
    result = result.filterData(filters);
  }
  if (sorts != null) {
    result = result.sortData(sorts);
  }
  if (search != null) {
    result = result.searchData(search);
  }
  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Convert List<DataItem> to json
// dynamic _listDataItemToJson(List<dynamic> args) {
//   // _log('_listDataItemModelToJson start');
//   String result = jsonEncode(
//     (args[1] as List<DataItem>).map((e) => e.toMap()).toList(),
//     toEncodable: (_) {
//       if (_ is DateTime) {
//         return DateTimeUtils.toDateTime(_).toString();
//       } else {
//         return "";
//       }
//     },
//   );
//   // _log('${result.length}');
//   if (kIsWeb) {
//     return EncryptUtil().encript(result);
//   } else {
//     SendPort port = args[0];
//     Isolate.exit(port, EncryptUtil().encript(result));
//   }
// }

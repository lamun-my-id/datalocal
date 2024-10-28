import 'dart:convert';

import 'package:datalocal/datalocal.dart';
import 'package:datalocal/src/extensions/list_data_item.dart';
import 'package:datalocal/src/models/data_compute.dart';
// import 'package:datalocal/utils/date_time.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
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

  int get sequence => _container.seq;

  late DataContainer _container;

  // List<DataItem> _data = [];
  // List<DataItem> get data => _data;

  late String _name;

  Map<String, DataItem> _raw = {};
  Map<String, DataItem> get raw => _raw;

  /// Log DataLocal used on debugMode
  _log(dynamic arg) async {
    if (_debugMode) {
      debugPrint('DataLocal (Debug):[$stateName]> ${arg.toString()}');
    }
  }

  // Function
  /// Used to initialize DataLocal
  _initialize() async {
    try {
      await initializeDateFormatting();
    } catch (e) {
      // print("Error initialize date time");
      //
    }
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
            seq: 0,
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
    for (String id in _container.ids) {
      await prefs.remove(EncryptUtil().encript(id));
      // _raw.remove(id);
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

  Future<DataItem?> get(String id) async {
    // _log('findAsync Isolate.spawn');
    return _raw[id];
  }

  /// Find More Efective Data with this function
  Future<DataQuery> find({
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    DataSearch? search,
    DataPaginate? paginate,
  }) async {
    // _log('findAsync Isolate.spawn');
    Map<String, dynamic> res = {};
    try {
      res = await DataCompute().isolate((args) async {
        Map<String, DataItem> raw = Map<String, DataItem>.from(args[0]);
        List<DataFilter>? filters = args[1];
        List<DataSort>? sorts = args[2];
        DataSearch? search = args[3];
        DataPaginate? paginate = args[4];

        List<DataItem> data = raw.entries.map((entry) => entry.value).toList();

        if (filters != null) {
          data = data.filterData(filters);
        }
        if (sorts != null) {
          data = data.sortData(sorts);
        }
        if (search != null) {
          data = data.searchData(search);
        }
        Map<String, dynamic> result = {};
        result['count'] = data.length;
        if (paginate != null) {
          try {
            result['page'] = paginate.page;
            result['pageSize'] = paginate.size;
            data = data.paginate(paginate);
          } catch (e) {
            //
          }
        }
        result['length'] = data.length;
        result['data'] = data;
        return result;
      }, args: [_raw, filters, sorts, search, paginate]);
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }
    return DataQuery(
      data: res['data'],
      length: res['length'],
      count: res['count'],
      page: res['page'],
      pageSize: res['pageSize'],
    );
  }

  /// Insert and save DataItem
  Future<DataItem> insertOne(Map<String, dynamic> value, {String? id}) async {
    _container.seq++;
    DataItem newData = DataItem.create(
      id ??
          EncryptUtil()
              .encript(DateTime.now().toString() + _container.seq.toString()),
      value: value,
      name: stateName,
      parent: "",
      seq: _container.seq,
    );
    try {
      _raw[newData.id] = newData;
      refresh();
      await newData.save({});
      _container.ids.add(newData.path());
      _container.lastDataCreatedAt = newData.createdAt;
      _count = _container.ids.length;
      await _saveState();
    } catch (e) {
      _log("error disini");
      //
    }
    return newData;
  }

  Future<void> insertMany(List<Map<String, dynamic>> values) async {
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    List<dynamic> args = await DataCompute().isolate((_) async {
      List<Map<String, dynamic>> values = _[0];
      Map<String, DataItem> raw = _[1];
      DataContainer container = _[2];
      int count = _[3];
      // SharedPreferences prefs = _[4];
      // String _count = _[3];
      // await Future.delayed(Duration(seconds: 2));

      List<String> ids = [];
      // print("Terdapat ${values.length} data yang diinputkan");
      for (int index = 0; index < values.length; index++) {
        // print("Data input ${index + 1} dari ${values.length}");
        Map<String, dynamic> value = values[index];
        container.seq++;
        DataItem newData = DataItem.create(
          EncryptUtil()
              .encript(DateTime.now().toString() + container.seq.toString()),
          value: value,
          name: container.name,
          parent: "",
          seq: container.seq,
        );
        try {
          ids.add(newData.id);
          raw[newData.id] = newData;
          // await newData.save({}, );
          container.ids.add(newData.path());
          container.lastDataCreatedAt = newData.createdAt;
          count = container.ids.length;
        } catch (e) {
          //
        }
      }
      return [container, raw, count, ids];
    }, args: [values, _raw, _container, _count]);
    _container = args[0];
    _raw = args[1];
    _count = args[2];
    List<String> ids = args[3];
    for (String id in ids) {
      await _raw[id]?.save({});
    }
    try {
      refresh();
      await _saveState();
    } catch (e) {
      _log("error disini");
      //
    }
  }

  /// Update to save DataItem
  Future<DataItem> updateOne(String id,
      {required Map<String, dynamic> value}) async {
    try {
      _count = _container.ids.length;
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    await _raw[id]!.save(value);
    _container.lastDataUpdatedAt = _raw[id]?.updatedAt;
    refresh();
    _saveState();
    return _raw[id]!;
  }

  /// Deletion DataItem
  Future<void> removeOne(String id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      DataItem? d = _raw[id];
      if (d == null) {
        throw "Data with id $id, not found";
      }
      _raw.remove(id);
      _container.ids.remove(id);
      _count = _container.ids.length;
      await prefs.remove(EncryptUtil().encript(d.path()));
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    _saveState();
  }

  Future<void> removeMany(List<String> ids) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      for (String id in ids) {
        DataItem? d = _raw['id'];
        if (d == null) {
          throw "Data with id $id, not found";
        }
        _raw.remove(id);
        _container.ids.remove(id);
        _count = _container.ids.length;
        await prefs.remove(EncryptUtil().encript(d.path()));
      }
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

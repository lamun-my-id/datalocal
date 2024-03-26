import 'dart:convert';
import 'dart:isolate';

import 'package:data_state/src/extensions/list_data_item.dart';
import 'package:data_state/src/models/data_filter.dart';
import 'package:data_state/src/models/data_item.dart';
import 'package:data_state/src/models/data_search.dart';
import 'package:data_state/src/models/data_sort.dart';
import 'package:data_state/utils/date_time.dart';
import 'package:data_state/utils/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataState {
  final String stateName;
  final List<DataFilter>? filters;
  final List<DataSort>? sorts;
  Function()? onRefresh;
  final bool debugMode;

  DataState(
    this.stateName, {
    this.filters,
    this.sorts,
    this.onRefresh,
    this.debugMode = false,
  });

  // Static Func
  static Future<DataState> create(
    String stateName, {
    List<DataFilter> filters = const [],
    List<DataSort> sorts = const [],
    Function()? onRefresh,
    bool? debugMode,
  }) async {
    DataState result = DataState(
      stateName,
      filters: filters,
      sorts: sorts,
      onRefresh: onRefresh,
      debugMode: debugMode ?? false,
    );
    await result._initialize();
    return result;
  }

  // Local Variable
  bool isInit = false;
  bool isLoading = false;
  int count = 0;
  int? searchCount;
  List<DataItem> data = [];
  List<DataItem>? search;
  late DateTime lastNewestCheck;
  late DateTime lastUpdateCheck;
  // Local Variable Private
  late String _name;
  int size = 200;

  _log(dynamic arg) async {
    if (debugMode) {
      debugPrint('DataState (Debug): ${arg.toString()}');
    }
  }

  // Function
  _initialize() async {
    try {
      try {
        initializeDateFormatting();
      } catch (e) {}
      _name = EncryptUtil().encript(
        "DataState-$stateName",
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
          data = [];
          throw "tidak ada state (${EncryptUtil().encript("$_name-0")})";
        }
        try {
          if (kIsWeb) {
            Map<String, dynamic> value = _jsonToListDataItem([null, res]);
            data.addAll(value['data']);
            count = data.length;
          } else {
            ReceivePort rPort = ReceivePort();
            await Isolate.spawn(_jsonToListDataItem, [rPort.sendPort, res]);
            Map<String, dynamic> value = await rPort.first;
            data.addAll(value['data']);
            count = data.length;
            rPort.close();
          }
          isInit = true;
          refresh();
        } catch (e) {
          _log("initialize error(3) : $e");
          //
        }
        count = data.length;
        if (count == 0 || count == size) {
          _loadState();
        }
      } catch (e) {
        _log("initialize error(2)#$stateName : $e");
      }
      isInit = true;
      refresh();
    } catch (e) {
      _log("initialize error(1) : $e");
      //
    }
  }

  Future<void> _saveState() async {
    isLoading = true;
    refresh();
    int loop = (count / size).ceil();
    _log('state akan dibuat ${loop + 1} ($count/$size)');
    for (int i = 0; i < loop; i++) {
      _log("start savestate number : ${i + 1}");
      SharedPreferences prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        try {
          if (kIsWeb) {
            String res = _listDataItemToJson(
                [null, data.skip(i * size).take(size).toList()]);
            // _log((await rPort.first as String).length);
            prefs.setString(EncryptUtil().encript("$_name-$i"), res);
          } else {
            ReceivePort rPort = ReceivePort();
            _log("Isolate spawn");
            await Isolate.spawn(_listDataItemToJson,
                [rPort.sendPort, data.skip(i * size).take(size).toList()]);
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
    isLoading = false;
    refresh();
  }

  Future<void> _loadState() async {
    // _log("start loadstate");
    isLoading = true;
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
    data = result;
    count = data.length;
    data = await find(sorts: sorts);
    isLoading = false;
    refresh();
  }

  Future<void> _deleteState() async {
    isLoading = true;
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
    data = result;
    count = data.length;
    data = await find(sorts: sorts);
    isLoading = false;
    refresh();
  }

  refresh() {
    if (onRefresh != null) {
      _log("refresh berjalan");
      onRefresh!();
    } else {
      _log("tidak ada refresh");
    }
  }

  void dispose() {}

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

  Future<DataItem> insertOne(Map<String, dynamic> value) async {
    String id = EncryptUtil().encript(
        DateTimeUtils.dateFormat(DateTime.now(), format: 'yyyyMMddhhmmss') ??
            "");
    _log(id);
    DataItem newData = DataItem(
      id: id,
      data: value,
      parent: stateName,
    );
    try {
      data.insert(0, newData);
      refresh();
      find(sorts: sorts).then((value) async {
        data = value;
        count = data.length;
        refresh();
        _log("start save state");
        await _saveState();
        _log("start save berhasil");
      });
    } catch (e) {
      _log("error disini");
      //
    }
    return newData;
  }

  Future<DataItem> updateOne(String id, Map<String, dynamic> value) async {
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
      data = res['data'];
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

  Future<void> reboot() async {
    await _deleteState();
    data.clear();
    await _initialize();
  }
}

dynamic _listDataItemAddUpdate(List<dynamic> args) {
  // _log('_listDataItemAddUpdate start');
  List<DataItem> result = args[1];
  DataItem newData = args[2];

  int index = result.indexWhere((element) => element.id == newData.id);
  if (index >= 0) {
    result[index] = newData;
  } else {
    result.insert(0, newData);
  }
  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

dynamic _jsonToListDataItem(List<dynamic> args) {
  // _log('_jsonToListDataItem start');
  try {
    List<DataItem> result = List<Map<String, dynamic>>.from(
            jsonDecode(EncryptUtil().decript(args[1])))
        .map((e) => DataItem.fromMap(e))
        .toList();
    int count = result.length;
    // _log(count.toString());
    if (kIsWeb) {
      return {"data": result, "count": count};
    } else {
      SendPort port = args[0];
      Isolate.exit(port, {"data": result, "count": count});
    }
  } catch (e) {
    print(args[1]);
  }
}

dynamic _listDataItemUpdate(List<dynamic> args) {
  List<DataItem> result = args[1];
  String id = args[2];
  Map<String, dynamic> update = args[3];

  int i = result.indexWhere((element) => element.id == id);
  if (i >= 0) {
    result[i].data = {...result[i].data, ...update};
  }

  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

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

dynamic _listDataItemToJson(List<dynamic> args) {
  // _log('_listDataItemModelToJson start');
  String result = jsonEncode(
    (args[1] as List<DataItem>)
        .map((e) => {"id": e.id, "data": e.data, "parent": e.parent})
        .toList(),
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

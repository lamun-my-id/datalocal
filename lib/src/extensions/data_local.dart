// ignore_for_file: no_wildcard_variable_uses

import 'package:datalocal/src/extensions/list_data_item.dart';
import 'package:datalocal/src/index.dart';
import 'package:datalocal/src/models/data_filter.dart';
import 'package:datalocal/src/models/data_query.dart';
import 'package:datalocal/src/models/data_sort.dart';

extension DataLocalExtensionQuery on DataLocal {
  /// Find More specific query Data with this function
  Future<List<DataItemRow>> execute(
    List<dynamic> selects, {
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    List<dynamic>? groups,
    int? limit,
  }) async {
    DataQuery query = await find(
      filters: filters,
      sorts: groups != null ? null : sorts,
    );
    List<DataItemRow> result = await query.data.execute(selects);
    return result;
  }
}

class DataItemRow {
  late Map<String, dynamic> _data;
  Map<String, dynamic> get data => _data;

  static DataItemRow fromMap(Map<String, dynamic> value) {
    DataItemRow row = DataItemRow();
    row._data = value;
    return row;
  }
}

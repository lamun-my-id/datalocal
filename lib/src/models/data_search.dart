import 'package:datalocal/src/models/data_item.dart';
import 'package:datalocal/src/models/data_key.dart';

class DataSearch {
  late List<DataKey>? keys;
  String? value;
  bool Function(DataItem)? builder;

  /// Used to search [DataLocal] data [keys] is list of the index that want to be search
  /// Used separated with dot '.' to sort data inside map variable
  DataSearch(List<Object> keys, {this.value, this.builder}) {
    this.keys = keys.map((key) {
      if (key is String) return DataKey(key);
      if (key is DataKey) return key;
      throw "Please fill key with String or DataKey value";
    }).toList();
  }
}

import 'package:datalocal/src/models/data_item.dart';
import 'package:datalocal/src/models/data_key.dart';

class DataSearch {
  List<DataKey>? keys;
  String? value;
  bool Function(DataItem)? builder;

  /// Used to search [DataLocal] data [keys] is list of the index that want to be search
  /// Used separated with dot '.' to sort data inside map variable
  DataSearch({this.keys, this.value, this.builder});
}

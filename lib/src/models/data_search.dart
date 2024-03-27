import 'package:datalocal/src/models/data_item.dart';

class DataSearch {
  List<String>? keys;
  String? value;
  bool Function(DataItem)? builder;

  /// Used to search [DataLocal] data [keys] is list of the index that want to be search
  /// Used separated with dot '.' to sort data inside map variable
  DataSearch({this.keys, this.value, this.builder});
}

import 'package:datalocal/src/models/data_item.dart';

class DataSearch {
  List<String>? keys;
  String? value;
  bool Function(DataItem)? builder;

  DataSearch({this.keys, this.value, this.builder});
}

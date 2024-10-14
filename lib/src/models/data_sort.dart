import 'package:datalocal/src/models/data_key.dart';

class DataSort {
  late DataKey key;
  String? as;
  bool desc;

  /// Used to sort [DataLocal] data [key] is the index
  /// Used separated with dot '.' to sort data inside map variable
  DataSort(
    Object key, {
    this.desc = true,
  }) {
    assert((key is String || key is DataKey),
        "Please fill key with String or DataKey value");
    if (key is String) this.key = DataKey(key);
    if (key is DataKey) this.key = key;
  }
}

import 'package:datalocal/src/models/data_key.dart';

class DataSort {
  DataKey key;
  String? as;
  bool desc;

  /// Used to sort [DataLocal] data [key] is the index
  /// Used separated with dot '.' to sort data inside map variable
  DataSort({
    required this.key,
    this.desc = true,
  });
}

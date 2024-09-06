import 'package:datalocal/datalocal.dart';

class DataQuery {
  List<DataItem> data;
  int length;
  int count;
  int? page;
  int? pageSize;
  DataQuery({
    required this.data,
    required this.length,
    required this.count,
    this.page,
    this.pageSize,
  });
}

import 'package:datalocal/src/document/datalocal_document.dart';
import 'package:datalocal/src/query/datalocal_query_cursor.dart';

final class DataLocalQuerySnapshot<T> {
  DataLocalQuerySnapshot({
    required List<DataLocalDocument<T>> documents,
    required this.totalCount,
    required this.cursor,
  }) : documents = List<DataLocalDocument<T>>.unmodifiable(documents);

  final List<DataLocalDocument<T>> documents;
  final int totalCount;
  final DataLocalQueryCursor? cursor;
}

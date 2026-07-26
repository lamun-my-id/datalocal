import 'package:datalocal/src/document/datalocal_document.dart';
import 'package:datalocal/src/query/datalocal_query_cursor.dart';

/// Immutable result produced by executing or watching a query.
final class DataLocalQuerySnapshot<T> {
  /// Creates a query result.
  DataLocalQuerySnapshot({
    required List<DataLocalDocument<T>> documents,
    required this.totalCount,
    required this.cursor,
  }) : documents = List<DataLocalDocument<T>>.unmodifiable(documents);

  /// Documents selected after cursor and limit processing.
  final List<DataLocalDocument<T>> documents;

  /// Number of matching documents before the query limit.
  final int totalCount;

  /// Cursor for continuing after the final selected document.
  final DataLocalQueryCursor? cursor;
}

import 'dart:async';

import 'package:datalocal/src/database/datalocal_collection.dart';
import 'package:datalocal/src/document/datalocal_document.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/query/datalocal_field_path.dart';
import 'package:datalocal/src/query/datalocal_query_cursor.dart';
import 'package:datalocal/src/query/datalocal_query_snapshot.dart';

const Object _unsetQueryValue = Object();

/// Operators supported by a [DataLocalFilter].
enum DataLocalFilterOperator {
  /// Matches a list field that contains the requested value.
  arrayContains,

  /// Matches values equal to the requested value.
  equal,

  /// Matches values greater than the requested value.
  greaterThan,

  /// Matches values greater than or equal to the requested value.
  greaterThanOrEqual,

  /// Matches values less than the requested value.
  lessThan,

  /// Matches values less than or equal to the requested value.
  lessThanOrEqual,

  /// Matches values that differ from the requested value.
  notEqual,

  /// Matches values contained in the requested list.
  whereIn,
}

/// An immutable field predicate used by [DataLocalQuery].
final class DataLocalFilter {
  /// Creates a predicate for [path].
  const DataLocalFilter({
    required this.path,
    required this.operator,
    required this.value,
  });

  /// Field path evaluated by this predicate.
  final DataLocalFieldPath path;

  /// Comparison performed against [value].
  final DataLocalFilterOperator operator;

  /// Operand supplied to [operator].
  final Object? value;
}

/// An immutable ordering clause used by [DataLocalQuery].
final class DataLocalOrder {
  /// Creates an ordering for [path].
  const DataLocalOrder({required this.path, required this.descending});

  /// Field path whose values are compared.
  final DataLocalFieldPath path;

  /// Whether larger values are returned before smaller values.
  final bool descending;

  /// Stable representation embedded in query cursors.
  String get signature => '${path.toString()}:${descending ? 'desc' : 'asc'}';
}

/// An immutable, lazily executed query over a DataLocal collection.
///
/// Filtering and sorting are currently evaluated in memory, so query cost
/// grows with the collection size.
final class DataLocalQuery<T> {
  DataLocalQuery._({
    required this._collection,
    required List<DataLocalFilter> filters,
    required List<DataLocalOrder> orders,
    required this._limit,
    required this._startAfter,
  }) : _filters = List<DataLocalFilter>.unmodifiable(filters),
       _orders = List<DataLocalOrder>.unmodifiable(orders),
       assert(_limit == null || _limit > 0);

  /// Creates an unfiltered query rooted at [collection].
  factory DataLocalQuery.root(DataLocalCollection<T> collection) =>
      DataLocalQuery<T>._(
        collection: collection,
        filters: const <DataLocalFilter>[],
        orders: const <DataLocalOrder>[],
        limit: null,
        startAfter: null,
      );

  final DataLocalCollection<T> _collection;
  final List<DataLocalFilter> _filters;
  final List<DataLocalOrder> _orders;
  final int? _limit;
  final DataLocalQueryCursor? _startAfter;

  /// Returns a query with one additional predicate for [path].
  ///
  /// Exactly one named operator must be supplied. Multiple calls are combined
  /// with logical AND.
  DataLocalQuery<T> where(
    String path, {
    Object? isEqualTo = _unsetQueryValue,
    Object? isNotEqualTo = _unsetQueryValue,
    Object? isGreaterThan = _unsetQueryValue,
    Object? isGreaterThanOrEqualTo = _unsetQueryValue,
    Object? isLessThan = _unsetQueryValue,
    Object? isLessThanOrEqualTo = _unsetQueryValue,
    Object? whereIn = _unsetQueryValue,
    Object? arrayContains = _unsetQueryValue,
  }) {
    final candidates = <(DataLocalFilterOperator, Object?)>[
      if (!identical(isEqualTo, _unsetQueryValue))
        (DataLocalFilterOperator.equal, isEqualTo),
      if (!identical(isNotEqualTo, _unsetQueryValue))
        (DataLocalFilterOperator.notEqual, isNotEqualTo),
      if (!identical(isGreaterThan, _unsetQueryValue))
        (DataLocalFilterOperator.greaterThan, isGreaterThan),
      if (!identical(isGreaterThanOrEqualTo, _unsetQueryValue))
        (DataLocalFilterOperator.greaterThanOrEqual, isGreaterThanOrEqualTo),
      if (!identical(isLessThan, _unsetQueryValue))
        (DataLocalFilterOperator.lessThan, isLessThan),
      if (!identical(isLessThanOrEqualTo, _unsetQueryValue))
        (DataLocalFilterOperator.lessThanOrEqual, isLessThanOrEqualTo),
      if (!identical(whereIn, _unsetQueryValue))
        (DataLocalFilterOperator.whereIn, whereIn),
      if (!identical(arrayContains, _unsetQueryValue))
        (DataLocalFilterOperator.arrayContains, arrayContains),
    ];
    if (candidates.length != 1) {
      throw const DataLocalValidationException(
        'where requires exactly one operator.',
        context: <String, Object?>{'field': 'where'},
      );
    }
    if (candidates.single.$1 == DataLocalFilterOperator.whereIn &&
        candidates.single.$2 is! List<Object?>) {
      throw const DataLocalValidationException(
        'whereIn requires a list value.',
        context: <String, Object?>{'field': 'whereIn'},
      );
    }
    return whereField(
      DataLocalFieldPath.parse(path),
      operator: candidates.single.$1,
      value: candidates.single.$2,
    );
  }

  /// Returns a query with [operator] applied to the parsed field [path].
  DataLocalQuery<T> whereField(
    DataLocalFieldPath path, {
    required DataLocalFilterOperator operator,
    required Object? value,
  }) => _copy(
    filters: <DataLocalFilter>[
      ..._filters,
      DataLocalFilter(path: path, operator: operator, value: value),
    ],
  );

  /// Returns a query ordered by the dot-separated field [path].
  DataLocalQuery<T> orderBy(String path, {bool descending = false}) =>
      orderByField(DataLocalFieldPath.parse(path), descending: descending);

  /// Returns a query ordered by the parsed field [path].
  DataLocalQuery<T> orderByField(
    DataLocalFieldPath path, {
    bool descending = false,
  }) => _copy(
    orders: <DataLocalOrder>[
      ..._orders,
      DataLocalOrder(path: path, descending: descending),
    ],
  );

  /// Restricts the result to at most [value] documents.
  DataLocalQuery<T> limit(int value) {
    if (value < 1) {
      throw const DataLocalValidationException(
        'Query limit must be at least one.',
        context: <String, Object?>{'field': 'limit'},
      );
    }
    return _copy(limit: value);
  }

  /// Returns only documents positioned after [cursor].
  DataLocalQuery<T> startAfter(DataLocalQueryCursor cursor) =>
      _copy(startAfter: cursor);

  /// Executes this query and returns a snapshot of matching documents.
  Future<DataLocalQuerySnapshot<T>> get() async {
    final allDocuments = await _collection.readAllForQuery();
    final matched = allDocuments.where(_matches).toList();
    _sort(matched);
    final totalCount = matched.length;
    final afterCursor = _applyCursor(matched);
    final selected = _limit == null
        ? afterCursor
        : afterCursor.take(_limit).toList(growable: false);
    return DataLocalQuerySnapshot<T>(
      documents: selected,
      totalCount: totalCount,
      cursor: selected.isEmpty ? null : _cursorFor(selected.last),
    );
  }

  /// Returns the number of matching documents before the result limit.
  Future<int> count() async => (await get()).totalCount;

  /// Sums numeric values at [path] in the selected result.
  Future<num> sum(String path) async {
    final snapshot = await get();
    num result = 0;
    final field = DataLocalFieldPath.parse(path);
    for (final document in snapshot.documents) {
      final value = field.read(_collection.encodeForQuery(document.data));
      if (value is! num) {
        throw DataLocalValidationException(
          'Aggregate field must contain numeric values.',
          context: <String, Object?>{'fieldPath': path},
        );
      }
      result += value;
    }
    return result;
  }

  /// Returns the mean for numeric values at [path], or `null` when empty.
  Future<double?> average(String path) async {
    final snapshot = await get();
    if (snapshot.documents.isEmpty) {
      return null;
    }
    return (await sum(path)) / snapshot.documents.length;
  }

  /// Emits the current query snapshot and then one snapshot per relevant commit.
  Stream<DataLocalQuerySnapshot<T>> watch() {
    late StreamController<DataLocalQuerySnapshot<T>> controller;
    StreamSubscription<Object?>? subscription;
    Future<void> tail = Future<void>.value();

    void enqueueSnapshot() {
      tail = tail.then((_) async {
        try {
          final snapshot = await get();
          if (!controller.isClosed) {
            controller.add(snapshot);
          }
        } catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      });
    }

    controller = StreamController<DataLocalQuerySnapshot<T>>(
      onListen: () {
        subscription = _collection.changes.listen(
          (_) => enqueueSnapshot(),
          onError: controller.addError,
          onDone: () {
            tail.whenComplete(() {
              if (!controller.isClosed) {
                controller.close();
              }
            });
          },
        );
        enqueueSnapshot();
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  bool _matches(DataLocalDocument<T> document) {
    final data = _collection.encodeForQuery(document.data);
    for (final filter in _filters) {
      final actual = filter.path.read(data);
      if (!_evaluate(actual, filter)) {
        return false;
      }
    }
    return true;
  }

  bool _evaluate(Object? actual, DataLocalFilter filter) {
    if (actual is DataLocalMissingField) {
      return false;
    }
    return switch (filter.operator) {
      DataLocalFilterOperator.equal => actual == filter.value,
      DataLocalFilterOperator.notEqual => actual != filter.value,
      DataLocalFilterOperator.greaterThan => _compare(actual, filter.value) > 0,
      DataLocalFilterOperator.greaterThanOrEqual =>
        _compare(actual, filter.value) >= 0,
      DataLocalFilterOperator.lessThan => _compare(actual, filter.value) < 0,
      DataLocalFilterOperator.lessThanOrEqual =>
        _compare(actual, filter.value) <= 0,
      DataLocalFilterOperator.whereIn =>
        (filter.value! as List<Object?>).contains(actual),
      DataLocalFilterOperator.arrayContains =>
        actual is List<Object?> && actual.contains(filter.value),
    };
  }

  void _sort(List<DataLocalDocument<T>> documents) {
    documents.sort((left, right) {
      final leftData = _collection.encodeForQuery(left.data);
      final rightData = _collection.encodeForQuery(right.data);
      for (final order in _orders) {
        final comparison = _compare(
          order.path.read(leftData),
          order.path.read(rightData),
        );
        if (comparison != 0) {
          return order.descending ? -comparison : comparison;
        }
      }
      return left.id.compareTo(right.id);
    });
  }

  List<DataLocalDocument<T>> _applyCursor(
    List<DataLocalDocument<T>> documents,
  ) {
    final cursor = _startAfter;
    if (cursor == null) {
      return documents;
    }
    final signature = _orders.map((order) => order.signature).toList();
    if (!_listEquals(cursor.orderSignature, signature)) {
      throw const DataLocalValidationException(
        'Cursor does not belong to this query ordering.',
        context: <String, Object?>{'field': 'cursor'},
      );
    }
    if (cursor.orderValues.length != _orders.length) {
      throw const DataLocalValidationException(
        'Cursor values do not match the query ordering.',
        context: <String, Object?>{'field': 'cursor'},
      );
    }
    return documents
        .where((document) => _compareDocumentToCursor(document, cursor) > 0)
        .toList(growable: false);
  }

  int _compareDocumentToCursor(
    DataLocalDocument<T> document,
    DataLocalQueryCursor cursor,
  ) {
    final data = _collection.encodeForQuery(document.data);
    for (var index = 0; index < _orders.length; index++) {
      final order = _orders[index];
      final comparison = _compare(
        order.path.read(data),
        cursor.orderValues[index],
      );
      if (comparison != 0) {
        return order.descending ? -comparison : comparison;
      }
    }
    return document.id.compareTo(cursor.documentId);
  }

  DataLocalQueryCursor _cursorFor(DataLocalDocument<T> document) {
    final data = _collection.encodeForQuery(document.data);
    return DataLocalQueryCursor(
      documentId: document.id,
      orderValues: _orders
          .map((order) => order.path.read(data))
          .toList(growable: false),
      orderSignature: _orders
          .map((order) => order.signature)
          .toList(growable: false),
    );
  }

  int _compare(Object? left, Object? right) {
    if (left is DataLocalMissingField || right is DataLocalMissingField) {
      if (left is DataLocalMissingField && right is DataLocalMissingField) {
        return 0;
      }
      return left is DataLocalMissingField ? -1 : 1;
    }
    if (left == null || right == null) {
      if (left == null && right == null) {
        return 0;
      }
      return left == null ? -1 : 1;
    }
    if (left is num && right is num) {
      return left.compareTo(right);
    }
    if (left is String && right is String) {
      return left.compareTo(right);
    }
    if (left is bool && right is bool) {
      return left == right ? 0 : (left ? 1 : -1);
    }
    throw DataLocalValidationException(
      'Values are not comparable.',
      context: <String, Object?>{
        'leftType': left.runtimeType.toString(),
        'rightType': right.runtimeType.toString(),
      },
    );
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  DataLocalQuery<T> _copy({
    List<DataLocalFilter>? filters,
    List<DataLocalOrder>? orders,
    int? limit,
    DataLocalQueryCursor? startAfter,
  }) => DataLocalQuery<T>._(
    collection: _collection,
    filters: filters ?? _filters,
    orders: orders ?? _orders,
    limit: limit ?? _limit,
    startAfter: startAfter ?? _startAfter,
  );
}

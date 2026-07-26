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

  /// Matches a list field containing at least one requested value.
  arrayContainsAny,

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

  /// Matches fields whose value is `null`.
  isNull,

  /// Matches fields whose value is not `null`.
  isNotNull,

  /// Matches values contained in the requested list.
  whereIn,

  /// Matches values not contained in the requested list.
  whereNotIn,
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

/// Controls where null and missing values appear in an ordered query.
enum DataLocalNullOrder {
  /// Preserve the natural order: first ascending and last descending.
  automatic,

  /// Place null and missing values before non-null values.
  first,

  /// Place null and missing values after non-null values.
  last,
}

/// An immutable ordering clause used by [DataLocalQuery].
final class DataLocalOrder {
  /// Creates an ordering for [path].
  const DataLocalOrder({
    required this.path,
    required this.descending,
    this.nullOrder = DataLocalNullOrder.automatic,
  });

  /// Field path whose values are compared.
  final DataLocalFieldPath path;

  /// Whether larger values are returned before smaller values.
  final bool descending;

  /// Placement of null and missing values.
  final DataLocalNullOrder nullOrder;

  /// Stable representation embedded in query cursors.
  String get signature =>
      '${path.toString()}:${descending ? 'desc' : 'asc'}:${nullOrder.name}';
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
    required this._limitToLast,
    required this._startCursor,
    required this._startInclusive,
    required this._endCursor,
    required this._endInclusive,
    required List<List<DataLocalFilter>> anyFilterGroups,
  }) : _filters = List<DataLocalFilter>.unmodifiable(filters),
       _orders = List<DataLocalOrder>.unmodifiable(orders),
       _anyFilterGroups = List<List<DataLocalFilter>>.unmodifiable(
         anyFilterGroups.map(List<DataLocalFilter>.unmodifiable),
       ),
       assert(_limit == null || _limit > 0);

  /// Creates an unfiltered query rooted at [collection].
  factory DataLocalQuery.root(DataLocalCollection<T> collection) =>
      DataLocalQuery<T>._(
        collection: collection,
        filters: const <DataLocalFilter>[],
        orders: const <DataLocalOrder>[],
        limit: null,
        limitToLast: false,
        startCursor: null,
        startInclusive: false,
        endCursor: null,
        endInclusive: false,
        anyFilterGroups: const <List<DataLocalFilter>>[],
      );

  final DataLocalCollection<T> _collection;
  final List<DataLocalFilter> _filters;
  final List<List<DataLocalFilter>> _anyFilterGroups;
  final List<DataLocalOrder> _orders;
  final int? _limit;
  final bool _limitToLast;
  final DataLocalQueryCursor? _startCursor;
  final bool _startInclusive;
  final DataLocalQueryCursor? _endCursor;
  final bool _endInclusive;

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
    Object? whereNotIn = _unsetQueryValue,
    Object? arrayContains = _unsetQueryValue,
    Object? arrayContainsAny = _unsetQueryValue,
    Object? isNull = _unsetQueryValue,
    Object? isNotNull = _unsetQueryValue,
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
      if (!identical(whereNotIn, _unsetQueryValue))
        (DataLocalFilterOperator.whereNotIn, whereNotIn),
      if (!identical(arrayContains, _unsetQueryValue))
        (DataLocalFilterOperator.arrayContains, arrayContains),
      if (!identical(arrayContainsAny, _unsetQueryValue))
        (DataLocalFilterOperator.arrayContainsAny, arrayContainsAny),
      if (!identical(isNull, _unsetQueryValue))
        (DataLocalFilterOperator.isNull, isNull),
      if (!identical(isNotNull, _unsetQueryValue))
        (DataLocalFilterOperator.isNotNull, isNotNull),
    ];
    if (candidates.length != 1) {
      throw const DataLocalValidationException(
        'where requires exactly one operator.',
        context: <String, Object?>{'field': 'where'},
      );
    }
    final operator = candidates.single.$1;
    if ((operator == DataLocalFilterOperator.whereIn ||
            operator == DataLocalFilterOperator.whereNotIn ||
            operator == DataLocalFilterOperator.arrayContainsAny) &&
        candidates.single.$2 is! List<Object?>) {
      throw const DataLocalValidationException(
        'This query operator requires a list value.',
        context: <String, Object?>{'field': 'where'},
      );
    }
    if ((operator == DataLocalFilterOperator.isNull ||
            operator == DataLocalFilterOperator.isNotNull) &&
        candidates.single.$2 != true) {
      throw const DataLocalValidationException(
        'Null predicates must be enabled with true.',
        context: <String, Object?>{'field': 'where'},
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
  }) {
    final filter = DataLocalFilter(
      path: path,
      operator: operator,
      value: value,
    );
    _validateFilter(filter);
    return _copy(filters: <DataLocalFilter>[..._filters, filter]);
  }

  /// Adds an OR group; at least one supplied filter must match.
  ///
  /// The group is combined with existing filters and groups using logical AND.
  DataLocalQuery<T> whereAny(Iterable<DataLocalFilter> filters) {
    final group = List<DataLocalFilter>.unmodifiable(filters);
    if (group.isEmpty) {
      throw const DataLocalValidationException(
        'whereAny requires at least one filter.',
        context: <String, Object?>{'field': 'whereAny'},
      );
    }
    for (final filter in group) {
      _validateFilter(filter);
    }
    return _copy(
      anyFilterGroups: <List<DataLocalFilter>>[..._anyFilterGroups, group],
    );
  }

  /// Returns a query ordered by the dot-separated field [path].
  DataLocalQuery<T> orderBy(
    String path, {
    bool descending = false,
    DataLocalNullOrder nullOrder = DataLocalNullOrder.automatic,
  }) => orderByField(
    DataLocalFieldPath.parse(path),
    descending: descending,
    nullOrder: nullOrder,
  );

  /// Returns a query ordered by the parsed field [path].
  DataLocalQuery<T> orderByField(
    DataLocalFieldPath path, {
    bool descending = false,
    DataLocalNullOrder nullOrder = DataLocalNullOrder.automatic,
  }) => _copy(
    orders: <DataLocalOrder>[
      ..._orders,
      DataLocalOrder(path: path, descending: descending, nullOrder: nullOrder),
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
    return _copy(limit: value, limitToLast: false);
  }

  /// Restricts the result to the final [value] documents.
  DataLocalQuery<T> limitToLast(int value) {
    if (value < 1) {
      throw const DataLocalValidationException(
        'Query limit must be at least one.',
        context: <String, Object?>{'field': 'limitToLast'},
      );
    }
    return _copy(limit: value, limitToLast: true);
  }

  /// Returns documents positioned at or after [cursor].
  DataLocalQuery<T> startAt(DataLocalQueryCursor cursor) =>
      _copy(startCursor: cursor, startInclusive: true);

  /// Returns only documents positioned after [cursor].
  DataLocalQuery<T> startAfter(DataLocalQueryCursor cursor) =>
      _copy(startCursor: cursor, startInclusive: false);

  /// Returns documents positioned at or before [cursor].
  DataLocalQuery<T> endAt(DataLocalQueryCursor cursor) =>
      _copy(endCursor: cursor, endInclusive: true);

  /// Returns only documents positioned before [cursor].
  DataLocalQuery<T> endBefore(DataLocalQueryCursor cursor) =>
      _copy(endCursor: cursor, endInclusive: false);

  /// Executes this query and returns a snapshot of matching documents.
  Future<DataLocalQuerySnapshot<T>> get() async {
    final allDocuments = await _collection.readAllForQuery();
    final matched = allDocuments.where(_matches).toList();
    _sort(matched);
    final totalCount = matched.length;
    final afterCursor = _applyCursors(matched);
    final selected = _limit == null
        ? afterCursor
        : _limitToLast
        ? afterCursor
              .skip(
                afterCursor.length > _limit ? afterCursor.length - _limit : 0,
              )
              .toList(growable: false)
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
    for (final group in _anyFilterGroups) {
      if (!group.any((filter) => _evaluate(filter.path.read(data), filter))) {
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
      DataLocalFilterOperator.whereNotIn =>
        !(filter.value! as List<Object?>).contains(actual),
      DataLocalFilterOperator.arrayContains =>
        actual is List<Object?> && actual.contains(filter.value),
      DataLocalFilterOperator.arrayContainsAny =>
        actual is List<Object?> &&
            (filter.value! as List<Object?>).any(actual.contains),
      DataLocalFilterOperator.isNull => actual == null,
      DataLocalFilterOperator.isNotNull => actual != null,
    };
  }

  void _validateFilter(DataLocalFilter filter) {
    if ((filter.operator == DataLocalFilterOperator.whereIn ||
            filter.operator == DataLocalFilterOperator.whereNotIn ||
            filter.operator == DataLocalFilterOperator.arrayContainsAny) &&
        filter.value is! List<Object?>) {
      throw const DataLocalValidationException(
        'This query operator requires a list value.',
        context: <String, Object?>{'field': 'filter.value'},
      );
    }
    if ((filter.operator == DataLocalFilterOperator.isNull ||
            filter.operator == DataLocalFilterOperator.isNotNull) &&
        filter.value != true) {
      throw const DataLocalValidationException(
        'Null predicates must be enabled with true.',
        context: <String, Object?>{'field': 'filter.value'},
      );
    }
  }

  void _sort(List<DataLocalDocument<T>> documents) {
    documents.sort((left, right) {
      final leftData = _collection.encodeForQuery(left.data);
      final rightData = _collection.encodeForQuery(right.data);
      for (final order in _orders) {
        final comparison = _compareForOrder(
          order.path.read(leftData),
          order.path.read(rightData),
          order,
        );
        if (comparison != 0) {
          return order.descending ? -comparison : comparison;
        }
      }
      return left.id.compareTo(right.id);
    });
  }

  List<DataLocalDocument<T>> _applyCursors(
    List<DataLocalDocument<T>> documents,
  ) {
    final start = _startCursor;
    final end = _endCursor;
    if (start == null && end == null) {
      return documents;
    }
    if (start != null) {
      _validateCursor(start);
    }
    if (end != null) {
      _validateCursor(end);
    }
    return documents
        .where((document) {
          if (start != null) {
            final comparison = _compareDocumentToCursor(document, start);
            if (_startInclusive ? comparison < 0 : comparison <= 0) {
              return false;
            }
          }
          if (end != null) {
            final comparison = _compareDocumentToCursor(document, end);
            if (_endInclusive ? comparison > 0 : comparison >= 0) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  void _validateCursor(DataLocalQueryCursor cursor) {
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
  }

  int _compareDocumentToCursor(
    DataLocalDocument<T> document,
    DataLocalQueryCursor cursor,
  ) {
    final data = _collection.encodeForQuery(document.data);
    for (var index = 0; index < _orders.length; index++) {
      final order = _orders[index];
      final comparison = _compareForOrder(
        order.path.read(data),
        cursor.orderValues[index],
        order,
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

  int _compareForOrder(Object? left, Object? right, DataLocalOrder order) {
    final leftNullish = left == null || left is DataLocalMissingField;
    final rightNullish = right == null || right is DataLocalMissingField;
    if (leftNullish != rightNullish &&
        order.nullOrder != DataLocalNullOrder.automatic) {
      final desired = order.nullOrder == DataLocalNullOrder.first
          ? (leftNullish ? -1 : 1)
          : (leftNullish ? 1 : -1);
      return order.descending ? -desired : desired;
    }
    return _compare(left, right);
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
    List<List<DataLocalFilter>>? anyFilterGroups,
    List<DataLocalOrder>? orders,
    int? limit,
    bool? limitToLast,
    DataLocalQueryCursor? startCursor,
    bool? startInclusive,
    DataLocalQueryCursor? endCursor,
    bool? endInclusive,
  }) => DataLocalQuery<T>._(
    collection: _collection,
    filters: filters ?? _filters,
    anyFilterGroups: anyFilterGroups ?? _anyFilterGroups,
    orders: orders ?? _orders,
    limit: limit ?? _limit,
    limitToLast: limitToLast ?? _limitToLast,
    startCursor: startCursor ?? _startCursor,
    startInclusive: startInclusive ?? _startInclusive,
    endCursor: endCursor ?? _endCursor,
    endInclusive: endInclusive ?? _endInclusive,
  );
}

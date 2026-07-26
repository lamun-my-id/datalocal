import 'dart:async';

import 'package:datalocal/datalocal.dart';
import 'package:flutter/material.dart';

typedef DataLocalDatabaseFactory = Future<DataLocalDatabase> Function();

class QueryPlaygroundPage extends StatefulWidget {
  const QueryPlaygroundPage({required this.databaseFactory, super.key});

  final DataLocalDatabaseFactory databaseFactory;

  @override
  State<QueryPlaygroundPage> createState() => _QueryPlaygroundPageState();
}

class _QueryPlaygroundPageState extends State<QueryPlaygroundPage> {
  static const _collectionName = 'query_playground_products';
  static const _seedSizes = <int>[10, 1000, 10000];
  static const _categories = <String>[
    'food',
    'tech',
    'books',
    'home',
    'sports',
  ];

  DataLocalDatabase? _database;
  DataLocalCollection<Map<String, Object?>>? _products;
  final List<QueryRunResult> _results = <QueryRunResult>[];
  Object? _error;
  bool _busy = false;
  String _status = 'Opening encrypted database…';
  int _documentCount = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final database = await widget.databaseFactory();
      final products = database.mapCollection(_collectionName);
      final count = await products.query().count();
      if (!mounted) {
        await database.close();
        return;
      }
      setState(() {
        _database = database;
        _products = products;
        _documentCount = count;
        _status = 'Ready';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _seed(int count) => _runBusy(() async {
    final products = _products!;
    setState(() {
      _results.clear();
      _status = 'Clearing previous dataset…';
    });
    await products.clear();

    const chunkSize = 100;
    final watch = Stopwatch()..start();
    for (var start = 0; start < count; start += chunkSize) {
      final end = start + chunkSize < count ? start + chunkSize : count;
      await _database!.writeBatch((batch) {
        for (var index = start; index < end; index++) {
          batch.insert(
            products,
            _product(index),
            id: 'product-${index.toString().padLeft(5, '0')}',
          );
        }
      });
      if (mounted) {
        setState(() {
          _documentCount = end;
          _status = 'Seeding $end / $count documents…';
        });
      }
      await Future<void>.delayed(Duration.zero);
    }
    watch.stop();
    setState(() {
      _documentCount = count;
      _status = 'Seeded $count documents in ${watch.elapsedMilliseconds} ms';
    });
  });

  Future<void> _clear() => _runBusy(() async {
    await _products!.clear();
    setState(() {
      _documentCount = 0;
      _results.clear();
      _status = 'Dataset cleared';
    });
  });

  Future<void> _runAll() => _runBusy(() async {
    if (_documentCount == 0) {
      throw const DataLocalValidationException(
        'Seed a dataset before running queries.',
      );
    }
    setState(() => _results.clear());
    for (var index = 0; index < _scenarios.length; index++) {
      final scenario = _scenarios[index];
      setState(
        () => _status =
            'Running ${index + 1}/${_scenarios.length}: ${scenario.name}',
      );
      final result = await scenario.run(_products!);
      if (mounted) setState(() => _results.add(result));
      await Future<void>.delayed(Duration.zero);
    }
    setState(() => _status = 'Completed ${_scenarios.length} scenarios');
  });

  Future<void> _runScenario(QueryScenario scenario) => _runBusy(() async {
    if (_documentCount == 0) {
      throw const DataLocalValidationException(
        'Seed a dataset before running queries.',
      );
    }
    setState(() => _status = 'Running ${scenario.name}…');
    final result = await scenario.run(_products!);
    setState(() {
      _results.removeWhere((item) => item.name == result.name);
      _results.insert(0, result);
      _status = '${scenario.name} completed';
    });
  });

  Future<void> _runBusy(Future<void> Function() operation) async {
    if (_busy || _products == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _status = 'Operation failed';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, Object?> _product(int index) {
    final category = _categories[index % _categories.length];
    return <String, Object?>{
      'index': index,
      'name': 'Product ${index.toString().padLeft(5, '0')}',
      'category': category,
      'price': ((index * 17) % 1000) + 1,
      'rating': index % 7 == 0 ? null : (index % 5) + 1,
      'active': index.isEven,
      'tags': <Object?>[
        category,
        if (index % 10 == 0) 'popular',
        if (index % 13 == 0) 'sale',
      ],
      'owner': <String, Object?>{
        'id': 'user-${index % 20}',
        'region': <String>['asia', 'europe', 'america'][index % 3],
      },
    };
  }

  List<QueryScenario> get _scenarios => <QueryScenario>[
    QueryScenario.query(
      'Equal + nested path',
      'category = tech AND owner.region = asia',
      (products) => products
          .query()
          .where('category', isEqualTo: 'tech')
          .where('owner.region', isEqualTo: 'asia')
          .orderBy('index')
          .limit(20),
    ),
    QueryScenario.query(
      'Range + multi-sort',
      'price 250…750, price DESC then name ASC',
      (products) => products
          .query()
          .where('price', isGreaterThanOrEqualTo: 250)
          .where('price', isLessThanOrEqualTo: 750)
          .orderBy('price', descending: true)
          .orderBy('name')
          .limit(20),
    ),
    QueryScenario.query(
      'whereIn',
      'category IN [tech, books]',
      (products) => products
          .query()
          .where('category', whereIn: <Object?>['tech', 'books'])
          .orderBy('index')
          .limit(20),
    ),
    QueryScenario.query(
      'whereNotIn',
      'category NOT IN [food, home]',
      (products) => products
          .query()
          .where('category', whereNotIn: <Object?>['food', 'home'])
          .orderBy('index')
          .limit(20),
    ),
    QueryScenario.query(
      'Array operators',
      'tags contains any [popular, sale]',
      (products) => products
          .query()
          .where('tags', arrayContainsAny: <Object?>['popular', 'sale'])
          .orderBy('index')
          .limit(20),
    ),
    QueryScenario.query(
      'Explicit null',
      'rating IS NULL, nulls last sort',
      (products) => products
          .query()
          .where('rating', isNull: true)
          .orderBy('rating', nullOrder: DataLocalNullOrder.last)
          .orderBy('index')
          .limit(20),
    ),
    QueryScenario.query(
      'AND + OR group',
      'active = true AND (category = tech OR rating = 5)',
      (products) => products
          .query()
          .where('active', isEqualTo: true)
          .whereAny(<DataLocalFilter>[
            DataLocalFilter(
              path: DataLocalFieldPath.parse('category'),
              operator: DataLocalFilterOperator.equal,
              value: 'tech',
            ),
            DataLocalFilter(
              path: DataLocalFieldPath.parse('rating'),
              operator: DataLocalFilterOperator.equal,
              value: 5,
            ),
          ])
          .orderBy('index')
          .limit(20),
    ),
    QueryScenario(
      name: 'Cursor pagination',
      description: 'page 2 after the first 10 rows',
      run: (products) async {
        final watch = Stopwatch()..start();
        final base = products.query().orderBy('price').orderBy('index');
        final first = await base.limit(10).get();
        final second = await base.limit(10).startAfter(first.cursor!).get();
        watch.stop();
        return QueryRunResult.fromSnapshot(
          name: 'Cursor pagination',
          elapsed: watch.elapsed,
          snapshot: second,
        );
      },
    ),
    QueryScenario.query(
      'limitToLast',
      'last 10 documents ordered by index',
      (products) => products.query().orderBy('index').limitToLast(10),
    ),
    QueryScenario(
      name: 'Aggregates',
      description: 'count, sum(price), average(rating) for non-null ratings',
      run: (products) async {
        final watch = Stopwatch()..start();
        final query = products.query().where('rating', isNotNull: true);
        final count = await query.count();
        final sum = await query.sum('price');
        final average = await query.average('rating');
        watch.stop();
        return QueryRunResult(
          name: 'Aggregates',
          elapsed: watch.elapsed,
          matchedCount: count,
          details:
              'count=$count · sum(price)=$sum · avg(rating)='
              '${average?.toStringAsFixed(2)}',
          preview: const <String>[],
        );
      },
    ),
    QueryScenario(
      name: 'Client text search',
      description: 'full scan: name contains "0099" (no text index)',
      run: (products) async {
        final watch = Stopwatch()..start();
        final snapshot = await products.query().get();
        final matches = snapshot.documents
            .where(
              (document) => (document.data['name']! as String)
                  .toLowerCase()
                  .contains('0099'),
            )
            .toList(growable: false);
        watch.stop();
        return QueryRunResult(
          name: 'Client text search',
          elapsed: watch.elapsed,
          matchedCount: matches.length,
          details: 'Full collection scan; intended for comparison only.',
          preview: _preview(matches),
        );
      },
    ),
  ];

  @override
  void dispose() {
    final database = _database;
    if (database != null) unawaited(database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DataLocal Query Playground')),
    body: _products == null && _error == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                'Encrypted SharedPreferences dataset',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '$_documentCount documents · $_status',
                key: const Key('playground-status'),
              ),
              if (_busy) ...<Widget>[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Error: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final size in _seedSizes)
                    FilledButton.tonal(
                      key: Key('seed-$size'),
                      onPressed: _busy ? null : () => _seed(size),
                      child: Text('Seed $size'),
                    ),
                  OutlinedButton(
                    key: const Key('clear-data'),
                    onPressed: _busy ? null : _clear,
                    child: const Text('Clear'),
                  ),
                  FilledButton.icon(
                    key: const Key('run-all'),
                    onPressed: _busy || _documentCount == 0 ? null : _runAll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run all queries'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Query scenarios',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final scenario in _scenarios)
                Card(
                  child: ListTile(
                    title: Text(scenario.name),
                    subtitle: Text(scenario.description),
                    trailing: IconButton(
                      tooltip: 'Run ${scenario.name}',
                      onPressed: _busy || _documentCount == 0
                          ? null
                          : () => _runScenario(scenario),
                      icon: const Icon(Icons.play_circle_outline),
                    ),
                  ),
                ),
              if (_results.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                Text('Results', style: Theme.of(context).textTheme.titleLarge),
                for (final result in _results)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${result.name} · ${result.elapsed.inMicroseconds} µs',
                      ),
                      subtitle: Text(
                        'matched ${result.matchedCount}\n'
                        '${result.details}\n'
                        '${result.preview.join('\n')}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ],
          ),
  );
}

class QueryScenario {
  const QueryScenario({
    required this.name,
    required this.description,
    required this.run,
  });

  factory QueryScenario.query(
    String name,
    String description,
    DataLocalQuery<Map<String, Object?>> Function(
      DataLocalCollection<Map<String, Object?>> products,
    )
    build,
  ) => QueryScenario(
    name: name,
    description: description,
    run: (products) async {
      final watch = Stopwatch()..start();
      final snapshot = await build(products).get();
      watch.stop();
      return QueryRunResult.fromSnapshot(
        name: name,
        elapsed: watch.elapsed,
        snapshot: snapshot,
      );
    },
  );

  final String name;
  final String description;
  final Future<QueryRunResult> Function(
    DataLocalCollection<Map<String, Object?>> products,
  )
  run;
}

class QueryRunResult {
  const QueryRunResult({
    required this.name,
    required this.elapsed,
    required this.matchedCount,
    required this.details,
    required this.preview,
  });

  factory QueryRunResult.fromSnapshot({
    required String name,
    required Duration elapsed,
    required DataLocalQuerySnapshot<Map<String, Object?>> snapshot,
  }) => QueryRunResult(
    name: name,
    elapsed: elapsed,
    matchedCount: snapshot.totalCount,
    details: 'returned ${snapshot.documents.length}',
    preview: _preview(snapshot.documents),
  );

  final String name;
  final Duration elapsed;
  final int matchedCount;
  final String details;
  final List<String> preview;
}

List<String> _preview(
  Iterable<DataLocalDocument<Map<String, Object?>>> documents,
) => documents
    .take(5)
    .map(
      (document) =>
          '${document.id}: ${document.data['name']} · '
          'price=${document.data['price']} · rating=${document.data['rating']}',
    )
    .toList(growable: false);

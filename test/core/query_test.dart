import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  late DataLocalDatabase database;
  late DataLocalCollection<Map<String, Object?>> products;

  setUp(() async {
    database = await DataLocalDatabase.open(
      name: 'query-test',
      storage: DataLocalMemoryStorage(),
    );
    products = database.mapCollection('products');
    await products.insert(_product('Apple', 10, 'food', null), id: 'a');
    await products.insert(_product('Banana', 20, 'food', 4), id: 'b');
    await products.insert(_product('Cable', 20, 'tech', 5), id: 'c');
    await products.insert(_product('Dock', 40, 'tech', 5), id: 'd');
  });

  tearDown(() => database.close());

  test('filters nested fields, nulls, lists, and ranges', () async {
    final tech = await products
        .query()
        .where('category.name', isEqualTo: 'tech')
        .where('price', isGreaterThanOrEqualTo: 20)
        .get();
    expect(tech.documents.map((item) => item.id), <String>['c', 'd']);

    final nullable = await products
        .query()
        .where('rating', isEqualTo: null)
        .get();
    expect(nullable.documents.single.id, 'a');

    final tagged = await products
        .query()
        .where('tags', arrayContains: 'popular')
        .get();
    expect(tagged.documents.map((item) => item.id), <String>['b', 'c']);

    final selected = await products
        .query()
        .where('price', whereIn: <Object?>[10, 40])
        .get();
    expect(selected.documents.map((item) => item.id), <String>['a', 'd']);
  });

  test('supports exclusion, array-any, and explicit null predicates', () async {
    final excluded = await products
        .query()
        .where('category.name', whereNotIn: <Object?>['food'])
        .get();
    expect(excluded.documents.map((item) => item.id), <String>['c', 'd']);

    final tagged = await products
        .query()
        .where('tags', arrayContainsAny: <Object?>['popular', 'missing'])
        .get();
    expect(tagged.documents.map((item) => item.id), <String>['b', 'c']);

    final nullRating = await products
        .query()
        .where('rating', isNull: true)
        .get();
    expect(nullRating.documents.map((item) => item.id), <String>['a']);

    final rated = await products.query().where('rating', isNotNull: true).get();
    expect(rated.documents.map((item) => item.id), <String>['b', 'c', 'd']);

    await products.insert(<String, Object?>{
      'name': 'Missing fields',
      'tags': <Object?>[],
    }, id: 'missing');
    expect(
      (await products.query().where('rating', isNull: true).get()).documents
          .map((item) => item.id),
      <String>['a'],
    );
    expect(
      (await products
              .query()
              .where('category.name', whereNotIn: <Object?>['food'])
              .get())
          .documents
          .map((item) => item.id),
      <String>['c', 'd'],
    );
  });

  test('combines OR groups with existing AND filters', () async {
    final query = products
        .query()
        .where('price', isGreaterThanOrEqualTo: 20)
        .whereAny(<DataLocalFilter>[
          DataLocalFilter(
            path: DataLocalFieldPath.parse('name'),
            operator: DataLocalFilterOperator.equal,
            value: 'Banana',
          ),
          DataLocalFilter(
            path: DataLocalFieldPath.parse('category.name'),
            operator: DataLocalFilterOperator.equal,
            value: 'tech',
          ),
        ]);

    final snapshot = await query.get();
    expect(snapshot.documents.map((item) => item.id), <String>['b', 'c', 'd']);
  });

  test('sorts deterministically and paginates with durable cursors', () async {
    final query = products.query().orderBy('price').limit(2);
    final first = await query.get();
    expect(first.documents.map((item) => item.id), <String>['a', 'b']);

    await products.delete('b');
    final second = await products
        .query()
        .orderBy('price')
        .limit(2)
        .startAfter(first.cursor!)
        .get();
    expect(second.documents.map((item) => item.id), <String>['c', 'd']);
  });

  test('supports descending order, counts, sum, and average', () async {
    final query = products
        .query()
        .where('category.name', isEqualTo: 'tech')
        .orderBy('price', descending: true);

    final snapshot = await query.get();
    expect(snapshot.documents.map((item) => item.id), <String>['d', 'c']);
    expect(await query.count(), 2);
    expect(await query.sum('price'), 60);
    expect(await query.average('price'), 30);
  });

  test('supports inclusive and exclusive cursor boundaries', () async {
    final ordered = products.query().orderBy('price');
    final throughBanana = await ordered.limit(2).get();
    final throughCable = await ordered.limit(3).get();
    final banana = throughBanana.cursor!;
    final cable = throughCable.cursor!;

    expect(
      (await ordered.startAt(banana).endAt(cable).get()).documents.map(
        (item) => item.id,
      ),
      <String>['b', 'c'],
    );
    expect(
      (await ordered.startAfter(banana).endBefore(cable).get()).documents,
      isEmpty,
    );
  });

  test('supports limitToLast and explicit null ordering', () async {
    await products.insert(<String, Object?>{
      'name': 'Earbuds',
      'price': 30,
      'category': <String, Object?>{'name': 'tech'},
      'tags': <Object?>['tech'],
    }, id: 'e');

    final last = await products.query().orderBy('price').limitToLast(2).get();
    expect(last.documents.map((item) => item.id), <String>['e', 'd']);

    final nullsLast = await products
        .query()
        .orderBy('rating', nullOrder: DataLocalNullOrder.last)
        .get();
    expect(nullsLast.documents.map((item) => item.id), <String>[
      'b',
      'c',
      'd',
      'e',
      'a',
    ]);

    final nullsFirstDescending = await products
        .query()
        .orderBy(
          'rating',
          descending: true,
          nullOrder: DataLocalNullOrder.first,
        )
        .get();
    expect(nullsFirstDescending.documents.map((item) => item.id), <String>[
      'a',
      'e',
      'c',
      'd',
      'b',
    ]);
  });

  test('rejects invalid operators, limits, cursors, and aggregates', () async {
    expect(
      () => products.query().where('price'),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().where('price', whereIn: 'not-a-list'),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().where('price', whereNotIn: 'not-a-list'),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().where('price', isNull: false),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().whereAny(const <DataLocalFilter>[]),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().whereAny(<DataLocalFilter>[
        DataLocalFilter(
          path: DataLocalFieldPath.parse('price'),
          operator: DataLocalFilterOperator.whereIn,
          value: 'not-a-list',
        ),
      ]),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().limit(0),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().limitToLast(0),
      throwsA(isA<DataLocalValidationException>()),
    );

    final cursor =
        (await products.query().orderBy('price').limit(1).get()).cursor;
    expect(
      () => products.query().orderBy('name').startAfter(cursor!).get(),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => products.query().sum('name'),
      throwsA(isA<DataLocalValidationException>()),
    );
  });
}

Map<String, Object?> _product(
  String name,
  int price,
  String category,
  int? rating,
) => <String, Object?>{
  'name': name,
  'price': price,
  'rating': rating,
  'category': <String, Object?>{'name': category},
  'tags': <Object?>[
    category,
    if (name == 'Banana' || name == 'Cable') 'popular',
  ],
};

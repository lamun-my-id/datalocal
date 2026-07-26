import 'package:datalocal/datalocal.dart';
import 'package:example/main.dart';
import 'package:example/query_playground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<DataLocalDatabase> openMemoryDatabase() => DataLocalDatabase.open(
    name: 'query-playground-widget-test',
    storage: DataLocalMemoryStorage(),
  );

  testWidgets('renders every query playground scenario', (tester) async {
    await tester.pumpWidget(
      DataLocalExampleApp(
        databaseFactories: <String, DataLocalDatabaseFactory>{
          'Memory': openMemoryDatabase,
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DataLocal Query Playground'), findsOneWidget);
    expect(find.text('Seed 10'), findsOneWidget);
    expect(find.text('Equal + nested path'), findsOneWidget);
    expect(find.text('whereIn'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Client text search'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Client text search'), findsOneWidget);
  });

  testWidgets('seeds ten documents and executes all scenarios', (tester) async {
    await tester.pumpWidget(
      DataLocalExampleApp(
        databaseFactories: <String, DataLocalDatabaseFactory>{
          'Memory': openMemoryDatabase,
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seed-10')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seeded 10 documents'), findsOneWidget);

    await tester.tap(find.byKey(const Key('run-all')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Completed 11 scenarios'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Results'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Results'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('count=8'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('count=8'), findsOneWidget);
  });
}

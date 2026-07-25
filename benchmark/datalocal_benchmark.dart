import 'dart:convert';
import 'dart:io';

import 'package:datalocal/datalocal_core.dart';

Future<void> main() async {
  const documentCount = int.fromEnvironment(
    'DATALOCAL_BENCHMARK_DOCUMENTS',
    defaultValue: 1000,
  );
  final database = await DataLocalDatabase.open(
    name: 'benchmark',
    storage: DataLocalMemoryStorage(),
    encryption: DataLocalAesGcmEncryptionProvider(
      keyProvider: DataLocalMemoryKeyProvider(),
    ),
  );
  final documents = database.mapCollection('documents');

  final insertWatch = Stopwatch()..start();
  for (var index = 0; index < documentCount; index++) {
    await documents.insert(<String, Object?>{
      'index': index,
      'group': index % 10,
      'payload': 'document-$index',
    }, id: 'document-$index');
  }
  insertWatch.stop();

  final queryWatch = Stopwatch()..start();
  final query = await documents
      .query()
      .where('group', isEqualTo: 5)
      .orderBy('index', descending: true)
      .limit(20)
      .get();
  queryWatch.stop();

  final readWatch = Stopwatch()..start();
  for (var index = 0; index < documentCount; index++) {
    await documents.require('document-$index');
  }
  readWatch.stop();
  await database.close();

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'documents': documentCount,
      'insertTotalUs': insertWatch.elapsedMicroseconds,
      'insertAverageUs': insertWatch.elapsedMicroseconds / documentCount,
      'pointReadTotalUs': readWatch.elapsedMicroseconds,
      'pointReadAverageUs': readWatch.elapsedMicroseconds / documentCount,
      'filteredSortedQueryUs': queryWatch.elapsedMicroseconds,
      'queryResultCount': query.documents.length,
      'runtime': 'Dart VM; in-memory storage; AES-256-GCM',
    }),
  );
}

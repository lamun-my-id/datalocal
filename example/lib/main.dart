import 'package:datalocal/datalocal.dart';
import 'package:datalocal_sqlite/datalocal_sqlite.dart';
import 'package:flutter/material.dart';

import 'query_playground.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DataLocalExampleApp());
}

class DataLocalExampleApp extends StatelessWidget {
  const DataLocalExampleApp({super.key, this.databaseFactories});

  final Map<String, DataLocalDatabaseFactory>? databaseFactories;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DataLocal Query Playground',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    ),
    home: QueryPlaygroundPage(
      databaseFactories:
          databaseFactories ??
          <String, DataLocalDatabaseFactory>{
            'SharedPreferences': openSharedPreferencesDatabase,
            'SQLite': openSqliteDatabase,
          },
    ),
  );
}

Future<DataLocalDatabase> openSharedPreferencesDatabase() async {
  const databaseName = 'datalocal-v2-query-playground-preferences';
  return DataLocalDatabase.open(
    name: databaseName,
    storage: DataLocalSharedPreferencesAsyncStorage(),
    encryption: DataLocalAesGcmEncryptionProvider(
      keyProvider: DataLocalSecureStorageKeyProvider(
        databaseName: databaseName,
      ),
    ),
  );
}

Future<DataLocalDatabase> openSqliteDatabase() async {
  const databaseName = 'datalocal-v2-query-playground-sqlite';
  return DataLocalDatabase.open(
    name: databaseName,
    storage: DataLocalSqliteStorage(),
    encryption: DataLocalAesGcmEncryptionProvider(
      keyProvider: DataLocalSecureStorageKeyProvider(
        databaseName: databaseName,
      ),
    ),
  );
}

import 'package:datalocal/datalocal.dart';
import 'package:flutter/material.dart';

import 'query_playground.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DataLocalExampleApp());
}

class DataLocalExampleApp extends StatelessWidget {
  const DataLocalExampleApp({super.key, this.databaseFactory});

  final DataLocalDatabaseFactory? databaseFactory;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DataLocal Query Playground',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    ),
    home: QueryPlaygroundPage(
      databaseFactory: databaseFactory ?? openExampleDatabase,
    ),
  );
}

Future<DataLocalDatabase> openExampleDatabase() async {
  const databaseName = 'datalocal-v2-query-playground';
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

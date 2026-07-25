import 'dart:typed_data';

import 'package:datalocal/datalocal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../contracts/storage_contract.dart';

void main() {
  storageContract(
    'SharedPreferencesAsync',
    () => DataLocalSharedPreferencesAsyncStorage(
      client: _MemoryPreferencesClient(),
    ),
  );

  test('persists complete database records across adapter instances', () async {
    final client = _MemoryPreferencesClient();
    var database = await DataLocalDatabase.open(
      name: 'persist',
      storage: DataLocalSharedPreferencesAsyncStorage(client: client),
    );
    var notes = database.mapCollection('notes.with.dots');
    await notes.insert(<String, Object?>{
      'title': 'restart safe',
    }, id: 'id.with.dots');
    await database.close();

    database = await DataLocalDatabase.open(
      name: 'persist',
      storage: DataLocalSharedPreferencesAsyncStorage(client: client),
    );
    notes = database.mapCollection('notes.with.dots');

    expect((await notes.require('id.with.dots')).data['title'], 'restart safe');
    expect(
      client.values.keys.where((key) => key.startsWith('datalocal.v2.')),
      isNotEmpty,
    );
    expect(
      client.values.keys.any((key) => key.contains('notes.with.dots')),
      isFalse,
    );
    await database.close();
  });

  test('removes orphan records during open', () async {
    final client = _MemoryPreferencesClient();
    final storage = DataLocalSharedPreferencesAsyncStorage(client: client);
    await storage.open(DataLocalStorageContext(databaseName: 'repair'));
    await storage.write(_record('kept'));
    final recordKey = client.values.keys.singleWhere(
      (key) => key.contains('.record.'),
    );
    final orphanKey = '${recordKey}orphan';
    client.values[orphanKey] = client.values[recordKey]!;
    await storage.close();

    final reopened = DataLocalSharedPreferencesAsyncStorage(client: client);
    await reopened.open(DataLocalStorageContext(databaseName: 'repair'));
    expect(client.values.containsKey(orphanKey), isFalse);
    expect(await reopened.read('notes', 'kept'), isNotNull);
    await reopened.close();
  });

  test('rejects a manifest that references a missing record', () async {
    final client = _MemoryPreferencesClient();
    final storage = DataLocalSharedPreferencesAsyncStorage(client: client);
    await storage.open(DataLocalStorageContext(databaseName: 'corrupt'));
    await storage.write(_record('missing'));
    final recordKey = client.values.keys.singleWhere(
      (key) => key.contains('.record.'),
    );
    client.values.remove(recordKey);
    await storage.close();

    await expectLater(
      DataLocalSharedPreferencesAsyncStorage(
        client: client,
      ).open(DataLocalStorageContext(databaseName: 'corrupt')),
      throwsA(isA<DataLocalCorruptionException>()),
    );
  });

  test(
    'runs journal recovery before manifest integrity verification',
    () async {
      final client = _MemoryPreferencesClient();
      var database = await DataLocalDatabase.open(
        name: 'recover-first',
        storage: DataLocalSharedPreferencesAsyncStorage(client: client),
      );
      var notes = database.mapCollection('notes');
      await notes.insert(<String, Object?>{'value': 'kept'}, id: 'note');
      await database.close();

      database = await DataLocalDatabase.open(
        name: 'recover-first',
        storage: DataLocalSharedPreferencesAsyncStorage(client: client),
        failureInjector: (phase) {
          if (phase == DataLocalCommitPhase.mutationsApplied) {
            throw _InjectedFailure();
          }
        },
      );
      notes = database.mapCollection('notes');
      await expectLater(notes.delete('note'), throwsA(isA<_InjectedFailure>()));
      await database.close();

      database = await DataLocalDatabase.open(
        name: 'recover-first',
        storage: DataLocalSharedPreferencesAsyncStorage(client: client),
      );
      notes = database.mapCollection('notes');
      expect((await notes.require('note')).data['value'], 'kept');
      await database.close();
    },
  );
}

DataLocalStoredRecord _record(String id) => DataLocalStoredRecord(
  collection: 'notes',
  id: id,
  revision: 1,
  formatVersion: 2,
  payload: Uint8List.fromList(<int>[1, 2, 3]),
);

final class _MemoryPreferencesClient
    implements DataLocalPreferencesAsyncClient {
  final Map<String, String> values = <String, String>{};

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

final class _InjectedFailure implements Exception {}

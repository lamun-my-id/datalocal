import 'dart:async';
import 'dart:convert';

import 'package:datalocal/datalocal.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _useDeviceKeys = bool.fromEnvironment(
  'DATALOCAL_E2E_DEVICE_KEYS',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real plugins persist encrypted CRUD across reopen', (_) async {
    const databaseName = 'datalocal-e2e-crud';
    await _resetDatabase(databaseName);
    final DataLocalKeyProvider keys = _useDeviceKeys
        ? DataLocalSecureStorageKeyProvider(databaseName: databaseName)
        : DataLocalMemoryKeyProvider();
    final encryption = DataLocalAesGcmEncryptionProvider(keyProvider: keys);
    var database = await _open(databaseName, encryption: encryption);
    var notes = database.mapCollection('notes');
    final events = <DataLocalCommitEvent>[];
    final subscription = notes.changes.listen(events.add);

    final inserted = await notes.insert(<String, Object?>{
      'title': 'KNOWN-E2E-PLAINTEXT',
      'nested': <String, Object?>{'value': 42},
    }, id: 'one');
    await notes.patch('one', <String, Object?>{
      'active': true,
    }, expectedRevision: inserted.revision);
    await keys.rotate();
    await notes.insert(<String, Object?>{'title': 'after'}, id: 'two');
    await subscription.cancel();
    await database.close();

    final persisted = (await SharedPreferencesAsync().getAll()).values.join();
    expect(persisted.contains('KNOWN-E2E-PLAINTEXT'), isFalse);

    database = await _open(databaseName, encryption: encryption);
    notes = database.mapCollection('notes');
    expect((await notes.require('one')).revision, 2);
    expect((await notes.require('one')).data['active'], isTrue);
    expect((await notes.require('two')).data['title'], 'after');
    expect(events.map((event) => event.sequence), <int>[1, 2, 3]);
    await database.close();
  });

  testWidgets('concurrent writes, watch, and lifecycle remain ordered', (
    _,
  ) async {
    const databaseName = 'datalocal-e2e-concurrency';
    await _resetDatabase(databaseName);
    final database = await _open(databaseName);
    final notes = database.mapCollection('notes');
    final snapshots = <DataLocalQuerySnapshot<Map<String, Object?>>>[];
    final ready = Completer<void>();
    final subscription = notes.query().orderBy('index').watch().listen((
      snapshot,
    ) {
      snapshots.add(snapshot);
      if (!ready.isCompleted) ready.complete();
    });
    await ready.future;

    await Future.wait(
      List<Future<DataLocalDocument<Map<String, Object?>>>>.generate(
        20,
        (index) =>
            notes.insert(<String, Object?>{'index': index}, id: 'item-$index'),
      ),
    );
    await _waitFor(
      () => snapshots.isNotEmpty && snapshots.last.documents.length == 20,
    );
    await database.close();
    await subscription.cancel();

    final reopened = await _open(databaseName);
    final restored = await reopened
        .mapCollection('notes')
        .query()
        .orderBy('index')
        .get();
    expect(restored.documents, hasLength(20));
    expect(snapshots.first.documents, isEmpty);
    expect(snapshots.last.documents, hasLength(20));
    await reopened.close();
  });

  for (final phase in DataLocalCommitPhase.values) {
    testWidgets('real storage recovers interruption at ${phase.name}', (
      _,
    ) async {
      final databaseName = 'datalocal-e2e-recovery-${phase.name}';
      await _resetDatabase(databaseName);
      var injected = false;
      var database = await _open(
        databaseName,
        failureInjector: (current) {
          if (!injected && current == phase) {
            injected = true;
            throw _InjectedFailure();
          }
        },
      );
      var notes = database.mapCollection('notes');
      await expectLater(
        notes.insert(<String, Object?>{'phase': phase.name}, id: 'record'),
        throwsA(isA<_InjectedFailure>()),
      );
      await database.close();

      database = await _open(databaseName);
      notes = database.mapCollection('notes');
      final record = await notes.get('record');
      if (phase == DataLocalCommitPhase.journalPrepared ||
          phase == DataLocalCommitPhase.mutationsApplied) {
        expect(record, isNull);
      } else {
        expect(record?.data['phase'], phase.name);
      }
      await database.close();
    });
  }

  testWidgets('missing real record is reported as corruption', (_) async {
    const databaseName = 'datalocal-e2e-corruption';
    await _resetDatabase(databaseName);
    var database = await _open(databaseName);
    await database.mapCollection('notes').insert(<String, Object?>{
      'value': 1,
    }, id: 'missing');
    await database.close();

    final preferences = SharedPreferencesAsync();
    final keys = await preferences.getKeys();
    final recordKey = keys.singleWhere(
      (key) =>
          key.startsWith(_prefix(databaseName)) && key.contains('.record.'),
    );
    await preferences.remove(recordKey);

    await expectLater(
      _open(databaseName),
      throwsA(isA<DataLocalCorruptionException>()),
    );
  });

  testWidgets('real 1.x preferences migrate and remain until cleanup', (
    _,
  ) async {
    const databaseName = 'datalocal-e2e-migration';
    const stateName = 'legacy-e2e';
    await _resetDatabase(databaseName);
    final preferences = SharedPreferencesAsync();
    final legacy = EncryptUtil();
    final encryptedName = legacy.encript('DataLocal-$stateName');
    final containerKey = legacy.encript(encryptedName);
    const path = 'legacy-e2e--legacy-id';
    final recordKey = legacy.encript(path);
    await preferences.setString(
      containerKey,
      legacy.encript(
        jsonEncode(<String, Object?>{
          'name': encryptedName,
          'seq': 1,
          'ids': <String>[path],
          'param': <String, Object?>{},
        }),
      ),
    );
    await preferences.setString(
      recordKey,
      legacy.encript(
        jsonEncode(<String, Object?>{
          'id': 'legacy-id',
          'name': stateName,
          'parent': '',
          'createdAt': '2021-01-01T00:00:00.000Z',
          'updatedAt': '2021-01-02T00:00:00.000Z',
          'data': <String, Object?>{'upgraded': true},
          'files': <Object?>[],
        }),
      ),
    );

    final database = await _open(databaseName);
    final migrator = DataLocalLegacyV1Migrator();
    final client = DataLocalSharedPreferencesAsyncClient(preferences);
    final report = await migrator.migrate(
      databaseName: databaseName,
      stateName: stateName,
      preferences: client,
      target: database.mapCollection('legacy'),
    );
    expect(report.complete, isTrue);
    expect(
      (await database.mapCollection('legacy').require('legacy-id'))
          .data['upgraded'],
      isTrue,
    );
    expect(await preferences.getString(containerKey), isNotNull);

    await migrator.cleanupLegacy(
      databaseName: databaseName,
      stateName: stateName,
      preferences: client,
    );
    expect(await preferences.getString(containerKey), isNull);
    expect(await preferences.getString(recordKey), isNull);
    await database.close();
  });
}

Future<DataLocalDatabase> _open(
  String name, {
  DataLocalEncryptionProvider encryption =
      const DataLocalNoEncryptionProvider(),
  DataLocalFailureInjector? failureInjector,
}) => DataLocalDatabase.open(
  name: name,
  storage: DataLocalSharedPreferencesAsyncStorage(),
  encryption: encryption,
  failureInjector: failureInjector,
);

Future<void> _resetDatabase(String name) async {
  final preferences = SharedPreferencesAsync();
  final keys = await preferences.getKeys();
  for (final key in keys.where((key) => key.startsWith(_prefix(name)))) {
    await preferences.remove(key);
  }
}

String _prefix(String name) =>
    'datalocal.v2.${base64UrlEncode(utf8.encode(name)).replaceAll('=', '')}';

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw TimeoutException('E2E condition was not reached.');
}

final class _InjectedFailure implements Exception {}

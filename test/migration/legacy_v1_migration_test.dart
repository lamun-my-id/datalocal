import 'dart:convert';

import 'package:datalocal/datalocal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/legacy_v1_cipher.dart';

void main() {
  test(
    'migrates legacy documents with IDs, metadata, and nested data',
    () async {
      final preferences = _MemoryPreferencesClient()..installFixture();
      final database = await DataLocalDatabase.open(
        name: 'v2-db',
        storage: DataLocalMemoryStorage(),
        encryption: DataLocalAesGcmEncryptionProvider(
          keyProvider: DataLocalMemoryKeyProvider(),
        ),
      );
      final target = database.mapCollection('legacy');
      final migrator = DataLocalLegacyV1Migrator();

      final report = await migrator.migrate(
        databaseName: 'v2-db',
        stateName: 'legacy',
        preferences: preferences,
        target: target,
      );

      expect(report.complete, isTrue);
      expect(report.migratedIds, <String>['item-1', 'item-2']);
      final first = await target.require('item-1');
      expect(first.createdAt, DateTime.utc(2020, 1, 1));
      expect(first.updatedAt, DateTime.utc(2020, 1, 2));
      expect(first.data['nested'], <String, Object?>{'value': 42});
      await database.close();
    },
  );

  test('resumes safely when progress persistence was interrupted', () async {
    final preferences = _MemoryPreferencesClient()
      ..installFixture()
      ..failNextMigrationStateWrite = true;
    final database = await DataLocalDatabase.open(
      name: 'resume-db',
      storage: DataLocalMemoryStorage(),
    );
    final target = database.mapCollection('legacy');
    final migrator = DataLocalLegacyV1Migrator();

    await expectLater(
      migrator.migrate(
        databaseName: 'resume-db',
        stateName: 'legacy',
        preferences: preferences,
        target: target,
      ),
      throwsA(isA<_InjectedFailure>()),
    );
    final resumed = await migrator.migrate(
      databaseName: 'resume-db',
      stateName: 'legacy',
      preferences: preferences,
      target: target,
    );

    expect(resumed.complete, isTrue);
    expect((await target.query().get()).documents, hasLength(2));
    await database.close();
  });

  test('requires explicit verified cleanup', () async {
    final preferences = _MemoryPreferencesClient()..installFixture();
    final database = await DataLocalDatabase.open(
      name: 'cleanup-db',
      storage: DataLocalMemoryStorage(),
    );
    final target = database.mapCollection('legacy');
    final migrator = DataLocalLegacyV1Migrator();

    await expectLater(
      migrator.cleanupLegacy(
        databaseName: 'cleanup-db',
        stateName: 'legacy',
        preferences: preferences,
      ),
      throwsA(isA<DataLocalMigrationException>()),
    );

    await migrator.migrate(
      databaseName: 'cleanup-db',
      stateName: 'legacy',
      preferences: preferences,
      target: target,
    );
    await migrator.cleanupLegacy(
      databaseName: 'cleanup-db',
      stateName: 'legacy',
      preferences: preferences,
    );

    expect(
      await const DataLocalLegacyV1Decoder().read(
        stateName: 'legacy',
        preferences: preferences,
      ),
      isNull,
    );
    expect((await target.query().get()).documents, hasLength(2));
    await database.close();
  });

  test(
    'reports missing legacy records without deleting source state',
    () async {
      final preferences = _MemoryPreferencesClient()..installFixture();
      preferences.values.remove(encryptLegacyV1Fixture('legacy--item-2'));
      final database = await DataLocalDatabase.open(
        name: 'incomplete-db',
        storage: DataLocalMemoryStorage(),
      );
      final migrator = DataLocalLegacyV1Migrator();

      final report = await migrator.migrate(
        databaseName: 'incomplete-db',
        stateName: 'legacy',
        preferences: preferences,
        target: database.mapCollection('legacy'),
      );

      expect(report.complete, isFalse);
      expect(report.failedPaths, <String>['legacy--item-2']);
      await expectLater(
        migrator.cleanupLegacy(
          databaseName: 'incomplete-db',
          stateName: 'legacy',
          preferences: preferences,
        ),
        throwsA(isA<DataLocalMigrationException>()),
      );
      await database.close();
    },
  );
}

final class _MemoryPreferencesClient
    implements DataLocalPreferencesAsyncClient {
  final Map<String, String> values = <String, String>{};
  bool failNextMigrationStateWrite = false;

  void installFixture() {
    final encryptedName = encryptLegacyV1Fixture('DataLocal-legacy');
    values[encryptLegacyV1Fixture(encryptedName)] = encryptLegacyV1Fixture(
      jsonEncode(<String, Object?>{
        'name': encryptedName,
        'seq': 2,
        'ids': <String>['legacy--item-1', 'legacy--item-2'],
        'param': <String, Object?>{},
      }),
    );
    values[encryptLegacyV1Fixture('legacy--item-1')] = encryptLegacyV1Fixture(
      jsonEncode(<String, Object?>{
        'id': 'item-1',
        'name': 'legacy',
        'parent': '',
        'createdAt': '2020-01-01T00:00:00.000Z',
        'updatedAt': '2020-01-02T00:00:00.000Z',
        'data': <String, Object?>{
          'title': 'first',
          'nested': <String, Object?>{'value': 42},
        },
        'files': <Object?>[],
      }),
    );
    values[encryptLegacyV1Fixture('legacy--item-2')] = encryptLegacyV1Fixture(
      jsonEncode(<String, Object?>{
        'id': 'item-2',
        'name': 'legacy',
        'parent': '',
        'createdAt': '2020-02-01T00:00:00.000Z',
        'updatedAt': null,
        'data': <String, Object?>{'title': 'second'},
        'files': <Object?>[],
      }),
    );
  }

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
    if (failNextMigrationStateWrite && key.contains('.migration.')) {
      failNextMigrationStateWrite = false;
      throw _InjectedFailure();
    }
    values[key] = value;
  }
}

final class _InjectedFailure implements Exception {}

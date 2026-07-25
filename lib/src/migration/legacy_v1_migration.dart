import 'dart:convert';
import 'dart:typed_data';

import 'package:datalocal/src/database/datalocal_collection.dart';
import 'package:datalocal/src/document/datalocal_document.dart';
import 'package:datalocal/src/document/datalocal_metadata.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/storage/shared_preferences_async_storage.dart';
import 'package:pointycastle/export.dart';

final class DataLocalLegacyRecord {
  const DataLocalLegacyRecord({
    required this.path,
    required this.id,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
  });

  final String path;
  final String id;
  final Map<String, Object?> data;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

final class DataLocalLegacySnapshot {
  const DataLocalLegacySnapshot({
    required this.containerKey,
    required this.records,
    required this.missingPaths,
  });

  final String containerKey;
  final List<DataLocalLegacyRecord> records;
  final List<String> missingPaths;
}

/// Read-only decoder for the fixed-key Salsa20 format emitted by DataLocal 1.x.
final class DataLocalLegacyV1Decoder {
  const DataLocalLegacyV1Decoder();

  static final Uint8List _legacyKey = Uint8List.fromList(
    utf8.encode('my 32 length key................'),
  );
  static final Uint8List _legacyNonce = Uint8List(8);

  Future<DataLocalLegacySnapshot?> read({
    required String stateName,
    required DataLocalPreferencesAsyncClient preferences,
  }) async {
    try {
      final encryptedName = _encrypt('DataLocal-$stateName');
      final containerKey = _encrypt(encryptedName);
      final containerValue = await preferences.getString(containerKey);
      if (containerValue == null) {
        return null;
      }
      final container =
          jsonDecode(_decrypt(containerValue)) as Map<String, dynamic>;
      final paths = (container['ids'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>();
      final records = <DataLocalLegacyRecord>[];
      final missing = <String>[];
      for (final path in paths) {
        final raw = await preferences.getString(_encrypt(path));
        if (raw == null) {
          missing.add(path);
          continue;
        }
        records.add(_decodeRecord(path, raw));
      }
      return DataLocalLegacySnapshot(
        containerKey: containerKey,
        records: List<DataLocalLegacyRecord>.unmodifiable(records),
        missingPaths: List<String>.unmodifiable(missing),
      );
    } on DataLocalException {
      rethrow;
    } catch (error, stackTrace) {
      throw DataLocalMigrationException(
        'Legacy DataLocal state could not be decoded.',
        context: <String, Object?>{'stateName': stateName},
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  DataLocalLegacyRecord _decodeRecord(String path, String encrypted) {
    final map = jsonDecode(_decrypt(encrypted)) as Map<String, dynamic>;
    final id = map['id'] as String;
    final data = Map<String, Object?>.from(
      map['data'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{},
    );
    final createdAt =
        _date(map['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return DataLocalLegacyRecord(
      path: path,
      id: id,
      data: data,
      createdAt: createdAt,
      updatedAt: _date(map['updatedAt']),
    );
  }

  DateTime? _date(Object? value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  String _encrypt(String value) => base64Encode(_process(utf8.encode(value)));

  String _decrypt(String value) =>
      utf8.decode(_process(base64Decode(value)), allowMalformed: true);

  Uint8List _process(List<int> input) {
    final cipher = Salsa20Engine()
      ..init(
        true,
        ParametersWithIV<KeyParameter>(KeyParameter(_legacyKey), _legacyNonce),
      );
    return cipher.process(Uint8List.fromList(input));
  }
}

final class DataLocalMigrationReport {
  const DataLocalMigrationReport({
    required this.migratedIds,
    required this.failedPaths,
    required this.complete,
  });

  final List<String> migratedIds;
  final List<String> failedPaths;
  final bool complete;
}

/// Resumable copier from one legacy state into a v2 map collection.
final class DataLocalLegacyV1Migrator {
  DataLocalLegacyV1Migrator({this.decoder = const DataLocalLegacyV1Decoder()});

  final DataLocalLegacyV1Decoder decoder;

  Future<DataLocalMigrationReport> migrate({
    required String databaseName,
    required String stateName,
    required DataLocalPreferencesAsyncClient preferences,
    required DataLocalCollection<Map<String, Object?>> target,
  }) async {
    final stateKey = _stateKey(databaseName, stateName);
    final progress = await _readProgress(preferences, stateKey);
    final snapshot = await decoder.read(
      stateName: stateName,
      preferences: preferences,
    );
    if (snapshot == null) {
      return const DataLocalMigrationReport(
        migratedIds: <String>[],
        failedPaths: <String>[],
        complete: true,
      );
    }
    final migrated = <String>{...progress};
    final failed = <String>[...snapshot.missingPaths];
    for (final legacy in snapshot.records) {
      if (migrated.contains(legacy.id)) {
        continue;
      }
      try {
        final existing = await target.get(legacy.id);
        if (existing == null) {
          await target.importDocument(
            DataLocalDocument<Map<String, Object?>>(
              metadata: DataLocalMetadata(
                id: legacy.id,
                createdAt: legacy.createdAt,
                updatedAt: legacy.updatedAt ?? legacy.createdAt,
                revision: 1,
              ),
              data: legacy.data,
            ),
          );
        } else if (!_mapsEqual(existing.data, legacy.data)) {
          throw DataLocalConflictException(
            'Migration target contains a different document.',
            context: <String, Object?>{'documentId': legacy.id},
          );
        }
        migrated.add(legacy.id);
        await _writeProgress(preferences, stateKey, migrated);
      } on DataLocalException {
        failed.add(legacy.path);
      }
    }
    return DataLocalMigrationReport(
      migratedIds: List<String>.unmodifiable(migrated.toList()..sort()),
      failedPaths: List<String>.unmodifiable(failed),
      complete: failed.isEmpty && migrated.length == snapshot.records.length,
    );
  }

  Future<void> cleanupLegacy({
    required String databaseName,
    required String stateName,
    required DataLocalPreferencesAsyncClient preferences,
  }) async {
    final snapshot = await decoder.read(
      stateName: stateName,
      preferences: preferences,
    );
    if (snapshot == null) {
      return;
    }
    final progress = await _readProgress(
      preferences,
      _stateKey(databaseName, stateName),
    );
    final expected = snapshot.records.map((record) => record.id).toSet();
    if (snapshot.missingPaths.isNotEmpty || !progress.containsAll(expected)) {
      throw const DataLocalMigrationException(
        'Legacy cleanup requires a complete verified migration.',
      );
    }
    for (final record in snapshot.records) {
      await preferences.remove(_legacyRecordKey(record.path));
    }
    await preferences.remove(snapshot.containerKey);
  }

  Future<Set<String>> _readProgress(
    DataLocalPreferencesAsyncClient preferences,
    String key,
  ) async {
    final raw = await preferences.getString(key);
    if (raw == null) {
      return <String>{};
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['format'] != 'datalocal-migration/1') {
        throw const FormatException('unsupported migration state');
      }
      return (map['migratedIds'] as List<dynamic>).cast<String>().toSet();
    } catch (error, stackTrace) {
      throw DataLocalMigrationException(
        'Migration progress is invalid.',
        context: const <String, Object?>{'component': 'migrationState'},
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  Future<void> _writeProgress(
    DataLocalPreferencesAsyncClient preferences,
    String key,
    Set<String> migrated,
  ) => preferences.setString(
    key,
    jsonEncode(<String, Object?>{
      'format': 'datalocal-migration/1',
      'migratedIds': migrated.toList()..sort(),
    }),
  );

  bool _mapsEqual(Map<String, Object?> left, Map<String, Object?> right) =>
      jsonEncode(left) == jsonEncode(right);

  String _stateKey(String databaseName, String stateName) =>
      'datalocal.v2.${_token(databaseName)}.migration.${_token(stateName)}';

  String _legacyRecordKey(String path) => decoder._encrypt(path);

  String _token(String value) =>
      base64UrlEncode(utf8.encode(value)).replaceAll('=', '');
}

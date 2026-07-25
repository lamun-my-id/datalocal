import 'dart:convert';
import 'dart:typed_data';

import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/storage/datalocal_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DataLocalPreferencesAsyncClient {
  Future<Set<String>> getKeys();

  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

final class DataLocalSharedPreferencesAsyncClient
    implements DataLocalPreferencesAsyncClient {
  DataLocalSharedPreferencesAsyncClient([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<Set<String>> getKeys() => _preferences.getKeys();

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// SharedPreferencesAsync-backed storage for small document collections.
///
/// Logical atomicity is supplied by DataLocal's recovery journal. This adapter
/// does not claim cross-process transactions.
final class DataLocalSharedPreferencesAsyncStorage
    implements DataLocalStorage, DataLocalIntegrityVerifyingStorage {
  DataLocalSharedPreferencesAsyncStorage({
    DataLocalPreferencesAsyncClient? client,
  }) : _client = client ?? DataLocalSharedPreferencesAsyncClient();

  final DataLocalPreferencesAsyncClient _client;
  String? _databaseName;
  String? _prefix;
  bool _isOpen = false;

  @override
  DataLocalStorageCapabilities get capabilities =>
      const DataLocalStorageCapabilities.basic();

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> open(DataLocalStorageContext context) async {
    if (_isOpen) {
      if (_databaseName == context.databaseName) {
        return;
      }
      throw DataLocalInitializationException(
        'Storage is already open for another database.',
        context: <String, Object?>{'databaseName': _databaseName},
      );
    }
    _databaseName = context.databaseName;
    _prefix = 'datalocal.v2.${_token(context.databaseName)}';
    await _ensureDatabaseManifest();
    _isOpen = true;
    try {
      if (await _client.getString('$_prefix.journal') == null) {
        await verifyIntegrity();
      }
    } catch (_) {
      _isOpen = false;
      _databaseName = null;
      _prefix = null;
      rethrow;
    }
  }

  @override
  Future<void> verifyIntegrity() async {
    _requireOpen();
    await _verifyAndRepair();
  }

  @override
  Future<DataLocalStoredRecord?> read(String collection, String id) async {
    _requireOpen();
    final encoded = await _client.getString(_recordKey(collection, id));
    return encoded == null ? null : _decodeRecord(encoded, collection, id);
  }

  @override
  Future<List<DataLocalStoredRecord>> readCollection(String collection) async {
    _requireOpen();
    final manifest = await _readCollectionManifest(collection);
    if (manifest == null) {
      return const <DataLocalStoredRecord>[];
    }
    final records = <DataLocalStoredRecord>[];
    for (final id in manifest.ids) {
      final record = await read(collection, id);
      if (record == null) {
        throw DataLocalCorruptionException(
          'Collection manifest references a missing record.',
          context: <String, Object?>{
            'collection': collection,
            'documentId': id,
          },
        );
      }
      records.add(record);
    }
    records.sort((left, right) => left.id.compareTo(right.id));
    return records;
  }

  @override
  Future<void> write(DataLocalStoredRecord record) async {
    _requireOpen();
    await _client.setString(
      _recordKey(record.collection, record.id),
      _encodeRecord(record),
    );
    final current =
        await _readCollectionManifest(record.collection) ??
        _CollectionManifest(record.collection, const <String>[], 0);
    final ids = <String>{...current.ids, record.id}.toList()..sort();
    await _writeCollectionManifest(
      _CollectionManifest(record.collection, ids, current.revision + 1),
    );
    await _addCollectionToDatabase(record.collection);
  }

  @override
  Future<bool> delete(String collection, String id) async {
    _requireOpen();
    final key = _recordKey(collection, id);
    if (await _client.getString(key) == null) {
      return false;
    }
    await _client.remove(key);
    final current = await _readCollectionManifest(collection);
    if (current != null) {
      final ids = current.ids.where((item) => item != id).toList();
      if (ids.isEmpty) {
        await _client.remove(_collectionKey(collection));
        await _removeCollectionFromDatabase(collection);
      } else {
        await _writeCollectionManifest(
          _CollectionManifest(collection, ids, current.revision + 1),
        );
      }
    }
    return true;
  }

  @override
  Future<void> clearCollection(String collection) async {
    _requireOpen();
    final manifest = await _readCollectionManifest(collection);
    for (final id in manifest?.ids ?? const <String>[]) {
      await _client.remove(_recordKey(collection, id));
    }
    await _client.remove(_collectionKey(collection));
    await _removeCollectionFromDatabase(collection);
  }

  @override
  Future<Uint8List?> readJournal() async {
    _requireOpen();
    final value = await _client.getString('$_prefix.journal');
    return value == null ? null : base64Url.decode(value);
  }

  @override
  Future<void> writeJournal(Uint8List payload) async {
    _requireOpen();
    await _client.setString('$_prefix.journal', base64UrlEncode(payload));
  }

  @override
  Future<void> clearJournal() async {
    _requireOpen();
    await _client.remove('$_prefix.journal');
  }

  @override
  Future<void> close() async {
    _isOpen = false;
    _databaseName = null;
    _prefix = null;
  }

  Future<void> _ensureDatabaseManifest() async {
    final key = '$_prefix.database';
    final raw = await _client.getString(key);
    if (raw == null) {
      await _client.setString(
        key,
        jsonEncode(<String, Object?>{
          'format': 'datalocal-database/2',
          'database': _databaseName,
          'collections': <String>[],
        }),
      );
      return;
    }
    final manifest = _decodeMap(raw, component: 'databaseManifest');
    if (manifest['format'] != 'datalocal-database/2' ||
        manifest['database'] != _databaseName) {
      throw const DataLocalCorruptionException(
        'Database manifest identity or format is invalid.',
      );
    }
  }

  Future<void> _verifyAndRepair() async {
    final database = await _readDatabaseManifest();
    final expectedRecordKeys = <String>{};
    for (final collection in database.collections) {
      final manifest = await _readCollectionManifest(collection);
      if (manifest == null) {
        throw DataLocalCorruptionException(
          'Database manifest references a missing collection manifest.',
          context: <String, Object?>{'collection': collection},
        );
      }
      for (final id in manifest.ids) {
        final key = _recordKey(collection, id);
        expectedRecordKeys.add(key);
        if (await _client.getString(key) == null) {
          throw DataLocalCorruptionException(
            'Collection manifest references a missing record.',
            context: <String, Object?>{
              'collection': collection,
              'documentId': id,
            },
          );
        }
      }
    }
    final recordPrefix = '$_prefix.record.';
    final orphanKeys = (await _client.getKeys()).where(
      (key) =>
          key.startsWith(recordPrefix) && !expectedRecordKeys.contains(key),
    );
    for (final key in orphanKeys) {
      await _client.remove(key);
    }
  }

  Future<_DatabaseManifest> _readDatabaseManifest() async {
    final raw = await _client.getString('$_prefix.database');
    if (raw == null) {
      throw const DataLocalCorruptionException('Database manifest is missing.');
    }
    final map = _decodeMap(raw, component: 'databaseManifest');
    return _DatabaseManifest(
      (map['collections'] as List<dynamic>).cast<String>(),
    );
  }

  Future<void> _writeDatabaseManifest(_DatabaseManifest manifest) =>
      _client.setString(
        '$_prefix.database',
        jsonEncode(<String, Object?>{
          'format': 'datalocal-database/2',
          'database': _databaseName,
          'collections': manifest.collections,
        }),
      );

  Future<void> _addCollectionToDatabase(String collection) async {
    final current = await _readDatabaseManifest();
    if (current.collections.contains(collection)) {
      return;
    }
    final collections = <String>[...current.collections, collection]..sort();
    await _writeDatabaseManifest(_DatabaseManifest(collections));
  }

  Future<void> _removeCollectionFromDatabase(String collection) async {
    final current = await _readDatabaseManifest();
    if (!current.collections.contains(collection)) {
      return;
    }
    await _writeDatabaseManifest(
      _DatabaseManifest(
        current.collections.where((item) => item != collection).toList(),
      ),
    );
  }

  Future<_CollectionManifest?> _readCollectionManifest(
    String collection,
  ) async {
    final raw = await _client.getString(_collectionKey(collection));
    if (raw == null) {
      return null;
    }
    final map = _decodeMap(raw, component: 'collectionManifest');
    if (map['format'] != 'datalocal-collection/2' ||
        map['collection'] != collection) {
      throw DataLocalCorruptionException(
        'Collection manifest identity or format is invalid.',
        context: <String, Object?>{'collection': collection},
      );
    }
    return _CollectionManifest(
      collection,
      (map['ids'] as List<dynamic>).cast<String>(),
      map['revision'] as int,
    );
  }

  Future<void> _writeCollectionManifest(_CollectionManifest manifest) =>
      _client.setString(
        _collectionKey(manifest.collection),
        jsonEncode(<String, Object?>{
          'format': 'datalocal-collection/2',
          'collection': manifest.collection,
          'revision': manifest.revision,
          'count': manifest.ids.length,
          'ids': manifest.ids,
        }),
      );

  String _encodeRecord(DataLocalStoredRecord record) =>
      jsonEncode(<String, Object?>{
        'format': 'datalocal-storage-record/2',
        'collection': record.collection,
        'id': record.id,
        'revision': record.revision,
        'formatVersion': record.formatVersion,
        'payload': base64UrlEncode(record.payload),
      });

  DataLocalStoredRecord _decodeRecord(
    String raw,
    String collection,
    String id,
  ) {
    try {
      final map = _decodeMap(raw, component: 'record');
      if (map['format'] != 'datalocal-storage-record/2' ||
          map['collection'] != collection ||
          map['id'] != id) {
        throw DataLocalCorruptionException(
          'Stored record identity or format is invalid.',
          context: <String, Object?>{
            'collection': collection,
            'documentId': id,
          },
        );
      }
      return DataLocalStoredRecord(
        collection: collection,
        id: id,
        revision: map['revision'] as int,
        formatVersion: map['formatVersion'] as int,
        payload: base64Url.decode(map['payload'] as String),
      );
    } on DataLocalException {
      rethrow;
    } catch (error, stackTrace) {
      throw DataLocalCorruptionException(
        'Stored record could not be decoded.',
        context: <String, Object?>{'collection': collection, 'documentId': id},
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  Map<String, dynamic> _decodeMap(String raw, {required String component}) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      throw DataLocalCorruptionException(
        'A SharedPreferences value contains invalid JSON.',
        context: <String, Object?>{'component': component},
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  String _collectionKey(String collection) =>
      '$_prefix.collection.${_token(collection)}';

  String _recordKey(String collection, String id) =>
      '$_prefix.record.${_token(collection)}.${_token(id)}';

  void _requireOpen() {
    if (!_isOpen) {
      throw const DataLocalClosedException(
        'SharedPreferences storage is not open.',
        context: <String, Object?>{'component': 'storage'},
      );
    }
  }

  static String _token(String value) =>
      base64UrlEncode(utf8.encode(value)).replaceAll('=', '');
}

final class _DatabaseManifest {
  const _DatabaseManifest(this.collections);

  final List<String> collections;
}

final class _CollectionManifest {
  const _CollectionManifest(this.collection, this.ids, this.revision);

  final String collection;
  final List<String> ids;
  final int revision;
}

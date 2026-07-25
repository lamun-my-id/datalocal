import 'dart:async';
import 'dart:typed_data';

import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/storage/datalocal_storage.dart';

/// In-memory storage used for unit tests and ephemeral databases.
final class DataLocalMemoryStorage implements DataLocalStorage {
  DataLocalMemoryStorage({
    this.operationDelay = Duration.zero,
    Map<String, Map<String, DataLocalStoredRecord>>? seed,
  }) : _records = _copySeed(seed);

  final Duration operationDelay;
  final Map<String, Map<String, DataLocalStoredRecord>> _records;

  bool _isOpen = false;
  String? _databaseName;
  List<int>? _journal;

  @override
  DataLocalStorageCapabilities get capabilities =>
      const DataLocalStorageCapabilities(
        supportsAtomicBatch: false,
        supportsIndexes: false,
        supportsQueryPushdown: false,
        supportsTransactions: false,
      );

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
    _isOpen = true;
    await _delay();
  }

  @override
  Future<DataLocalStoredRecord?> read(String collection, String id) async {
    _requireOpen();
    await _delay();
    return _records[collection]?[id]?.copy();
  }

  @override
  Future<List<DataLocalStoredRecord>> readCollection(String collection) async {
    _requireOpen();
    await _delay();
    final result =
        _records[collection]?.values
            .map((record) => record.copy())
            .toList(growable: false) ??
        const <DataLocalStoredRecord>[];
    return result.toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
  }

  @override
  Future<void> write(DataLocalStoredRecord record) async {
    _requireOpen();
    await _delay();
    final collection = _records.putIfAbsent(
      record.collection,
      () => <String, DataLocalStoredRecord>{},
    );
    collection[record.id] = record.copy();
  }

  @override
  Future<bool> delete(String collection, String id) async {
    _requireOpen();
    await _delay();
    final records = _records[collection];
    if (records == null) {
      return false;
    }
    final removed = records.remove(id) != null;
    if (records.isEmpty) {
      _records.remove(collection);
    }
    return removed;
  }

  @override
  Future<void> clearCollection(String collection) async {
    _requireOpen();
    await _delay();
    _records.remove(collection);
  }

  @override
  Future<Uint8List?> readJournal() async {
    _requireOpen();
    await _delay();
    final journal = _journal;
    return journal == null ? null : Uint8List.fromList(journal);
  }

  @override
  Future<void> writeJournal(Uint8List payload) async {
    _requireOpen();
    await _delay();
    _journal = List<int>.from(payload);
  }

  @override
  Future<void> clearJournal() async {
    _requireOpen();
    await _delay();
    _journal = null;
  }

  @override
  Future<void> close() async {
    if (!_isOpen) {
      return;
    }
    await _delay();
    _isOpen = false;
    _databaseName = null;
  }

  void _requireOpen() {
    if (!_isOpen) {
      throw const DataLocalClosedException(
        'Storage is not open.',
        context: <String, Object?>{'component': 'storage'},
      );
    }
  }

  Future<void> _delay() => operationDelay == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(operationDelay);

  static Map<String, Map<String, DataLocalStoredRecord>> _copySeed(
    Map<String, Map<String, DataLocalStoredRecord>>? seed,
  ) => <String, Map<String, DataLocalStoredRecord>>{
    for (final collection
        in seed?.entries ??
            const <MapEntry<String, Map<String, DataLocalStoredRecord>>>[])
      collection.key: <String, DataLocalStoredRecord>{
        for (final record in collection.value.entries)
          record.key: record.value.copy(),
      },
  };
}

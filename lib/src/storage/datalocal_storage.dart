import 'dart:typed_data';

import 'package:datalocal/src/document/document_id.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Features a storage adapter can perform natively.
final class DataLocalStorageCapabilities {
  const DataLocalStorageCapabilities({
    required this.supportsAtomicBatch,
    required this.supportsIndexes,
    required this.supportsQueryPushdown,
    required this.supportsTransactions,
  });

  const DataLocalStorageCapabilities.basic()
    : supportsAtomicBatch = false,
      supportsIndexes = false,
      supportsQueryPushdown = false,
      supportsTransactions = false;

  final bool supportsAtomicBatch;
  final bool supportsIndexes;
  final bool supportsQueryPushdown;
  final bool supportsTransactions;
}

/// Immutable configuration supplied when a storage adapter is opened.
final class DataLocalStorageContext {
  DataLocalStorageContext({required String databaseName})
    : databaseName = _validateName(databaseName);

  final String databaseName;

  static String _validateName(String value) {
    if (value.trim().isEmpty) {
      throw const DataLocalValidationException(
        'Database name must not be empty.',
        context: <String, Object?>{'field': 'databaseName'},
      );
    }
    return value;
  }
}

/// Encoded record passed across the storage boundary.
///
/// Payload bytes are copied on input and output so storage adapters cannot
/// mutate caller-owned buffers.
final class DataLocalStoredRecord {
  DataLocalStoredRecord({
    required String collection,
    required String id,
    required int revision,
    required int formatVersion,
    required Uint8List payload,
  }) : collection = _validateCollection(collection),
       id = DataLocalSecureDocumentIdGenerator.validate(id),
       revision = _validatePositive(revision, 'revision'),
       formatVersion = _validatePositive(formatVersion, 'formatVersion'),
       _payload = Uint8List.fromList(payload);

  final String collection;
  final String id;
  final int revision;
  final int formatVersion;
  final Uint8List _payload;

  Uint8List get payload => Uint8List.fromList(_payload);

  DataLocalStoredRecord copy() => DataLocalStoredRecord(
    collection: collection,
    id: id,
    revision: revision,
    formatVersion: formatVersion,
    payload: _payload,
  );

  static String _validateCollection(String value) {
    if (value.trim().isEmpty) {
      throw const DataLocalValidationException(
        'Collection name must not be empty.',
        context: <String, Object?>{'field': 'collection'},
      );
    }
    return value;
  }

  static int _validatePositive(int value, String field) {
    if (value < 1) {
      throw DataLocalValidationException(
        '$field must be at least one.',
        context: <String, Object?>{'field': field, 'value': value},
      );
    }
    return value;
  }
}

/// Persistence boundary implemented by every DataLocal storage backend.
abstract interface class DataLocalStorage {
  DataLocalStorageCapabilities get capabilities;

  bool get isOpen;

  Future<void> open(DataLocalStorageContext context);

  Future<DataLocalStoredRecord?> read(String collection, String id);

  Future<List<DataLocalStoredRecord>> readCollection(String collection);

  Future<void> write(DataLocalStoredRecord record);

  Future<bool> delete(String collection, String id);

  Future<void> clearCollection(String collection);

  /// Returns the database-level recovery journal, when a commit was interrupted.
  Future<Uint8List?> readJournal();

  /// Atomically replaces the database-level recovery journal blob.
  Future<void> writeJournal(Uint8List payload);

  /// Removes the recovery journal after a commit is fully durable.
  Future<void> clearJournal();

  Future<void> close();
}

/// Optional post-recovery integrity hook for manifest-based adapters.
abstract interface class DataLocalIntegrityVerifyingStorage {
  Future<void> verifyIntegrity();
}

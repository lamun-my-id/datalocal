// ignore_for_file: prefer_initializing_formals

import 'package:datalocal/src/codec/datalocal_codec.dart';
import 'package:datalocal/src/consistency/datalocal_commit_coordinator.dart';
import 'package:datalocal/src/document/datalocal_clock.dart';
import 'package:datalocal/src/document/datalocal_document.dart';
import 'package:datalocal/src/document/document_id.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/query/datalocal_query.dart';
import 'package:datalocal/src/reactive/datalocal_change.dart';
import 'package:datalocal/src/serialization/datalocal_record_serializer.dart';
import 'package:datalocal/src/storage/datalocal_storage.dart';

/// A typed set of documents sharing a storage namespace and codec.
final class DataLocalCollection<T> {
  /// Creates a collection wired to database internals.
  const DataLocalCollection.internal({
    required this.name,
    required DataLocalCodec<T> codec,
    required DataLocalStorage storage,
    required DataLocalRecordSerializer serializer,
    required DataLocalClock clock,
    required DataLocalDocumentIdGenerator idGenerator,
    required DataLocalCommitCoordinator coordinator,
    required DataLocalChangeHub changeHub,
    required void Function() requireDatabaseOpen,
  }) : _codec = codec,
       _storage = storage,
       _serializer = serializer,
       _clock = clock,
       _idGenerator = idGenerator,
       _coordinator = coordinator,
       _changeHub = changeHub,
       _requireDatabaseOpen = requireDatabaseOpen;

  /// Collection name used as the persistent namespace.
  final String name;
  final DataLocalCodec<T> _codec;
  final DataLocalStorage _storage;
  final DataLocalRecordSerializer _serializer;
  final DataLocalClock _clock;
  final DataLocalDocumentIdGenerator _idGenerator;
  final DataLocalCommitCoordinator _coordinator;
  final DataLocalChangeHub _changeHub;
  final void Function() _requireDatabaseOpen;

  /// Inserts [value] with an optional caller-supplied [id].
  ///
  /// Throws [DataLocalConflictException] when the identifier already exists.
  Future<DataLocalDocument<T>> insert(T value, {String? id}) async {
    _requireDatabaseOpen();
    return _coordinator.synchronized(() async {
      final document = DataLocalDocument<T>.create(
        data: value,
        codec: _codec,
        id: id,
        idGenerator: _idGenerator,
        clock: _clock,
      );
      if (await _storage.read(name, document.id) != null) {
        throw DataLocalConflictException(
          'A document with this ID already exists.',
          context: <String, Object?>{
            'collection': name,
            'documentId': document.id,
          },
        );
      }
      final record = await encodeForCommit(document);
      await _coordinator.commit(<DataLocalStorageMutation>[
        DataLocalStorageMutation.write(record),
      ]);
      _emit(document.id, DataLocalMutationType.insert);
      return document;
    });
  }

  /// Imports an externally decoded document while preserving its metadata.
  ///
  /// Intended for verified migration tools. Existing IDs are never overwritten.
  Future<DataLocalDocument<T>> importDocument(
    DataLocalDocument<T> document,
  ) async {
    _requireDatabaseOpen();
    return _coordinator.synchronized(() async {
      if (await _storage.read(name, document.id) != null) {
        throw DataLocalConflictException(
          'A document with this ID already exists.',
          context: <String, Object?>{
            'collection': name,
            'documentId': document.id,
          },
        );
      }
      final normalized = DataLocalDocument<T>(
        metadata: document.metadata,
        data: _codec.decode(_codec.encode(document.data)),
      );
      await _coordinator.commit(<DataLocalStorageMutation>[
        DataLocalStorageMutation.write(await encodeForCommit(normalized)),
      ]);
      _emit(normalized.id, DataLocalMutationType.insert);
      return normalized;
    });
  }

  /// Returns the document identified by [id], or `null` when absent.
  Future<DataLocalDocument<T>?> get(String id) async {
    _requireDatabaseOpen();
    final record = await _storage.read(name, id);
    return record == null ? null : _decode(record);
  }

  /// Returns the document identified by [id].
  ///
  /// Throws [DataLocalNotFoundException] when it does not exist.
  Future<DataLocalDocument<T>> require(String id) async {
    final document = await get(id);
    if (document == null) {
      throw DataLocalNotFoundException(
        'Document not found.',
        context: <String, Object?>{'collection': name, 'documentId': id},
      );
    }
    return document;
  }

  /// Replaces an existing document and increments its revision.
  ///
  /// [expectedRevision] enables optimistic concurrency control.
  Future<DataLocalDocument<T>> replace(
    String id,
    T value, {
    int? expectedRevision,
  }) async {
    _requireDatabaseOpen();
    return _coordinator.synchronized(() async {
      final current = await require(id);
      _checkRevision(current, expectedRevision);
      final encoded = _codec.encode(value);
      final decoded = _codec.decode(encoded);
      final updated = DataLocalDocument<T>(
        metadata: current.metadata.nextRevision(_clock.now()),
        data: decoded,
      );
      final record = await encodeForCommit(updated);
      await _coordinator.commit(<DataLocalStorageMutation>[
        DataLocalStorageMutation.write(record),
      ]);
      _emit(updated.id, DataLocalMutationType.update);
      return updated;
    });
  }

  /// Shallow-merges [values] into an existing document.
  ///
  /// Nested maps are replaced rather than recursively merged.
  Future<DataLocalDocument<T>> patch(
    String id,
    Map<String, Object?> values, {
    int? expectedRevision,
  }) async {
    _requireDatabaseOpen();
    return _coordinator.synchronized(() async {
      final current = await require(id);
      _checkRevision(current, expectedRevision);
      final currentMap = _codec.encode(current.data);
      final merged = <String, Object?>{...currentMap, ...values};
      final updated = DataLocalDocument<T>(
        metadata: current.metadata.nextRevision(_clock.now()),
        data: _codec.decode(merged),
      );
      final record = await encodeForCommit(updated);
      await _coordinator.commit(<DataLocalStorageMutation>[
        DataLocalStorageMutation.write(record),
      ]);
      _emit(updated.id, DataLocalMutationType.update);
      return updated;
    });
  }

  /// Deletes [id] and returns whether a document existed.
  Future<bool> delete(String id, {int? expectedRevision}) async {
    _requireDatabaseOpen();
    return _coordinator.synchronized(() async {
      if (expectedRevision != null) {
        final current = await require(id);
        _checkRevision(current, expectedRevision);
      }
      if (await _storage.read(name, id) == null) {
        return false;
      }
      await _coordinator.commit(<DataLocalStorageMutation>[
        DataLocalStorageMutation.delete(collection: name, id: id),
      ]);
      _emit(id, DataLocalMutationType.delete);
      return true;
    });
  }

  /// Atomically deletes every document in this collection.
  Future<void> clear() async {
    _requireDatabaseOpen();
    await _coordinator.synchronized(() async {
      final records = await _storage.readCollection(name);
      await _coordinator.commit(<DataLocalStorageMutation>[
        for (final record in records)
          DataLocalStorageMutation.delete(
            collection: record.collection,
            id: record.id,
          ),
      ]);
      _changeHub.emit(<DataLocalDocumentChange>[
        for (final record in records)
          DataLocalDocumentChange(
            collection: name,
            documentId: record.id,
            type: DataLocalMutationType.delete,
          ),
      ]);
    });
  }

  /// Creates an immutable query rooted at this collection.
  DataLocalQuery<T> query() => DataLocalQuery<T>.root(this);

  /// Successful commit events that affect this collection.
  Stream<DataLocalCommitEvent> get changes => _changeHub.forCollection(name);

  /// Reads and decodes all documents for query evaluation.
  Future<List<DataLocalDocument<T>>> readAllForQuery() async {
    _requireDatabaseOpen();
    final records = await _storage.readCollection(name);
    final result = <DataLocalDocument<T>>[];
    for (final record in records) {
      result.add(await _decode(record));
    }
    return List<DataLocalDocument<T>>.unmodifiable(result);
  }

  /// Encodes [value] into the map evaluated by the query engine.
  Map<String, Object?> encodeForQuery(T value) => _codec.encode(value);

  /// Prepares an insert for a logical write batch.
  Future<DataLocalStorageMutation> prepareInsertForBatch(
    T value, {
    String? id,
  }) async {
    final document = DataLocalDocument<T>.create(
      data: value,
      codec: _codec,
      id: id,
      idGenerator: _idGenerator,
      clock: _clock,
    );
    if (await _storage.read(name, document.id) != null) {
      throw DataLocalConflictException(
        'A document with this ID already exists.',
        context: <String, Object?>{
          'collection': name,
          'documentId': document.id,
        },
      );
    }
    return DataLocalStorageMutation.write(await encodeForCommit(document));
  }

  /// Prepares a replacement for a logical write batch.
  Future<DataLocalStorageMutation> prepareReplaceForBatch(
    String id,
    T value, {
    int? expectedRevision,
  }) async {
    final current = await require(id);
    _checkRevision(current, expectedRevision);
    final updated = DataLocalDocument<T>(
      metadata: current.metadata.nextRevision(_clock.now()),
      data: _codec.decode(_codec.encode(value)),
    );
    return DataLocalStorageMutation.write(await encodeForCommit(updated));
  }

  /// Prepares a deletion for a logical write batch.
  Future<DataLocalStorageMutation> prepareDeleteForBatch(
    String id, {
    int? expectedRevision,
  }) async {
    final current = await require(id);
    _checkRevision(current, expectedRevision);
    return DataLocalStorageMutation.delete(collection: name, id: id);
  }

  /// Encodes [document] into its persistent record representation.
  Future<DataLocalStoredRecord> encodeForCommit(
    DataLocalDocument<T> document,
  ) async {
    final encoded = _codec.encode(document.data);
    return _serializer.encode(
      collection: name,
      document: document,
      data: encoded,
    );
  }

  Future<DataLocalDocument<T>> _decode(DataLocalStoredRecord record) async {
    final decoded = await _serializer.decode(record);
    return DataLocalDocument<T>(
      metadata: decoded.metadata,
      data: _codec.decode(decoded.data),
    );
  }

  void _checkRevision(DataLocalDocument<T> current, int? expectedRevision) {
    if (expectedRevision != null && current.revision != expectedRevision) {
      throw DataLocalConflictException(
        'Document revision does not match the expected revision.',
        context: <String, Object?>{
          'collection': name,
          'documentId': current.id,
          'expectedRevision': expectedRevision,
          'actualRevision': current.revision,
        },
      );
    }
  }

  void _emit(String id, DataLocalMutationType type) {
    _changeHub.emit(<DataLocalDocumentChange>[
      DataLocalDocumentChange(collection: name, documentId: id, type: type),
    ]);
  }
}

// ignore_for_file: prefer_initializing_formals

import 'package:datalocal/src/codec/datalocal_codec.dart';
import 'package:datalocal/src/consistency/datalocal_commit_coordinator.dart';
import 'package:datalocal/src/database/datalocal_collection.dart';
import 'package:datalocal/src/database/datalocal_write_batch.dart';
import 'package:datalocal/src/document/datalocal_clock.dart';
import 'package:datalocal/src/document/document_id.dart';
import 'package:datalocal/src/encryption/datalocal_encryption.dart';
import 'package:datalocal/src/encryption/no_encryption_provider.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/reactive/datalocal_change.dart';
import 'package:datalocal/src/serialization/datalocal_record_serializer.dart';
import 'package:datalocal/src/storage/datalocal_storage.dart';

/// Open DataLocal 2.0 database instance.
final class DataLocalDatabase {
  DataLocalDatabase._({
    required this.name,
    required this._storage,
    required DataLocalEncryptionProvider encryption,
    required this._clock,
    required this._idGenerator,
    required DataLocalCommitCoordinator coordinator,
  }) : _coordinator = coordinator,
       _changeHub = DataLocalChangeHub(),
       _serializer = DataLocalRecordSerializer(
         databaseName: name,
         encryption: encryption,
       );

  /// Validated name used to namespace every stored record.
  final String name;
  final DataLocalStorage _storage;
  final DataLocalClock _clock;
  final DataLocalDocumentIdGenerator _idGenerator;
  final DataLocalRecordSerializer _serializer;
  final DataLocalCommitCoordinator _coordinator;
  final DataLocalChangeHub _changeHub;
  bool _isClosed = false;
  bool _isClosing = false;
  Future<void>? _closeFuture;

  /// Whether this database has completed closing.
  bool get isClosed => _isClosed;

  /// Commit events emitted after successful mutations.
  Stream<DataLocalCommitEvent> get changes => _changeHub.events;

  /// Capabilities advertised by the configured storage provider.
  DataLocalStorageCapabilities get storageCapabilities => _storage.capabilities;

  /// Opens a database and performs pending journal recovery.
  ///
  /// [encryption] defaults to plaintext storage and must be configured
  /// explicitly when data-at-rest encryption is required.
  static Future<DataLocalDatabase> open({
    required String name,
    required DataLocalStorage storage,
    DataLocalEncryptionProvider encryption =
        const DataLocalNoEncryptionProvider(),
    DataLocalClock clock = const DataLocalSystemClock(),
    DataLocalDocumentIdGenerator? idGenerator,
    DataLocalFailureInjector? failureInjector,
  }) async {
    final context = DataLocalStorageContext(databaseName: name);
    await storage.open(context);
    final coordinator = DataLocalCommitCoordinator(
      storage: storage,
      failureInjector: failureInjector,
    );
    await coordinator.recover();
    if (storage
        case final DataLocalIntegrityVerifyingStorage verifyingStorage) {
      await verifyingStorage.verifyIntegrity();
    }
    return DataLocalDatabase._(
      name: context.databaseName,
      storage: storage,
      encryption: encryption,
      clock: clock,
      idGenerator: idGenerator ?? DataLocalSecureDocumentIdGenerator(),
      coordinator: coordinator,
    );
  }

  /// Returns a map-backed collection named [name].
  DataLocalCollection<Map<String, Object?>> mapCollection(String name) =>
      collection<Map<String, Object?>>(name, codec: const DataLocalMapCodec());

  /// Returns a typed collection using [codec] for serialization.
  DataLocalCollection<T> collection<T>(
    String name, {
    required DataLocalCodec<T> codec,
  }) {
    _requireOpen();
    if (name.trim().isEmpty) {
      throw const DataLocalValidationException(
        'Collection name must not be empty.',
        context: <String, Object?>{'field': 'collection'},
      );
    }
    return DataLocalCollection<T>.internal(
      name: name,
      codec: codec,
      storage: _storage,
      serializer: _serializer,
      clock: _clock,
      idGenerator: _idGenerator,
      coordinator: _coordinator,
      changeHub: _changeHub,
      requireDatabaseOpen: _requireOpen,
    );
  }

  /// Atomically commits the mutations added synchronously by [build].
  Future<void> writeBatch(void Function(DataLocalWriteBatch batch) build) {
    _requireOpen();
    final batch = DataLocalWriteBatch.internal();
    build(batch);
    return _coordinator.synchronized(() async {
      _requireOpen();
      final prepared = await batch.sealAndPrepare();
      await _coordinator.commit(
        prepared.map((item) => item.mutation).toList(growable: false),
      );
      _changeHub.emit(
        prepared.map((item) => item.change).toList(growable: false),
      );
    });
  }

  /// Drains accepted writes, closes storage and event streams.
  Future<void> close() {
    if (_isClosed) {
      return Future<void>.value();
    }
    final current = _closeFuture;
    if (current != null) {
      return current;
    }
    _isClosing = true;
    return _closeFuture = _performClose();
  }

  Future<void> _performClose() async {
    await _coordinator.drain();
    await _storage.close();
    await _changeHub.close();
    _isClosed = true;
    _isClosing = false;
  }

  void _requireOpen() {
    if (_isClosed || _isClosing) {
      throw const DataLocalClosedException('Database is closed.');
    }
  }
}

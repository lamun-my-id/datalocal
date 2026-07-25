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
       _serializer = DataLocalRecordSerializer(
         databaseName: name,
         encryption: encryption,
       );

  final String name;
  final DataLocalStorage _storage;
  final DataLocalClock _clock;
  final DataLocalDocumentIdGenerator _idGenerator;
  final DataLocalRecordSerializer _serializer;
  final DataLocalCommitCoordinator _coordinator;
  bool _isClosed = false;

  bool get isClosed => _isClosed;
  DataLocalStorageCapabilities get storageCapabilities => _storage.capabilities;

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

  DataLocalCollection<Map<String, Object?>> mapCollection(String name) =>
      collection<Map<String, Object?>>(name, codec: const DataLocalMapCodec());

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
      requireDatabaseOpen: _requireOpen,
    );
  }

  Future<void> writeBatch(void Function(DataLocalWriteBatch batch) build) {
    _requireOpen();
    final batch = DataLocalWriteBatch.internal();
    build(batch);
    return _coordinator.synchronized(() async {
      _requireOpen();
      await _coordinator.commit(await batch.sealAndPrepare());
    });
  }

  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    await _storage.close();
    _isClosed = true;
  }

  void _requireOpen() {
    if (_isClosed) {
      throw const DataLocalClosedException('Database is closed.');
    }
  }
}

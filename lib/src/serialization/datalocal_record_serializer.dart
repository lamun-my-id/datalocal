import 'dart:convert';
import 'dart:typed_data';

import 'package:datalocal/src/document/datalocal_document.dart';
import 'package:datalocal/src/document/datalocal_document_validator.dart';
import 'package:datalocal/src/document/datalocal_metadata.dart';
import 'package:datalocal/src/encryption/datalocal_encryption.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/storage/datalocal_storage.dart';

final class DataLocalDecodedRecord {
  const DataLocalDecodedRecord({
    required this.metadata,
    required this.data,
    required this.schemaVersion,
  });

  final DataLocalMetadata metadata;
  final Map<String, Object?> data;
  final int schemaVersion;
}

/// Converts logical documents into storage-independent encrypted records.
final class DataLocalRecordSerializer {
  const DataLocalRecordSerializer({
    required this.databaseName,
    required this.encryption,
    this.schemaVersion = 1,
    this.validator = const DataLocalDocumentValidator(),
  });

  static const int storedRecordFormatVersion = 2;
  static const int envelopeFormatVersion = 1;

  final String databaseName;
  final DataLocalEncryptionProvider encryption;
  final int schemaVersion;
  final DataLocalDocumentValidator validator;

  Future<DataLocalStoredRecord> encode<T>({
    required String collection,
    required DataLocalDocument<T> document,
    required Map<String, Object?> data,
  }) async {
    try {
      final frozen = validator.validateAndFreeze(data);
      final logicalRecord = <String, Object?>{
        'format': 'datalocal/2',
        'collection': collection,
        'id': document.id,
        'revision': document.revision,
        'createdAtUs': document.createdAt.microsecondsSinceEpoch,
        'updatedAtUs': document.updatedAt.microsecondsSinceEpoch,
        'codec': 'json/1',
        'schemaVersion': schemaVersion,
        'data': frozen,
      };
      final plainText = Uint8List.fromList(
        utf8.encode(jsonEncode(logicalRecord)),
      );
      final context = _context(collection, document.id, schemaVersion);
      final envelope = await encryption.encrypt(plainText, context: context);
      final storedPayload = Uint8List.fromList(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'format': 'datalocal-envelope/1',
            'formatVersion': envelope.formatVersion,
            'algorithm': envelope.algorithm,
            'keyId': envelope.keyId,
            'nonce': base64UrlEncode(envelope.nonce),
            'ciphertext': base64UrlEncode(envelope.cipherText),
            'mac': base64UrlEncode(envelope.authenticationTag),
          }),
        ),
      );
      return DataLocalStoredRecord(
        collection: collection,
        id: document.id,
        revision: document.revision,
        formatVersion: storedRecordFormatVersion,
        payload: storedPayload,
      );
    } on DataLocalException {
      rethrow;
    } catch (error, stackTrace) {
      throw DataLocalSerializationException(
        'Failed to serialize a document.',
        context: <String, Object?>{
          'collection': collection,
          'documentId': document.id,
        },
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  Future<DataLocalDecodedRecord> decode(DataLocalStoredRecord record) async {
    try {
      if (record.formatVersion != storedRecordFormatVersion) {
        throw DataLocalUnsupportedException(
          'Unsupported stored record format.',
          context: <String, Object?>{
            'formatVersion': record.formatVersion,
            'documentId': record.id,
          },
        );
      }
      final envelopeMap =
          jsonDecode(utf8.decode(record.payload)) as Map<String, dynamic>;
      if (envelopeMap['format'] != 'datalocal-envelope/1') {
        throw const DataLocalCorruptionException(
          'Stored record has an invalid envelope format.',
        );
      }
      final envelope = DataLocalEncryptedEnvelope(
        formatVersion: envelopeMap['formatVersion'] as int,
        algorithm: envelopeMap['algorithm'] as String,
        keyId: envelopeMap['keyId'] as String,
        nonce: base64Url.decode(envelopeMap['nonce'] as String),
        cipherText: base64Url.decode(envelopeMap['ciphertext'] as String),
        authenticationTag: base64Url.decode(envelopeMap['mac'] as String),
      );
      final context = _context(record.collection, record.id, schemaVersion);
      final plainText = await encryption.decrypt(envelope, context: context);
      final logical =
          jsonDecode(utf8.decode(plainText)) as Map<String, dynamic>;

      _verifyIdentity(logical, record);
      final decodedSchemaVersion = logical['schemaVersion'] as int;
      if (decodedSchemaVersion != schemaVersion) {
        throw DataLocalUnsupportedException(
          'Unsupported document schema version.',
          context: <String, Object?>{
            'schemaVersion': decodedSchemaVersion,
            'documentId': record.id,
          },
        );
      }
      final rawData = Map<String, Object?>.from(
        logical['data'] as Map<dynamic, dynamic>,
      );
      return DataLocalDecodedRecord(
        metadata: DataLocalMetadata(
          id: logical['id'] as String,
          createdAt: DateTime.fromMicrosecondsSinceEpoch(
            logical['createdAtUs'] as int,
            isUtc: true,
          ),
          updatedAt: DateTime.fromMicrosecondsSinceEpoch(
            logical['updatedAtUs'] as int,
            isUtc: true,
          ),
          revision: logical['revision'] as int,
        ),
        data: validator.validateAndFreeze(rawData),
        schemaVersion: decodedSchemaVersion,
      );
    } on DataLocalException {
      rethrow;
    } catch (error, stackTrace) {
      throw DataLocalCorruptionException(
        'Stored record could not be decoded.',
        context: <String, Object?>{
          'collection': record.collection,
          'documentId': record.id,
        },
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  DataLocalEncryptionContext _context(
    String collection,
    String documentId,
    int version,
  ) => DataLocalEncryptionContext(
    databaseName: databaseName,
    collection: collection,
    documentId: documentId,
    schemaVersion: version,
  );

  void _verifyIdentity(
    Map<String, dynamic> logical,
    DataLocalStoredRecord record,
  ) {
    final valid =
        logical['format'] == 'datalocal/2' &&
        logical['collection'] == record.collection &&
        logical['id'] == record.id &&
        logical['revision'] == record.revision;
    if (!valid) {
      throw DataLocalCorruptionException(
        'Stored record identity does not match its storage key.',
        context: <String, Object?>{
          'collection': record.collection,
          'documentId': record.id,
        },
      );
    }
  }
}

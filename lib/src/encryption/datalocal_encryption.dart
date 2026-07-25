import 'dart:convert';
import 'dart:typed_data';

import 'package:datalocal/src/document/document_id.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Identifies the record being encrypted and becomes authenticated metadata.
final class DataLocalEncryptionContext {
  DataLocalEncryptionContext({
    required String databaseName,
    required String collection,
    required String documentId,
    required int schemaVersion,
  }) : databaseName = _validateName(databaseName, 'databaseName'),
       collection = _validateName(collection, 'collection'),
       documentId = DataLocalSecureDocumentIdGenerator.validate(documentId),
       schemaVersion = _validateVersion(schemaVersion);

  final String databaseName;
  final String collection;
  final String documentId;
  final int schemaVersion;

  Uint8List associatedData() {
    final value =
        'datalocal/2\u0000$databaseName\u0000$collection\u0000'
        '$documentId\u0000$schemaVersion';
    return Uint8List.fromList(utf8.encode(value));
  }

  static String _validateName(String value, String field) {
    if (value.trim().isEmpty) {
      throw DataLocalValidationException(
        '$field must not be empty.',
        context: <String, Object?>{'field': field},
      );
    }
    return value;
  }

  static int _validateVersion(int value) {
    if (value < 1) {
      throw DataLocalValidationException(
        'schemaVersion must be at least one.',
        context: <String, Object?>{'field': 'schemaVersion', 'value': value},
      );
    }
    return value;
  }
}

/// Storage-independent authenticated-encryption envelope.
final class DataLocalEncryptedEnvelope {
  DataLocalEncryptedEnvelope({
    required int formatVersion,
    required String algorithm,
    required String keyId,
    required Uint8List nonce,
    required Uint8List cipherText,
    required Uint8List authenticationTag,
  }) : formatVersion = _validateVersion(formatVersion),
       algorithm = _validateName(algorithm, 'algorithm'),
       keyId = _validateName(keyId, 'keyId'),
       _nonce = Uint8List.fromList(nonce),
       _cipherText = Uint8List.fromList(cipherText),
       _authenticationTag = Uint8List.fromList(authenticationTag);

  final int formatVersion;
  final String algorithm;
  final String keyId;
  final Uint8List _nonce;
  final Uint8List _cipherText;
  final Uint8List _authenticationTag;

  Uint8List get nonce => Uint8List.fromList(_nonce);
  Uint8List get cipherText => Uint8List.fromList(_cipherText);
  Uint8List get authenticationTag => Uint8List.fromList(_authenticationTag);

  static int _validateVersion(int value) {
    if (value < 1) {
      throw DataLocalValidationException(
        'Envelope format version must be at least one.',
        context: <String, Object?>{'field': 'formatVersion', 'value': value},
      );
    }
    return value;
  }

  static String _validateName(String value, String field) {
    if (value.trim().isEmpty) {
      throw DataLocalValidationException(
        '$field must not be empty.',
        context: <String, Object?>{'field': field},
      );
    }
    return value;
  }
}

/// Authenticated-encryption boundary.
abstract interface class DataLocalEncryptionProvider {
  String get algorithm;

  Future<DataLocalEncryptedEnvelope> encrypt(
    Uint8List plainText, {
    required DataLocalEncryptionContext context,
  });

  Future<Uint8List> decrypt(
    DataLocalEncryptedEnvelope envelope, {
    required DataLocalEncryptionContext context,
  });
}

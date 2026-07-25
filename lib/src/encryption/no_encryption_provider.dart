import 'dart:typed_data';

import 'package:datalocal/src/encryption/datalocal_encryption.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Explicit plaintext provider for caches and tests.
///
/// This provider offers no confidentiality or tamper protection.
final class DataLocalNoEncryptionProvider
    implements DataLocalEncryptionProvider {
  const DataLocalNoEncryptionProvider();

  static const String keyIdentifier = 'none';

  @override
  String get algorithm => 'none';

  @override
  Future<DataLocalEncryptedEnvelope> encrypt(
    Uint8List plainText, {
    required DataLocalEncryptionContext context,
  }) async => DataLocalEncryptedEnvelope(
    formatVersion: 1,
    algorithm: algorithm,
    keyId: keyIdentifier,
    nonce: Uint8List(0),
    cipherText: plainText,
    authenticationTag: Uint8List(0),
  );

  @override
  Future<Uint8List> decrypt(
    DataLocalEncryptedEnvelope envelope, {
    required DataLocalEncryptionContext context,
  }) async {
    if (envelope.algorithm != algorithm ||
        envelope.keyId != keyIdentifier ||
        envelope.nonce.isNotEmpty ||
        envelope.authenticationTag.isNotEmpty) {
      throw const DataLocalEncryptionException(
        'Invalid plaintext envelope.',
        context: <String, Object?>{'algorithm': 'none'},
      );
    }
    return envelope.cipherText;
  }
}

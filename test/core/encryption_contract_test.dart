import 'dart:typed_data';

import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

import '../contracts/encryption_contract.dart';

void main() {
  encryptionRoundTripContract('none', DataLocalNoEncryptionProvider.new);

  test('plaintext provider rejects malformed envelopes', () async {
    const provider = DataLocalNoEncryptionProvider();
    final context = DataLocalEncryptionContext(
      databaseName: 'db',
      collection: 'notes',
      documentId: 'note-1',
      schemaVersion: 1,
    );
    final malformed = DataLocalEncryptedEnvelope(
      formatVersion: 1,
      algorithm: 'AES-256-GCM',
      keyId: 'key-1',
      nonce: Uint8List(12),
      cipherText: Uint8List(0),
      authenticationTag: Uint8List(16),
    );

    expect(
      () => provider.decrypt(malformed, context: context),
      throwsA(isA<DataLocalEncryptionException>()),
    );
  });

  test('encryption context binds all record identity fields', () {
    final context = DataLocalEncryptionContext(
      databaseName: 'db',
      collection: 'notes',
      documentId: 'note-1',
      schemaVersion: 2,
    );

    expect(
      String.fromCharCodes(context.associatedData()),
      'datalocal/2\u0000db\u0000notes\u0000note-1\u00002',
    );
  });
}

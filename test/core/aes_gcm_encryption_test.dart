import 'dart:typed_data';

import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

import '../contracts/encryption_contract.dart';

void main() {
  encryptionRoundTripContract(
    'AES-256-GCM',
    () => DataLocalAesGcmEncryptionProvider(
      keyProvider: DataLocalMemoryKeyProvider(),
    ),
  );

  test('uses unique 96-bit nonces and a 128-bit authentication tag', () async {
    final encryption = DataLocalAesGcmEncryptionProvider(
      keyProvider: DataLocalMemoryKeyProvider(),
    );
    final context = _context();
    final envelopes = await Future.wait(
      List<Future<DataLocalEncryptedEnvelope>>.generate(
        100,
        (_) => encryption.encrypt(
          Uint8List.fromList(<int>[1, 2, 3]),
          context: context,
        ),
      ),
    );

    expect(envelopes.every((item) => item.nonce.length == 12), isTrue);
    expect(
      envelopes.every((item) => item.authenticationTag.length == 16),
      isTrue,
    );
    expect(
      envelopes.map((item) => item.nonce.join(',')).toSet(),
      hasLength(100),
    );
  });

  test(
    'detects ciphertext, tag, nonce, and associated-data tampering',
    () async {
      final encryption = DataLocalAesGcmEncryptionProvider(
        keyProvider: DataLocalMemoryKeyProvider(),
      );
      final context = _context();
      final envelope = await encryption.encrypt(
        Uint8List.fromList(<int>[1, 2, 3]),
        context: context,
      );

      for (final tampered in <DataLocalEncryptedEnvelope>[
        _copy(envelope, cipherText: _flip(envelope.cipherText)),
        _copy(envelope, tag: _flip(envelope.authenticationTag)),
        _copy(envelope, nonce: _flip(envelope.nonce)),
      ]) {
        await expectLater(
          encryption.decrypt(tampered, context: context),
          throwsA(isA<DataLocalEncryptionException>()),
        );
      }
      await expectLater(
        encryption.decrypt(
          envelope,
          context: DataLocalEncryptionContext(
            databaseName: 'other',
            collection: 'notes',
            documentId: 'note-1',
            schemaVersion: 1,
          ),
        ),
        throwsA(isA<DataLocalEncryptionException>()),
      );
    },
  );

  test('reads historical records after active key rotation', () async {
    final keys = DataLocalMemoryKeyProvider();
    final encryption = DataLocalAesGcmEncryptionProvider(keyProvider: keys);
    final context = _context();
    final before = await encryption.encrypt(
      Uint8List.fromList(<int>[1]),
      context: context,
    );

    final rotated = await keys.rotate();
    final after = await encryption.encrypt(
      Uint8List.fromList(<int>[2]),
      context: context,
    );

    expect(after.keyId, rotated.id);
    expect(after.keyId, isNot(before.keyId));
    expect(await encryption.decrypt(before, context: context), <int>[1]);
    expect(await encryption.decrypt(after, context: context), <int>[2]);
  });

  test('rejects keys that are not exactly 256 bits', () async {
    final keys = DataLocalMemoryKeyProvider(
      initialKey: DataLocalKeyMaterial(
        id: 'short',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    final encryption = DataLocalAesGcmEncryptionProvider(keyProvider: keys);
    await expectLater(
      encryption.encrypt(Uint8List(0), context: _context()),
      throwsA(isA<DataLocalEncryptionException>()),
    );
  });
}

DataLocalEncryptionContext _context() => DataLocalEncryptionContext(
  databaseName: 'db',
  collection: 'notes',
  documentId: 'note-1',
  schemaVersion: 1,
);

DataLocalEncryptedEnvelope _copy(
  DataLocalEncryptedEnvelope source, {
  Uint8List? nonce,
  Uint8List? cipherText,
  Uint8List? tag,
}) => DataLocalEncryptedEnvelope(
  formatVersion: source.formatVersion,
  algorithm: source.algorithm,
  keyId: source.keyId,
  nonce: nonce ?? source.nonce,
  cipherText: cipherText ?? source.cipherText,
  authenticationTag: tag ?? source.authenticationTag,
);

Uint8List _flip(Uint8List source) {
  final result = Uint8List.fromList(source);
  result[0] ^= 1;
  return result;
}

import 'dart:typed_data';

import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

typedef EncryptionFactory = DataLocalEncryptionProvider Function();

void encryptionRoundTripContract(
  String name,
  EncryptionFactory createEncryption,
) {
  group('$name encryption round-trip contract', () {
    test('round trips and protects caller-owned byte buffers', () async {
      final encryption = createEncryption();
      final plainText = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final context = DataLocalEncryptionContext(
        databaseName: 'db',
        collection: 'notes',
        documentId: 'note-1',
        schemaVersion: 1,
      );

      final envelope = await encryption.encrypt(plainText, context: context);
      plainText[0] = 99;

      final decrypted = await encryption.decrypt(envelope, context: context);
      expect(decrypted, <int>[1, 2, 3, 4]);

      final exposedCipherText = envelope.cipherText;
      if (exposedCipherText.isNotEmpty) {
        exposedCipherText[0] = 88;
      }
      expect(await encryption.decrypt(envelope, context: context), <int>[
        1,
        2,
        3,
        4,
      ]);
    });
  });
}

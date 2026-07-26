import 'dart:math';
import 'dart:typed_data';

import 'package:datalocal/src/encryption/datalocal_encryption.dart';
import 'package:datalocal/src/encryption/datalocal_key_provider.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/pointycastle.dart';

/// AES-256-GCM authenticated encryption with 96-bit random nonces.
final class DataLocalAesGcmEncryptionProvider
    implements DataLocalEncryptionProvider {
  /// Creates an AES-GCM provider backed by [keyProvider].
  DataLocalAesGcmEncryptionProvider({required this.keyProvider, Random? random})
    : _random = random ?? Random.secure();

  /// Required AES-256 key length in bytes.
  static const int keyByteLength = 32;

  /// Random GCM nonce length in bytes.
  static const int nonceByteLength = 12;

  /// Authentication tag length in bytes.
  static const int authenticationTagByteLength = 16;

  /// Provider used to resolve active and historical encryption keys.
  final DataLocalKeyProvider keyProvider;
  final Random _random;

  @override
  /// Algorithm identifier stored in encrypted envelopes.
  String get algorithm => 'AES-256-GCM';

  @override
  /// Encrypts [plainText] and authenticates the supplied record [context].
  Future<DataLocalEncryptedEnvelope> encrypt(
    Uint8List plainText, {
    required DataLocalEncryptionContext context,
  }) async {
    final key = await keyProvider.activeKey();
    _validateKey(key);
    final nonce = Uint8List.fromList(
      List<int>.generate(nonceByteLength, (_) => _random.nextInt(256)),
    );
    try {
      final output = _process(
        encrypting: true,
        input: Uint8List.fromList(plainText),
        key: key.bytes,
        nonce: nonce,
        associatedData: context.associatedData(),
      );
      final cipherText = output.sublist(
        0,
        output.length - authenticationTagByteLength,
      );
      final tag = output.sublist(output.length - authenticationTagByteLength);
      return DataLocalEncryptedEnvelope(
        formatVersion: 1,
        algorithm: algorithm,
        keyId: key.id,
        nonce: nonce,
        cipherText: cipherText,
        authenticationTag: tag,
      );
    } catch (error, stackTrace) {
      throw DataLocalEncryptionException(
        'Document encryption failed.',
        context: <String, Object?>{'algorithm': algorithm, 'keyId': key.id},
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  @override
  /// Authenticates and decrypts [envelope] for the supplied record [context].
  Future<Uint8List> decrypt(
    DataLocalEncryptedEnvelope envelope, {
    required DataLocalEncryptionContext context,
  }) async {
    if (envelope.algorithm != algorithm ||
        envelope.formatVersion != 1 ||
        envelope.nonce.length != nonceByteLength ||
        envelope.authenticationTag.length != authenticationTagByteLength) {
      throw DataLocalEncryptionException(
        'Encrypted envelope parameters are invalid.',
        context: <String, Object?>{
          'algorithm': envelope.algorithm,
          'keyId': envelope.keyId,
        },
      );
    }
    final key = await keyProvider.keyById(envelope.keyId);
    if (key == null) {
      throw DataLocalEncryptionException(
        'The encryption key is unavailable.',
        context: <String, Object?>{
          'algorithm': algorithm,
          'keyId': envelope.keyId,
        },
      );
    }
    _validateKey(key);
    try {
      return _process(
        encrypting: false,
        input: Uint8List.fromList(<int>[
          ...envelope.cipherText,
          ...envelope.authenticationTag,
        ]),
        key: key.bytes,
        nonce: envelope.nonce,
        associatedData: context.associatedData(),
      );
    } catch (error, stackTrace) {
      throw DataLocalEncryptionException(
        'Encrypted document authentication failed.',
        context: <String, Object?>{
          'algorithm': algorithm,
          'keyId': envelope.keyId,
        },
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  Uint8List _process({
    required bool encrypting,
    required Uint8List input,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List associatedData,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        encrypting,
        AEADParameters(
          KeyParameter(key),
          authenticationTagByteLength * 8,
          nonce,
          associatedData,
        ),
      );
    return cipher.process(input);
  }

  void _validateKey(DataLocalKeyMaterial key) {
    if (key.bytes.length != keyByteLength) {
      throw DataLocalEncryptionException(
        'AES-256-GCM requires a 256-bit key.',
        context: <String, Object?>{'algorithm': algorithm, 'keyId': key.id},
      );
    }
  }
}

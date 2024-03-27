// ignore_for_file: use_super_parameters

import 'dart:convert' as convert;
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' hide Signer hide RSASigner;

class EncryptUtil {
  static final Key _key = Key.fromUtf8('my 32 length key................');
  static final IV _iv = IV.fromLength(8);
  static final _Encrypter _encrypter = _Encrypter(_Salsa20(_key));

  /// To Encrypt String
  String encript(String value) {
    return _encrypter.encrypt(value, iv: _iv).base64;
  }

  /// To Decrypt String
  String decript(String value) {
    return _encrypter.decrypt64(value, iv: _iv);
  }
}

Uint8List _decodeHexString(String input) {
  assert(input.length % 2 == 0, 'Input needs to be an even length.');

  return Uint8List.fromList(
    List.generate(
      input.length ~/ 2,
      (i) => int.parse(input.substring(i * 2, (i * 2) + 2), radix: 16),
    ).toList(),
  );
}

abstract class _Algorithm {
  /// Encrypt [bytes].
  _Encrypted encrypt(Uint8List bytes, {IV? iv});

  /// Decrypt [encrypted] value.
  Uint8List decrypt(_Encrypted encrypted, {IV? iv});
}

class _Salsa20 implements _Algorithm {
  final Key key;

  final Salsa20Engine _cipher = Salsa20Engine();

  _Salsa20(this.key);

  @override
  _Encrypted encrypt(Uint8List bytes, {IV? iv}) {
    if (iv == null) {
      throw StateError('IV is required.');
    }

    _cipher
      ..reset()
      ..init(true, _buildParams(iv));

    return _Encrypted(_cipher.process(bytes));
  }

  @override
  Uint8List decrypt(_Encrypted encrypted, {IV? iv}) {
    if (iv == null) {
      throw StateError('IV is required.');
    }

    _cipher
      ..reset()
      ..init(false, _buildParams(iv));

    return _cipher.process(encrypted.bytes);
  }

  ParametersWithIV<KeyParameter> _buildParams(IV iv) {
    return ParametersWithIV<KeyParameter>(KeyParameter(key.bytes), iv.bytes);
  }
}

class _Encrypted {
  _Encrypted(this._bytes);

  final Uint8List _bytes;

  /// Creates an Encrypted object from a hexdecimal string.
  _Encrypted.fromBase16(String encoded) : _bytes = _decodeHexString(encoded);

  /// Creates an Encrypted object from a Base64 string.
  _Encrypted.fromBase64(String encoded)
      : _bytes = convert.base64.decode(encoded);

  /// Creates an Encrypted object from a Base64 string.
  // _Encrypted.from64(String encoded) : _bytes = convert.base64.decode(encoded);

  /// Creates an Encrypted object from a UTF-8 string.
  _Encrypted.fromUtf8(String input)
      : _bytes = Uint8List.fromList(convert.utf8.encode(input));

  /// Creates an Encrypted object from a length.
  _Encrypted.fromLength(int length) : _bytes = Uint8List(length);

  /// Gets the Encrypted bytes.
  Uint8List get bytes => _bytes;

  /// Gets the Encrypted bytes as a Hexdecimal representation.
  String get base16 =>
      _bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// Gets the Encrypted bytes as a Base64 representation.
  String get base64 => convert.base64.encode(_bytes);
}

/// Represents an Initialization Vector.
class IV extends _Encrypted {
  IV(Uint8List bytes) : super(bytes);
  IV.fromBase16(String encoded) : super.fromBase16(encoded);
  IV.fromBase64(String encoded) : super.fromBase64(encoded);
  IV.fromUtf8(String input) : super.fromUtf8(input);
  IV.fromLength(int length) : super.fromLength(length);
  IV.fromSecureRandom(int length) : super(_SecureRandom(length).bytes);
}

/// Represents an Encryption Key.
class Key extends _Encrypted {
  Key(Uint8List bytes) : super(bytes);
  Key.fromBase16(String encoded) : super.fromBase16(encoded);
  Key.fromBase64(String encoded) : super.fromBase64(encoded);
  Key.fromUtf8(String input) : super.fromUtf8(input);
  Key.fromLength(int length) : super.fromLength(length);
  Key.fromSecureRandom(int length) : super(_SecureRandom(length).bytes);

  Key stretch(int desiredKeyLength,
      {int iterationCount = 100, Uint8List? salt}) {
    salt ??= _SecureRandom(desiredKeyLength).bytes;

    final params = Pbkdf2Parameters(salt, iterationCount, desiredKeyLength);
    final pbkdf2 = PBKDF2KeyDerivator(Mac('SHA-1/HMAC'))..init(params);

    return Key(pbkdf2.process(_bytes));
  }

  int get length => bytes.lengthInBytes;
}

class _Encrypter {
  final _Algorithm algo;

  _Encrypter(this.algo);

  /// Calls [encrypt] on the wrapped _Algorithm using a raw binary.
  _Encrypted encryptBytes(List<int> input, {IV? iv}) {
    if (input is Uint8List) {
      return algo.encrypt(input, iv: iv);
    }

    return algo.encrypt(Uint8List.fromList(input), iv: iv);
  }

  /// Calls [encrypt] on the wrapped _Algorithm.
  _Encrypted encrypt(String input, {IV? iv}) {
    return encryptBytes(convert.utf8.encode(input), iv: iv);
  }

  /// Calls [decrypt] on the wrapped Algorith without UTF-8 decoding.
  List<int> decryptBytes(_Encrypted encrypted, {IV? iv}) {
    return algo.decrypt(encrypted, iv: iv).toList();
  }

  /// Calls [decrypt] on the wrapped _Algorithm.
  String decrypt(_Encrypted encrypted, {IV? iv}) {
    return convert.utf8
        .decode(decryptBytes(encrypted, iv: iv), allowMalformed: true);
  }

  /// Sugar for `decrypt(Encrypted.fromBase16(encoded))`.
  String decrypt16(String encoded, {IV? iv}) {
    return decrypt(_Encrypted.fromBase16(encoded), iv: iv);
  }

  /// Sugar for `decrypt(Encrypted.fromBase64(encoded))`.
  String decrypt64(String encoded, {IV? iv}) {
    return decrypt(_Encrypted.fromBase64(encoded), iv: iv);
  }
}

class _SecureRandom {
  static final Random _generator = Random.secure();
  final Uint8List _bytes;

  _SecureRandom(int length)
      : _bytes = Uint8List.fromList(
            List.generate(length, (i) => _generator.nextInt(256)));

  Uint8List get bytes => _bytes;

  String get base16 =>
      _bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  String get base64 => convert.base64.encode(_bytes);

  String get utf8 => convert.utf8.decode(_bytes);

  int get length => _bytes.length;
}

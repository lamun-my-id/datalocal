import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:datalocal/src/encryption/datalocal_key_provider.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DataLocalSecureStorageClient {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class DataLocalFlutterSecureStorageClient
    implements DataLocalSecureStorageClient {
  DataLocalFlutterSecureStorageClient([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists AES keys outside SharedPreferences using platform secure storage.
final class DataLocalSecureStorageKeyProvider implements DataLocalKeyProvider {
  DataLocalSecureStorageKeyProvider({
    required String databaseName,
    DataLocalSecureStorageClient? client,
    Random? random,
  }) : _namespace = 'datalocal.v2.keys.${_token(databaseName)}',
       _client = client ?? DataLocalFlutterSecureStorageClient(),
       _random = random ?? Random.secure();

  static const int keyByteLength = 32;
  static const int keyIdByteLength = 12;

  final String _namespace;
  final DataLocalSecureStorageClient _client;
  final Random _random;
  Future<void> _tail = Future<void>.value();

  @override
  Future<DataLocalKeyMaterial> activeKey() =>
      _serialized<DataLocalKeyMaterial>(() async {
        final index = await _readOrCreateIndex();
        return _requireKey(index.activeKeyId);
      });

  @override
  Future<DataLocalKeyMaterial?> keyById(String id) =>
      _serialized<DataLocalKeyMaterial?>(() => _readKey(id));

  @override
  Future<DataLocalKeyMaterial> rotate() =>
      _serialized<DataLocalKeyMaterial>(() async {
        final index = await _readOrCreateIndex();
        DataLocalKeyMaterial key;
        do {
          key = _newKey();
        } while (index.keyIds.contains(key.id));
        await _writeKey(key);
        await _writeIndex(
          _KeyIndex(
            activeKeyId: key.id,
            keyIds: <String>[...index.keyIds, key.id],
          ),
        );
        return DataLocalKeyMaterial(id: key.id, bytes: key.bytes);
      });

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<_KeyIndex> _readOrCreateIndex() async {
    final raw = await _client.read('$_namespace.index');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (map['format'] != 'datalocal-key-index/1') {
          throw const FormatException('unsupported key index');
        }
        return _KeyIndex(
          activeKeyId: map['activeKeyId'] as String,
          keyIds: (map['keyIds'] as List<dynamic>).cast<String>(),
        );
      } catch (error, stackTrace) {
        throw DataLocalEncryptionException(
          'Secure key index is invalid.',
          context: const <String, Object?>{'component': 'keyIndex'},
          cause: error,
          causeStackTrace: stackTrace,
        );
      }
    }
    final initial = _newKey();
    await _writeKey(initial);
    await _writeIndex(
      _KeyIndex(activeKeyId: initial.id, keyIds: <String>[initial.id]),
    );
    return _KeyIndex(activeKeyId: initial.id, keyIds: <String>[initial.id]);
  }

  Future<DataLocalKeyMaterial> _requireKey(String id) async {
    final key = await _readKey(id);
    if (key == null) {
      throw DataLocalEncryptionException(
        'Secure key material is missing.',
        context: <String, Object?>{'keyId': id},
      );
    }
    return key;
  }

  Future<DataLocalKeyMaterial?> _readKey(String id) async {
    final raw = await _client.read('$_namespace.key.$id');
    if (raw == null) {
      return null;
    }
    try {
      final bytes = base64Url.decode(raw);
      if (bytes.length != keyByteLength) {
        throw const FormatException('invalid key length');
      }
      return DataLocalKeyMaterial(id: id, bytes: bytes);
    } catch (error, stackTrace) {
      throw DataLocalEncryptionException(
        'Secure key material is invalid.',
        context: <String, Object?>{'keyId': id},
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  Future<void> _writeKey(DataLocalKeyMaterial key) =>
      _client.write('$_namespace.key.${key.id}', base64UrlEncode(key.bytes));

  Future<void> _writeIndex(_KeyIndex index) => _client.write(
    '$_namespace.index',
    jsonEncode(<String, Object?>{
      'format': 'datalocal-key-index/1',
      'activeKeyId': index.activeKeyId,
      'keyIds': index.keyIds,
    }),
  );

  DataLocalKeyMaterial _newKey() => DataLocalKeyMaterial(
    id: base64UrlEncode(
      List<int>.generate(keyIdByteLength, (_) => _random.nextInt(256)),
    ).replaceAll('=', ''),
    bytes: Uint8List.fromList(
      List<int>.generate(keyByteLength, (_) => _random.nextInt(256)),
    ),
  );

  static String _token(String value) {
    if (value.trim().isEmpty) {
      throw const DataLocalValidationException(
        'Database name must not be empty.',
        context: <String, Object?>{'field': 'databaseName'},
      );
    }
    return base64UrlEncode(utf8.encode(value)).replaceAll('=', '');
  }
}

final class _KeyIndex {
  const _KeyIndex({required this.activeKeyId, required this.keyIds});

  final String activeKeyId;
  final List<String> keyIds;
}

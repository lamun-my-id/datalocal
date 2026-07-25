import 'dart:math';
import 'dart:typed_data';

import 'package:datalocal/src/encryption/datalocal_key_provider.dart';

/// In-memory key provider for tests and ephemeral databases.
///
/// It is not a replacement for Android Keystore or Apple Keychain.
final class DataLocalMemoryKeyProvider implements DataLocalKeyProvider {
  DataLocalMemoryKeyProvider({DataLocalKeyMaterial? initialKey, Random? random})
    : _random = random ?? Random.secure() {
    final key = initialKey ?? _newKey(1);
    _keys[key.id] = key;
    _activeKeyId = key.id;
  }

  static const int keyByteLength = 32;

  final Random _random;
  final Map<String, DataLocalKeyMaterial> _keys =
      <String, DataLocalKeyMaterial>{};
  late String _activeKeyId;
  int _sequence = 1;

  @override
  Future<DataLocalKeyMaterial> activeKey() async => _copy(_keys[_activeKeyId]!);

  @override
  Future<DataLocalKeyMaterial?> keyById(String id) async {
    final key = _keys[id];
    return key == null ? null : _copy(key);
  }

  @override
  Future<DataLocalKeyMaterial> rotate() async {
    DataLocalKeyMaterial key;
    do {
      key = _newKey(++_sequence);
    } while (_keys.containsKey(key.id));
    _keys[key.id] = key;
    _activeKeyId = key.id;
    return _copy(key);
  }

  DataLocalKeyMaterial _newKey(int sequence) => DataLocalKeyMaterial(
    id: 'memory-key-$sequence',
    bytes: Uint8List.fromList(
      List<int>.generate(keyByteLength, (_) => _random.nextInt(256)),
    ),
  );

  DataLocalKeyMaterial _copy(DataLocalKeyMaterial key) =>
      DataLocalKeyMaterial(id: key.id, bytes: key.bytes);
}

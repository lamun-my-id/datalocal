import 'package:datalocal/datalocal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persists active and historical keys across provider instances',
    () async {
      final client = _MemorySecureStorageClient();
      var provider = DataLocalSecureStorageKeyProvider(
        databaseName: 'secure-db',
        client: client,
      );
      final initial = await provider.activeKey();
      final rotated = await provider.rotate();

      provider = DataLocalSecureStorageKeyProvider(
        databaseName: 'secure-db',
        client: client,
      );
      expect((await provider.activeKey()).id, rotated.id);
      expect((await provider.keyById(initial.id))?.bytes, initial.bytes);
      expect(
        client.values.values.any((value) => value.contains('secure-db')),
        isFalse,
      );
    },
  );

  test('serializes concurrent first access into one initial key', () async {
    final client = _MemorySecureStorageClient();
    final provider = DataLocalSecureStorageKeyProvider(
      databaseName: 'concurrent',
      client: client,
    );

    final keys = await Future.wait(
      List<Future<DataLocalKeyMaterial>>.generate(
        20,
        (_) => provider.activeKey(),
      ),
    );

    expect(keys.map((key) => key.id).toSet(), hasLength(1));
    expect(
      client.values.keys.where((key) => key.contains('.key.')),
      hasLength(1),
    );
  });

  test('reports missing historical key material explicitly', () async {
    final client = _MemorySecureStorageClient();
    final provider = DataLocalSecureStorageKeyProvider(
      databaseName: 'missing',
      client: client,
    );
    final key = await provider.activeKey();
    client.values.removeWhere((name, _) => name.endsWith('.key.${key.id}'));

    await expectLater(
      provider.activeKey(),
      throwsA(isA<DataLocalEncryptionException>()),
    );
    expect(await provider.keyById(key.id), isNull);
  });
}

final class _MemorySecureStorageClient implements DataLocalSecureStorageClient {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

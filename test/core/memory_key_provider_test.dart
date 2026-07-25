import 'dart:typed_data';

import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  test('returns defensive copies of active and historical keys', () async {
    final original = Uint8List.fromList(List<int>.filled(32, 7));
    final provider = DataLocalMemoryKeyProvider(
      initialKey: DataLocalKeyMaterial(id: 'key-1', bytes: original),
    );
    original[0] = 99;

    final active = await provider.activeKey();
    expect(active.id, 'key-1');
    expect(active.bytes, everyElement(7));

    final exposed = active.bytes;
    exposed[0] = 88;
    expect((await provider.activeKey()).bytes, everyElement(7));
  });

  test('rotates without losing historical key lookup', () async {
    final provider = DataLocalMemoryKeyProvider(
      initialKey: DataLocalKeyMaterial(
        id: 'key-1',
        bytes: Uint8List.fromList(List<int>.filled(32, 7)),
      ),
    );

    final rotated = await provider.rotate();

    expect(rotated.id, isNot('key-1'));
    expect(rotated.bytes, hasLength(32));
    expect((await provider.activeKey()).id, rotated.id);
    expect(await provider.keyById('key-1'), isNotNull);
    expect(await provider.keyById('missing'), isNull);
  });

  test('rotation never replaces a colliding initial key ID', () async {
    final provider = DataLocalMemoryKeyProvider(
      initialKey: DataLocalKeyMaterial(
        id: 'memory-key-2',
        bytes: Uint8List.fromList(List<int>.filled(32, 7)),
      ),
    );

    final rotated = await provider.rotate();

    expect(rotated.id, 'memory-key-3');
    expect((await provider.keyById('memory-key-2'))!.bytes, everyElement(7));
  });
}

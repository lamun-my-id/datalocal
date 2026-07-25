import 'dart:typed_data';

import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

import '../contracts/storage_contract.dart';

void main() {
  storageContract('memory', DataLocalMemoryStorage.new);

  test(
    'memory storage retains records when the same instance reopens',
    () async {
      final storage = DataLocalMemoryStorage();
      final context = DataLocalStorageContext(databaseName: 'db');
      await storage.open(context);
      await storage.write(
        DataLocalStoredRecord(
          collection: 'notes',
          id: 'note-1',
          revision: 1,
          formatVersion: 2,
          payload: Uint8List.fromList(<int>[1]),
        ),
      );
      await storage.close();

      await storage.open(context);

      expect(await storage.read('notes', 'note-1'), isNotNull);
      await storage.close();
    },
  );
}

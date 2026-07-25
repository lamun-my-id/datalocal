import 'dart:typed_data';

import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

typedef StorageFactory = DataLocalStorage Function();

void storageContract(String name, StorageFactory createStorage) {
  group('$name storage contract', () {
    late DataLocalStorage storage;

    setUp(() async {
      storage = createStorage();
      await storage.open(DataLocalStorageContext(databaseName: 'contract-db'));
    });

    tearDown(() async {
      await storage.close();
    });

    test('is open after open and closed after close', () async {
      expect(storage.isOpen, isTrue);
      await storage.close();
      expect(storage.isOpen, isFalse);
      await storage.close();
    });

    test('returns null for a missing record', () async {
      expect(await storage.read('notes', 'missing'), isNull);
    });

    test('writes and reads defensive record copies', () async {
      final source = Uint8List.fromList(<int>[1, 2, 3]);
      final record = DataLocalStoredRecord(
        collection: 'notes',
        id: 'note-1',
        revision: 1,
        formatVersion: 2,
        payload: source,
      );

      await storage.write(record);
      source[0] = 99;

      final firstRead = await storage.read('notes', 'note-1');
      expect(firstRead, isNotNull);
      expect(firstRead!.payload, <int>[1, 2, 3]);

      final exposed = firstRead.payload;
      exposed[0] = 88;
      expect((await storage.read('notes', 'note-1'))!.payload, <int>[1, 2, 3]);
    });

    test('overwrites a record with a newer representation', () async {
      await storage.write(_record('note-1', revision: 1, payload: 1));
      await storage.write(_record('note-1', revision: 2, payload: 2));

      final result = await storage.read('notes', 'note-1');
      expect(result!.revision, 2);
      expect(result.payload, <int>[2]);
    });

    test('lists a collection in deterministic ID order', () async {
      await storage.write(_record('note-c'));
      await storage.write(_record('note-a'));
      await storage.write(_record('note-b'));
      await storage.write(
        DataLocalStoredRecord(
          collection: 'other',
          id: 'other-a',
          revision: 1,
          formatVersion: 2,
          payload: Uint8List(0),
        ),
      );

      final result = await storage.readCollection('notes');
      expect(result.map((record) => record.id), <String>[
        'note-a',
        'note-b',
        'note-c',
      ]);
    });

    test('deletes existing records and reports missing records', () async {
      await storage.write(_record('note-1'));

      expect(await storage.delete('notes', 'note-1'), isTrue);
      expect(await storage.delete('notes', 'note-1'), isFalse);
      expect(await storage.read('notes', 'note-1'), isNull);
    });

    test('clears only the selected collection', () async {
      await storage.write(_record('note-1'));
      await storage.write(
        DataLocalStoredRecord(
          collection: 'other',
          id: 'other-1',
          revision: 1,
          formatVersion: 2,
          payload: Uint8List(0),
        ),
      );

      await storage.clearCollection('notes');

      expect(await storage.readCollection('notes'), isEmpty);
      expect(await storage.read('other', 'other-1'), isNotNull);
    });

    test('rejects operations while closed', () async {
      await storage.close();

      expect(
        () => storage.read('notes', 'note-1'),
        throwsA(isA<DataLocalClosedException>()),
      );
      expect(
        () => storage.write(_record('note-1')),
        throwsA(isA<DataLocalClosedException>()),
      );
    });

    test('persists defensive journal copies and clears them', () async {
      final source = Uint8List.fromList(<int>[1, 2, 3]);
      await storage.writeJournal(source);
      source[0] = 99;

      final first = await storage.readJournal();
      expect(first, <int>[1, 2, 3]);
      first![1] = 99;
      expect(await storage.readJournal(), <int>[1, 2, 3]);

      await storage.clearJournal();
      expect(await storage.readJournal(), isNull);
    });
  });
}

DataLocalStoredRecord _record(String id, {int revision = 1, int payload = 0}) =>
    DataLocalStoredRecord(
      collection: 'notes',
      id: id,
      revision: revision,
      formatVersion: 2,
      payload: Uint8List.fromList(<int>[payload]),
    );

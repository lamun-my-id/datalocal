import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  test('serializes concurrent mutations without losing revisions', () async {
    final database = await DataLocalDatabase.open(
      name: 'concurrency',
      storage: DataLocalMemoryStorage(
        operationDelay: const Duration(milliseconds: 1),
      ),
    );
    final collection = database.mapCollection('counters');
    await collection.insert(<String, Object?>{'value': 0}, id: 'counter');

    await Future.wait(
      List<Future<void>>.generate(20, (index) async {
        await collection.patch('counter', <String, Object?>{
          'value': index + 1,
        });
      }),
    );

    final result = await collection.require('counter');
    expect(result.revision, 21);
    expect(result.data['value'], 20);
    await database.close();
  });

  test('commits multiple documents as one logical batch', () async {
    final database = await DataLocalDatabase.open(
      name: 'batch',
      storage: DataLocalMemoryStorage(),
    );
    final notes = database.mapCollection('notes');
    await notes.insert(<String, Object?>{'value': 1}, id: 'existing');

    await database.writeBatch((batch) {
      batch.insert(notes, <String, Object?>{'value': 2}, id: 'new');
      batch.replace(notes, 'existing', <String, Object?>{
        'value': 3,
      }, expectedRevision: 1);
    });

    expect((await notes.require('new')).data['value'], 2);
    expect((await notes.require('existing')).data['value'], 3);
    await database.close();
  });

  for (final phase in DataLocalCommitPhase.values) {
    test('recovers deterministically after ${phase.name}', () async {
      final storage = DataLocalMemoryStorage();
      var injected = false;
      var database = await DataLocalDatabase.open(
        name: 'recovery-${phase.name}',
        storage: storage,
        failureInjector: (current) {
          if (!injected && current == phase) {
            injected = true;
            throw _InjectedFailure();
          }
        },
      );
      var notes = database.mapCollection('notes');

      await expectLater(
        notes.insert(<String, Object?>{'value': phase.name}, id: 'note'),
        throwsA(isA<_InjectedFailure>()),
      );
      await database.close();

      database = await DataLocalDatabase.open(
        name: 'recovery-${phase.name}',
        storage: storage,
      );
      notes = database.mapCollection('notes');
      final recovered = await notes.get('note');

      if (phase == DataLocalCommitPhase.journalPrepared ||
          phase == DataLocalCommitPhase.mutationsApplied) {
        expect(recovered, isNull);
      } else {
        expect(recovered?.data['value'], phase.name);
      }
      expect(await storage.readJournal(), isNull);
      await database.close();
    });
  }

  test('rolls back every member of an interrupted batch', () async {
    final storage = DataLocalMemoryStorage();
    var database = await DataLocalDatabase.open(
      name: 'batch-recovery',
      storage: storage,
      failureInjector: (phase) {
        if (phase == DataLocalCommitPhase.mutationsApplied) {
          throw _InjectedFailure();
        }
      },
    );
    var notes = database.mapCollection('notes');

    await expectLater(
      database.writeBatch((batch) {
        batch.insert(notes, <String, Object?>{'value': 1}, id: 'one');
        batch.insert(notes, <String, Object?>{'value': 2}, id: 'two');
      }),
      throwsA(isA<_InjectedFailure>()),
    );
    await database.close();

    database = await DataLocalDatabase.open(
      name: 'batch-recovery',
      storage: storage,
    );
    notes = database.mapCollection('notes');
    expect(await notes.get('one'), isNull);
    expect(await notes.get('two'), isNull);
    await database.close();
  });
}

final class _InjectedFailure implements Exception {}

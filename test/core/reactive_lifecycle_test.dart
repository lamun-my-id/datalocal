import 'dart:async';

import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'multiple listeners receive initial and commit-ordered snapshots',
    () async {
      final database = await DataLocalDatabase.open(
        name: 'watch',
        storage: DataLocalMemoryStorage(),
      );
      final notes = database.mapCollection('notes');
      final first = <List<String>>[];
      final second = <List<String>>[];
      final firstReady = Completer<void>();
      final secondReady = Completer<void>();

      final firstSubscription = notes.query().orderBy('value').watch().listen((
        snapshot,
      ) {
        first.add(snapshot.documents.map((item) => item.id).toList());
        if (first.length == 1) firstReady.complete();
      });
      final secondSubscription = notes.query().orderBy('value').watch().listen((
        snapshot,
      ) {
        second.add(snapshot.documents.map((item) => item.id).toList());
        if (second.length == 1) secondReady.complete();
      });
      await Future.wait(<Future<void>>[firstReady.future, secondReady.future]);

      await notes.insert(<String, Object?>{'value': 2}, id: 'b');
      await notes.insert(<String, Object?>{'value': 1}, id: 'a');
      await _waitFor(() => first.length == 3 && second.length == 3);

      expect(first, <List<String>>[
        <String>[],
        <String>['b'],
        <String>['a', 'b'],
      ]);
      expect(second, first);
      await firstSubscription.cancel();
      await secondSubscription.cancel();
      await database.close();
    },
  );

  test('batch emits one event group and one query snapshot', () async {
    final database = await DataLocalDatabase.open(
      name: 'batch-watch',
      storage: DataLocalMemoryStorage(),
    );
    final notes = database.mapCollection('notes');
    final events = <DataLocalCommitEvent>[];
    final snapshots = <DataLocalQuerySnapshot<Map<String, Object?>>>[];
    final eventSubscription = notes.changes.listen(events.add);
    final watchSubscription = notes.query().watch().listen(snapshots.add);
    await _waitFor(() => snapshots.isNotEmpty);

    await database.writeBatch((batch) {
      batch.insert(notes, <String, Object?>{'value': 1}, id: 'one');
      batch.insert(notes, <String, Object?>{'value': 2}, id: 'two');
    });
    await _waitFor(() => snapshots.length == 2);

    expect(events, hasLength(1));
    expect(events.single.changes, hasLength(2));
    expect(events.single.sequence, 1);
    expect(
      snapshots.singleWhere((item) => item.documents.length == 2),
      isNotNull,
    );
    await eventSubscription.cancel();
    await watchSubscription.cancel();
    await database.close();
  });

  test('failed commits emit neither change events nor snapshots', () async {
    final database = await DataLocalDatabase.open(
      name: 'failed-watch',
      storage: DataLocalMemoryStorage(),
      failureInjector: (phase) {
        if (phase == DataLocalCommitPhase.journalPrepared) {
          throw _InjectedFailure();
        }
      },
    );
    final notes = database.mapCollection('notes');
    final events = <DataLocalCommitEvent>[];
    final snapshots = <DataLocalQuerySnapshot<Map<String, Object?>>>[];
    final eventSubscription = notes.changes.listen(events.add);
    final watchSubscription = notes.query().watch().listen(snapshots.add);
    await _waitFor(() => snapshots.isNotEmpty);

    await expectLater(
      notes.insert(<String, Object?>{'value': 1}, id: 'failed'),
      throwsA(isA<_InjectedFailure>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(events, isEmpty);
    expect(snapshots, hasLength(1));
    await eventSubscription.cancel();
    await watchSubscription.cancel();
    await database.close();
  });

  test(
    'close drains accepted writes, rejects new work, and closes streams',
    () async {
      final storage = DataLocalMemoryStorage(
        operationDelay: const Duration(milliseconds: 2),
      );
      var database = await DataLocalDatabase.open(
        name: 'close',
        storage: storage,
      );
      var notes = database.mapCollection('notes');
      final streamDone = Completer<void>();
      final subscription = database.changes.listen(
        (_) {},
        onDone: streamDone.complete,
      );

      final accepted = notes.insert(<String, Object?>{
        'value': 1,
      }, id: 'accepted');
      final closing = database.close();
      expect(
        () => notes.insert(<String, Object?>{'value': 2}, id: 'rejected'),
        throwsA(isA<DataLocalClosedException>()),
      );
      await Future.wait<Object?>(<Future<Object?>>[accepted, closing]);
      await streamDone.future;
      await subscription.cancel();

      database = await DataLocalDatabase.open(name: 'close', storage: storage);
      notes = database.mapCollection('notes');
      expect(await notes.get('accepted'), isNotNull);
      expect(await notes.get('rejected'), isNull);
      await database.close();
    },
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  throw TimeoutException('Condition was not reached.');
}

final class _InjectedFailure implements Exception {}

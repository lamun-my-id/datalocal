import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  late DataLocalMemoryStorage storage;
  late _MutableClock clock;
  late DataLocalDatabase database;
  late DataLocalCollection<Map<String, Object?>> notes;

  setUp(() async {
    storage = DataLocalMemoryStorage();
    clock = _MutableClock(DateTime.utc(2026, 7, 25, 10));
    database = await DataLocalDatabase.open(
      name: 'crud-test',
      storage: storage,
      clock: clock,
      idGenerator: _SequenceIdGenerator(),
    );
    notes = database.mapCollection('notes');
  });

  tearDown(() => database.close());

  test('inserts, reads, replaces, patches, and deletes a document', () async {
    final inserted = await notes.insert(<String, Object?>{
      'title': 'first',
      'done': false,
    });
    expect(inserted.id, 'generated-1');
    expect(inserted.revision, 1);

    clock.value = DateTime.utc(2026, 7, 25, 11);
    final replaced = await notes.replace(inserted.id, <String, Object?>{
      'title': 'second',
      'done': false,
    }, expectedRevision: 1);
    expect(replaced.revision, 2);
    expect(replaced.createdAt, inserted.createdAt);
    expect(replaced.updatedAt, clock.value);

    final patched = await notes.patch(inserted.id, <String, Object?>{
      'done': true,
    }, expectedRevision: 2);
    expect(patched.revision, 3);
    expect(patched.data, <String, Object?>{'title': 'second', 'done': true});

    expect(await notes.delete(inserted.id, expectedRevision: 3), isTrue);
    expect(await notes.get(inserted.id), isNull);
    expect(await notes.delete(inserted.id), isFalse);
  });

  test('persists records when a database is reopened', () async {
    await notes.insert(<String, Object?>{'title': 'survives'}, id: 'note-1');
    await database.close();

    database = await DataLocalDatabase.open(
      name: 'crud-test',
      storage: storage,
      clock: clock,
    );
    notes = database.mapCollection('notes');

    final restored = await notes.require('note-1');
    expect(restored.data['title'], 'survives');
    expect(restored.revision, 1);
  });

  test('rejects duplicate IDs and stale revisions', () async {
    await notes.insert(<String, Object?>{'value': 1}, id: 'same');

    expect(
      () => notes.insert(<String, Object?>{'value': 2}, id: 'same'),
      throwsA(isA<DataLocalConflictException>()),
    );
    expect(
      () => notes.replace('same', <String, Object?>{
        'value': 2,
      }, expectedRevision: 99),
      throwsA(isA<DataLocalConflictException>()),
    );
  });

  test('supports typed collections through codecs', () async {
    final users = database.collection<_User>(
      'users',
      codec: DataLocalFunctionalCodec<_User>(
        encode: (user) => <String, Object?>{'name': user.name, 'age': user.age},
        decode: (data) => _User(data['name']! as String, data['age']! as int),
      ),
    );

    await users.insert(const _User('Risa', 30), id: 'risa');
    expect(await users.require('risa'), isA<DataLocalDocument<_User>>());
    expect((await users.require('risa')).data, const _User('Risa', 30));
  });

  test(
    'fails predictably after close and validates collection names',
    () async {
      expect(
        () => database.mapCollection(' '),
        throwsA(isA<DataLocalValidationException>()),
      );
      await database.close();
      expect(
        () => notes.get('anything'),
        throwsA(isA<DataLocalClosedException>()),
      );
    },
  );
}

final class _MutableClock implements DataLocalClock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _SequenceIdGenerator implements DataLocalDocumentIdGenerator {
  var _next = 0;

  @override
  String generate() => 'generated-${++_next}';
}

final class _User {
  const _User(this.name, this.age);

  final String name;
  final int age;

  @override
  bool operator ==(Object other) =>
      other is _User && other.name == name && other.age == age;

  @override
  int get hashCode => Object.hash(name, age);
}

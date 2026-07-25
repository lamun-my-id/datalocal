import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  test('creates metadata independently from user data', () {
    final document = DataLocalDocument<Map<String, Object?>>.create(
      id: 'note-1',
      data: <String, Object?>{'createdAt': 'a user field', 'revision': 9000},
      codec: const DataLocalMapCodec(),
      clock: _FixedClock(DateTime.utc(2026, 7, 25, 10)),
    );

    expect(document.id, 'note-1');
    expect(document.createdAt, DateTime.utc(2026, 7, 25, 10));
    expect(document.updatedAt, document.createdAt);
    expect(document.revision, 1);
    expect(document.data['createdAt'], 'a user field');
    expect(document.data['revision'], 9000);
  });

  test('normalizes metadata time to UTC and advances revisions', () {
    final created = DateTime.parse('2026-07-25T17:00:00+07:00');
    final metadata = DataLocalMetadata(
      id: 'note-1',
      createdAt: created,
      updatedAt: created,
      revision: 1,
    );

    final updated = metadata.nextRevision(
      DateTime.parse('2026-07-25T18:00:00+07:00'),
    );

    expect(metadata.createdAt.isUtc, isTrue);
    expect(updated.updatedAt, DateTime.utc(2026, 7, 25, 11));
    expect(updated.revision, 2);
    expect(updated.createdAt, metadata.createdAt);
  });

  test('does not move updatedAt backwards', () {
    final metadata = DataLocalMetadata(
      id: 'note-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      revision: 2,
    );

    final updated = metadata.nextRevision(DateTime.utc(2025));

    expect(updated.updatedAt, metadata.updatedAt);
    expect(updated.revision, 3);
  });

  test('validates IDs and revisions', () {
    expect(
      () => DataLocalMetadata(
        id: '',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        revision: 1,
      ),
      throwsA(isA<DataLocalValidationException>()),
    );
    expect(
      () => DataLocalMetadata(
        id: 'valid',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        revision: 0,
      ),
      throwsA(isA<DataLocalValidationException>()),
    );
  });

  test('secure ID generator produces opaque unique IDs', () {
    final generator = DataLocalSecureDocumentIdGenerator();
    final ids = List<String>.generate(100, (_) => generator.generate()).toSet();

    expect(ids, hasLength(100));
    expect(ids.every((id) => id.length == 24), isTrue);
    expect(ids.every((id) => !id.contains('=')), isTrue);
  });
}

final class _FixedClock implements DataLocalClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

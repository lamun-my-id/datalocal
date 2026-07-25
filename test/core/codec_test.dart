import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  const codec = DataLocalFunctionalCodec<_Note>(
    encode: _encodeNote,
    decode: _decodeNote,
  );

  test('typed codec round trips application values', () {
    const note = _Note(title: 'DataLocal', completed: false);

    final encoded = codec.encode(note);
    final decoded = codec.decode(encoded);

    expect(decoded, note);
    expect(
      () => encoded['title'] = 'Changed',
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('codec wraps application errors without leaking document values', () {
    const failingCodec = DataLocalFunctionalCodec<_Note>(
      encode: _encodeNote,
      decode: _failingDecode,
    );

    expect(
      () => failingCodec.decode(<String, Object?>{'secret': 'plaintext'}),
      throwsA(
        isA<DataLocalSerializationException>()
            .having(
              (error) => error.message,
              'message',
              isNot(contains('plaintext')),
            )
            .having((error) => error.cause, 'cause', isA<StateError>()),
      ),
    );
  });
}

Map<String, Object?> _encodeNote(_Note note) => <String, Object?>{
  'title': note.title,
  'completed': note.completed,
};

_Note _decodeNote(Map<String, Object?> data) => _Note(
  title: data['title']! as String,
  completed: data['completed']! as bool,
);

_Note _failingDecode(Map<String, Object?> data) {
  throw StateError('Application decoder rejected its input.');
}

final class _Note {
  const _Note({required this.title, required this.completed});

  final String title;
  final bool completed;

  @override
  bool operator ==(Object other) =>
      other is _Note && other.title == title && other.completed == completed;

  @override
  int get hashCode => Object.hash(title, completed);
}

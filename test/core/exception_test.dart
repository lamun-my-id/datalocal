import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  test('exception exposes a stable code and safe string', () {
    final exception = DataLocalWriteException(
      'Unable to persist the record.',
      context: const <String, Object?>{
        'collection': 'notes',
        'documentId': 'note-1',
      },
      cause: StateError('disk unavailable'),
    );

    expect(exception.code, DataLocalErrorCode.write);
    expect(exception.toString(), contains('DataLocalWriteException(write)'));
    expect(exception.toString(), isNot(contains('disk unavailable')));
  });
}

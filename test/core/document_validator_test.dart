import 'package:datalocal/datalocal_core.dart';
import 'package:test/test.dart';

void main() {
  const validator = DataLocalDocumentValidator();

  test('creates an immutable deep copy', () {
    final nested = <String, Object?>{'name': 'Void'};
    final tags = <Object?>['flutter', 'storage'];
    final source = <String, Object?>{'author': nested, 'tags': tags};

    final frozen = validator.validateAndFreeze(source);
    nested['name'] = 'Changed';
    tags.add('later');

    expect(frozen['author'], <String, Object?>{'name': 'Void'});
    expect(frozen['tags'], <Object?>['flutter', 'storage']);
    expect(() => frozen['new'] = true, throwsA(isA<UnsupportedError>()));
    expect(
      () => (frozen['tags']! as List<Object?>).add('nope'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('rejects unsupported values with a safe path', () {
    expect(
      () => validator.validateAndFreeze(<String, Object?>{
        'profile': <String, Object?>{'birthday': DateTime.utc(2020)},
      }),
      throwsA(
        isA<DataLocalValidationException>().having(
          (error) => error.context['path'],
          'path',
          r'$.profile.birthday',
        ),
      ),
    );
  });

  test('rejects non-finite numbers', () {
    expect(
      () => validator.validateAndFreeze(<String, Object?>{'score': double.nan}),
      throwsA(isA<DataLocalValidationException>()),
    );
  });

  test('rejects cyclic documents', () {
    final cyclic = <String, Object?>{};
    cyclic['self'] = cyclic;

    expect(
      () => validator.validateAndFreeze(cyclic),
      throwsA(
        isA<DataLocalValidationException>().having(
          (error) => error.message,
          'message',
          contains('cyclic'),
        ),
      ),
    );
  });

  test('rejects documents deeper than the configured maximum', () {
    const shallowValidator = DataLocalDocumentValidator(maximumDepth: 2);

    expect(
      () => shallowValidator.validateAndFreeze(<String, Object?>{
        'one': <String, Object?>{'two': <String, Object?>{}},
      }),
      throwsA(isA<DataLocalValidationException>()),
    );
  });
}

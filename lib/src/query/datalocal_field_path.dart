import 'package:datalocal/src/exceptions/datalocal_exception.dart';

final class DataLocalFieldPath {
  DataLocalFieldPath(List<String> segments)
    : segments = List<String>.unmodifiable(_validate(segments));

  factory DataLocalFieldPath.parse(String path) =>
      DataLocalFieldPath(path.split('.'));

  final List<String> segments;

  Object? read(Map<String, Object?> document) {
    Object? current = document;
    for (final segment in segments) {
      if (current is! Map<String, Object?> || !current.containsKey(segment)) {
        return DataLocalMissingField.instance;
      }
      current = current[segment];
    }
    return current;
  }

  static List<String> _validate(List<String> value) {
    if (value.isEmpty || value.any((segment) => segment.isEmpty)) {
      throw const DataLocalValidationException(
        'Field path must contain non-empty segments.',
        context: <String, Object?>{'field': 'fieldPath'},
      );
    }
    return value;
  }

  @override
  String toString() => segments.join('.');
}

final class DataLocalMissingField {
  const DataLocalMissingField._();

  static const DataLocalMissingField instance = DataLocalMissingField._();
}

import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// A validated dot-separated path into a document map.
final class DataLocalFieldPath {
  /// Creates a path from validated [segments].
  DataLocalFieldPath(List<String> segments)
    : segments = List<String>.unmodifiable(_validate(segments));

  /// Parses a dot-separated field [path].
  factory DataLocalFieldPath.parse(String path) =>
      DataLocalFieldPath(path.split('.'));

  /// Immutable path components in traversal order.
  final List<String> segments;

  /// Reads this path from [document].
  ///
  /// Returns [DataLocalMissingField.instance] when a segment is absent.
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

/// Sentinel distinguishing a missing field from a field containing `null`.
final class DataLocalMissingField {
  const DataLocalMissingField._();

  /// Shared missing-field sentinel.
  static const DataLocalMissingField instance = DataLocalMissingField._();
}

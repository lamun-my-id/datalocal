import 'dart:collection';

import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Validates and freezes values accepted by the default map codec.
final class DataLocalDocumentValidator {
  const DataLocalDocumentValidator({
    this.maximumDepth = 32,
    this.maximumCollectionLength = 100000,
  });

  final int maximumDepth;
  final int maximumCollectionLength;

  Map<String, Object?> validateAndFreeze(Map<String, Object?> data) {
    if (maximumDepth < 1) {
      throw const DataLocalValidationException(
        'maximumDepth must be at least one.',
        context: <String, Object?>{'field': 'maximumDepth'},
      );
    }
    final activeContainers = HashSet<Object>.identity();
    return _freezeMap(
      data,
      path: r'$',
      depth: 0,
      activeContainers: activeContainers,
    );
  }

  Map<String, Object?> _freezeMap(
    Map<Object?, Object?> value, {
    required String path,
    required int depth,
    required Set<Object> activeContainers,
  }) {
    _validateContainer(value, path, depth, activeContainers);
    final result = <String, Object?>{};
    try {
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw DataLocalValidationException(
            'Document map keys must be strings.',
            context: <String, Object?>{'path': path},
          );
        }
        result[key] = _freezeValue(
          entry.value,
          path: _childPath(path, key),
          depth: depth + 1,
          activeContainers: activeContainers,
        );
      }
    } finally {
      activeContainers.remove(value);
    }
    return UnmodifiableMapView<String, Object?>(result);
  }

  List<Object?> _freezeList(
    List<Object?> value, {
    required String path,
    required int depth,
    required Set<Object> activeContainers,
  }) {
    _validateContainer(value, path, depth, activeContainers);
    final result = <Object?>[];
    try {
      for (var index = 0; index < value.length; index++) {
        result.add(
          _freezeValue(
            value[index],
            path: '$path[$index]',
            depth: depth + 1,
            activeContainers: activeContainers,
          ),
        );
      }
    } finally {
      activeContainers.remove(value);
    }
    return UnmodifiableListView<Object?>(result);
  }

  Object? _freezeValue(
    Object? value, {
    required String path,
    required int depth,
    required Set<Object> activeContainers,
  }) {
    if (value == null || value is bool || value is int || value is String) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw DataLocalValidationException(
          'Document numbers must be finite.',
          context: <String, Object?>{'path': path},
        );
      }
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return _freezeMap(
        value,
        path: path,
        depth: depth,
        activeContainers: activeContainers,
      );
    }
    if (value is List<Object?>) {
      return _freezeList(
        value,
        path: path,
        depth: depth,
        activeContainers: activeContainers,
      );
    }
    throw DataLocalValidationException(
      'Unsupported document value type.',
      context: <String, Object?>{
        'path': path,
        'type': value.runtimeType.toString(),
      },
    );
  }

  void _validateContainer(
    Object value,
    String path,
    int depth,
    Set<Object> activeContainers,
  ) {
    if (depth >= maximumDepth) {
      throw DataLocalValidationException(
        'Document exceeds the maximum nesting depth.',
        context: <String, Object?>{'path': path, 'maximumDepth': maximumDepth},
      );
    }
    final length = switch (value) {
      Map<Object?, Object?> map => map.length,
      List<Object?> list => list.length,
      _ => 0,
    };
    if (length > maximumCollectionLength) {
      throw DataLocalValidationException(
        'Document collection exceeds the maximum length.',
        context: <String, Object?>{
          'path': path,
          'length': length,
          'maximumLength': maximumCollectionLength,
        },
      );
    }
    if (!activeContainers.add(value)) {
      throw DataLocalValidationException(
        'Document contains a cyclic reference.',
        context: <String, Object?>{'path': path},
      );
    }
  }

  String _childPath(String parent, String key) {
    final simpleKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key);
    return simpleKey ? '$parent.$key' : '$parent[${_quote(key)}]';
  }

  String _quote(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

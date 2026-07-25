import 'dart:typed_data';

import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Secret key bytes and their non-secret stable identifier.
final class DataLocalKeyMaterial {
  DataLocalKeyMaterial({required String id, required Uint8List bytes})
    : id = _validateId(id),
      _bytes = Uint8List.fromList(bytes) {
    if (_bytes.isEmpty) {
      throw const DataLocalValidationException(
        'Key material must not be empty.',
        context: <String, Object?>{'field': 'bytes'},
      );
    }
  }

  final String id;
  final Uint8List _bytes;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  static String _validateId(String value) {
    if (value.trim().isEmpty) {
      throw const DataLocalValidationException(
        'Key ID must not be empty.',
        context: <String, Object?>{'field': 'id'},
      );
    }
    return value;
  }
}

/// Supplies active and historical keys without coupling encryption to an OS.
abstract interface class DataLocalKeyProvider {
  Future<DataLocalKeyMaterial> activeKey();

  Future<DataLocalKeyMaterial?> keyById(String id);

  Future<DataLocalKeyMaterial> rotate();
}

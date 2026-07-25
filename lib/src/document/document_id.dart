import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Generates and validates opaque document identifiers.
abstract interface class DataLocalDocumentIdGenerator {
  String generate();
}

final class DataLocalSecureDocumentIdGenerator
    implements DataLocalDocumentIdGenerator {
  DataLocalSecureDocumentIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  static const int randomByteLength = 18;
  static const int maximumEncodedLength = 256;

  final Random _random;

  @override
  String generate() {
    final bytes = Uint8List.fromList(
      List<int>.generate(randomByteLength, (_) => _random.nextInt(256)),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String validate(String id) {
    if (id.isEmpty) {
      throw const DataLocalValidationException(
        'Document ID must not be empty.',
        context: <String, Object?>{'field': 'id'},
      );
    }
    if (id.length > maximumEncodedLength) {
      throw DataLocalValidationException(
        'Document ID exceeds the maximum encoded length.',
        context: <String, Object?>{
          'field': 'id',
          'length': id.length,
          'maximumLength': maximumEncodedLength,
        },
      );
    }
    if (id.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      throw const DataLocalValidationException(
        'Document ID must not contain control characters.',
        context: <String, Object?>{'field': 'id'},
      );
    }
    return id;
  }
}

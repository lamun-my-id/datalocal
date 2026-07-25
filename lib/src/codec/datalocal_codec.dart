// ignore_for_file: prefer_initializing_formals

import 'package:datalocal/src/document/datalocal_document_validator.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Converts application values to and from DataLocal map documents.
abstract interface class DataLocalCodec<T> {
  Map<String, Object?> encode(T value);

  T decode(Map<String, Object?> data);
}

final class DataLocalFunctionalCodec<T> implements DataLocalCodec<T> {
  const DataLocalFunctionalCodec({
    required Map<String, Object?> Function(T value) encode,
    required T Function(Map<String, Object?> data) decode,
    DataLocalDocumentValidator validator = const DataLocalDocumentValidator(),
  }) : _encode = encode,
       _decode = decode,
       _validator = validator;

  final Map<String, Object?> Function(T value) _encode;
  final T Function(Map<String, Object?> data) _decode;
  final DataLocalDocumentValidator _validator;

  @override
  Map<String, Object?> encode(T value) {
    try {
      return _validator.validateAndFreeze(_encode(value));
    } on DataLocalException {
      rethrow;
    } catch (error, stackTrace) {
      throw DataLocalSerializationException(
        'Failed to encode a document.',
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  @override
  T decode(Map<String, Object?> data) {
    try {
      return _decode(_validator.validateAndFreeze(data));
    } on DataLocalException {
      rethrow;
    } catch (error, stackTrace) {
      throw DataLocalSerializationException(
        'Failed to decode a document.',
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }
}

final class DataLocalMapCodec implements DataLocalCodec<Map<String, Object?>> {
  const DataLocalMapCodec({
    DataLocalDocumentValidator validator = const DataLocalDocumentValidator(),
  }) : _validator = validator;

  final DataLocalDocumentValidator _validator;

  @override
  Map<String, Object?> decode(Map<String, Object?> data) =>
      _validator.validateAndFreeze(data);

  @override
  Map<String, Object?> encode(Map<String, Object?> value) =>
      _validator.validateAndFreeze(value);
}

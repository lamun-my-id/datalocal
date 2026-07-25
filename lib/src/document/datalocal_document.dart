import 'package:datalocal/src/codec/datalocal_codec.dart';
import 'package:datalocal/src/document/datalocal_clock.dart';
import 'package:datalocal/src/document/datalocal_metadata.dart';
import 'package:datalocal/src/document/document_id.dart';

/// Immutable snapshot of a committed document.
final class DataLocalDocument<T> {
  const DataLocalDocument({required this.metadata, required this.data});

  factory DataLocalDocument.create({
    required T data,
    required DataLocalCodec<T> codec,
    String? id,
    DataLocalDocumentIdGenerator? idGenerator,
    DataLocalClock clock = const DataLocalSystemClock(),
  }) {
    final encoded = codec.encode(data);
    final decoded = codec.decode(encoded);
    final time = clock.now().toUtc();
    final resolvedId =
        id ?? (idGenerator ?? DataLocalSecureDocumentIdGenerator()).generate();
    return DataLocalDocument<T>(
      metadata: DataLocalMetadata(
        id: resolvedId,
        createdAt: time,
        updatedAt: time,
        revision: 1,
      ),
      data: decoded,
    );
  }

  final DataLocalMetadata metadata;
  final T data;

  String get id => metadata.id;
  DateTime get createdAt => metadata.createdAt;
  DateTime get updatedAt => metadata.updatedAt;
  int get revision => metadata.revision;
}

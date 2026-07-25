import 'package:datalocal/src/document/document_id.dart';
import 'package:datalocal/src/exceptions/datalocal_exception.dart';

/// Immutable system metadata stored separately from user document fields.
final class DataLocalMetadata {
  DataLocalMetadata({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int revision,
  }) : id = DataLocalSecureDocumentIdGenerator.validate(id),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       revision = _validateRevision(revision) {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw const DataLocalValidationException(
        'updatedAt must not be earlier than createdAt.',
        context: <String, Object?>{'field': 'updatedAt'},
      );
    }
  }

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  DataLocalMetadata nextRevision(DateTime time) {
    final normalizedTime = time.toUtc();
    return DataLocalMetadata(
      id: id,
      createdAt: createdAt,
      updatedAt: normalizedTime.isBefore(updatedAt)
          ? updatedAt
          : normalizedTime,
      revision: revision + 1,
    );
  }

  static int _validateRevision(int revision) {
    if (revision < 1) {
      throw DataLocalValidationException(
        'Document revision must be at least one.',
        context: <String, Object?>{'field': 'revision', 'revision': revision},
      );
    }
    return revision;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataLocalMetadata &&
          id == other.id &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          revision == other.revision;

  @override
  int get hashCode => Object.hash(id, createdAt, updatedAt, revision);
}

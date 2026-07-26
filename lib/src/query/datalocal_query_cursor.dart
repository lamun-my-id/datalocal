/// A stable position that can resume an ordered [DataLocalQuery].
final class DataLocalQueryCursor {
  /// Creates a cursor from a final document and its ordering values.
  DataLocalQueryCursor({
    required this.documentId,
    required List<Object?> orderValues,
    required List<String> orderSignature,
  }) : orderValues = List<Object?>.unmodifiable(orderValues),
       orderSignature = List<String>.unmodifiable(orderSignature);

  /// Identifier used as the deterministic ordering tie-breaker.
  final String documentId;

  /// Values corresponding to the query ordering clauses.
  final List<Object?> orderValues;

  /// Ordering definition that this cursor belongs to.
  final List<String> orderSignature;
}

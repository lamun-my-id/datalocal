final class DataLocalQueryCursor {
  DataLocalQueryCursor({
    required this.documentId,
    required List<Object?> orderValues,
    required List<String> orderSignature,
  }) : orderValues = List<Object?>.unmodifiable(orderValues),
       orderSignature = List<String>.unmodifiable(orderSignature);

  final String documentId;
  final List<Object?> orderValues;
  final List<String> orderSignature;
}

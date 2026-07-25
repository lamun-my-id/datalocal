import 'dart:async';

enum DataLocalMutationType { delete, insert, update }

final class DataLocalDocumentChange {
  const DataLocalDocumentChange({
    required this.collection,
    required this.documentId,
    required this.type,
  });

  final String collection;
  final String documentId;
  final DataLocalMutationType type;
}

final class DataLocalCommitEvent {
  DataLocalCommitEvent({
    required this.sequence,
    required List<DataLocalDocumentChange> changes,
  }) : changes = List<DataLocalDocumentChange>.unmodifiable(changes);

  final int sequence;
  final List<DataLocalDocumentChange> changes;
}

final class DataLocalChangeHub {
  final StreamController<DataLocalCommitEvent> _controller =
      StreamController<DataLocalCommitEvent>.broadcast(sync: true);
  var _sequence = 0;
  var _isClosed = false;

  Stream<DataLocalCommitEvent> get events => _controller.stream;

  void emit(List<DataLocalDocumentChange> changes) {
    if (_isClosed || changes.isEmpty) {
      return;
    }
    _controller.add(
      DataLocalCommitEvent(sequence: ++_sequence, changes: changes),
    );
  }

  Stream<DataLocalCommitEvent> forCollection(String collection) => events.where(
    (event) => event.changes.any((change) => change.collection == collection),
  );

  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    await _controller.close();
  }
}

import 'package:datalocal/src/consistency/datalocal_commit_coordinator.dart';
import 'package:datalocal/src/database/datalocal_collection.dart';
import 'package:datalocal/src/reactive/datalocal_change.dart';

typedef _MutationPreparer = Future<DataLocalPreparedMutation> Function();

final class DataLocalPreparedMutation {
  const DataLocalPreparedMutation({
    required this.mutation,
    required this.change,
  });

  final DataLocalStorageMutation mutation;
  final DataLocalDocumentChange change;
}

/// Synchronous batch builder committed by [DataLocalDatabase.writeBatch].
final class DataLocalWriteBatch {
  DataLocalWriteBatch.internal();

  final List<_MutationPreparer> _preparers = <_MutationPreparer>[];
  var _sealed = false;

  void insert<T>(DataLocalCollection<T> collection, T value, {String? id}) {
    _ensureMutable();
    _preparers.add(() async {
      final mutation = await collection.prepareInsertForBatch(value, id: id);
      return DataLocalPreparedMutation(
        mutation: mutation,
        change: DataLocalDocumentChange(
          collection: mutation.collection,
          documentId: mutation.id,
          type: DataLocalMutationType.insert,
        ),
      );
    });
  }

  void replace<T>(
    DataLocalCollection<T> collection,
    String id,
    T value, {
    int? expectedRevision,
  }) {
    _ensureMutable();
    _preparers.add(() async {
      final mutation = await collection.prepareReplaceForBatch(
        id,
        value,
        expectedRevision: expectedRevision,
      );
      return DataLocalPreparedMutation(
        mutation: mutation,
        change: DataLocalDocumentChange(
          collection: mutation.collection,
          documentId: mutation.id,
          type: DataLocalMutationType.update,
        ),
      );
    });
  }

  void delete<T>(
    DataLocalCollection<T> collection,
    String id, {
    int? expectedRevision,
  }) {
    _ensureMutable();
    _preparers.add(() async {
      final mutation = await collection.prepareDeleteForBatch(
        id,
        expectedRevision: expectedRevision,
      );
      return DataLocalPreparedMutation(
        mutation: mutation,
        change: DataLocalDocumentChange(
          collection: mutation.collection,
          documentId: mutation.id,
          type: DataLocalMutationType.delete,
        ),
      );
    });
  }

  Future<List<DataLocalPreparedMutation>> sealAndPrepare() async {
    _sealed = true;
    final mutations = <DataLocalPreparedMutation>[];
    for (final prepare in _preparers) {
      mutations.add(await prepare());
    }
    return mutations;
  }

  void _ensureMutable() {
    if (_sealed) {
      throw StateError('A DataLocalWriteBatch cannot be reused.');
    }
  }
}

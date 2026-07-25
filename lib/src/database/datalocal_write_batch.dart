import 'package:datalocal/src/consistency/datalocal_commit_coordinator.dart';
import 'package:datalocal/src/database/datalocal_collection.dart';

typedef _MutationPreparer = Future<DataLocalStorageMutation> Function();

/// Synchronous batch builder committed by [DataLocalDatabase.writeBatch].
final class DataLocalWriteBatch {
  DataLocalWriteBatch.internal();

  final List<_MutationPreparer> _preparers = <_MutationPreparer>[];
  var _sealed = false;

  void insert<T>(DataLocalCollection<T> collection, T value, {String? id}) {
    _ensureMutable();
    _preparers.add(() => collection.prepareInsertForBatch(value, id: id));
  }

  void replace<T>(
    DataLocalCollection<T> collection,
    String id,
    T value, {
    int? expectedRevision,
  }) {
    _ensureMutable();
    _preparers.add(
      () => collection.prepareReplaceForBatch(
        id,
        value,
        expectedRevision: expectedRevision,
      ),
    );
  }

  void delete<T>(
    DataLocalCollection<T> collection,
    String id, {
    int? expectedRevision,
  }) {
    _ensureMutable();
    _preparers.add(
      () => collection.prepareDeleteForBatch(
        id,
        expectedRevision: expectedRevision,
      ),
    );
  }

  Future<List<DataLocalStorageMutation>> sealAndPrepare() async {
    _sealed = true;
    final mutations = <DataLocalStorageMutation>[];
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

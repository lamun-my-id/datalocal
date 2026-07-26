// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:datalocal/src/exceptions/datalocal_exception.dart';
import 'package:datalocal/src/storage/datalocal_storage.dart';

enum DataLocalCommitPhase {
  journalPrepared,
  mutationsApplied,
  journalCommitted,
  journalCleared,
}

typedef DataLocalFailureInjector =
    FutureOr<void> Function(DataLocalCommitPhase phase);

final class DataLocalStorageMutation {
  const DataLocalStorageMutation.write(this.after) : delete = null;

  const DataLocalStorageMutation.delete({
    required String collection,
    required String id,
  }) : after = null,
       delete = (collection: collection, id: id);

  final DataLocalStoredRecord? after;
  final ({String collection, String id})? delete;

  String get collection => after?.collection ?? delete!.collection;
  String get id => after?.id ?? delete!.id;
}

/// Serializes logical commits and maintains a recoverable before/after journal.
final class DataLocalCommitCoordinator {
  DataLocalCommitCoordinator({
    required DataLocalStorage storage,
    DataLocalFailureInjector? failureInjector,
  }) : _storage = storage,
       _failureInjector = failureInjector;

  final DataLocalStorage _storage;
  final DataLocalFailureInjector? _failureInjector;
  Future<void> _tail = Future<void>.value();
  var _transactionSequence = 0;

  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> drain() => synchronized<void>(() async {});

  Future<void> commit(List<DataLocalStorageMutation> mutations) async {
    if (mutations.isEmpty) {
      return;
    }
    final identities = <String>{};
    final entries = <_JournalEntry>[];
    for (final mutation in mutations) {
      final identity = '${mutation.collection}\u0000${mutation.id}';
      if (!identities.add(identity)) {
        throw DataLocalConflictException(
          'A batch mutates the same document more than once.',
          context: <String, Object?>{
            'collection': mutation.collection,
            'documentId': mutation.id,
          },
        );
      }
      entries.add(
        _JournalEntry(
          before: await _storage.read(mutation.collection, mutation.id),
          after: mutation.after,
          collection: mutation.collection,
          id: mutation.id,
        ),
      );
    }

    final transactionId =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-${++_transactionSequence}';
    await _storage.writeJournal(
      _encodeJournal(transactionId, 'prepared', entries),
    );
    await _inject(DataLocalCommitPhase.journalPrepared);

    await _apply(entries, useAfter: true);
    await _inject(DataLocalCommitPhase.mutationsApplied);

    await _storage.writeJournal(
      _encodeJournal(transactionId, 'committed', entries),
    );
    await _inject(DataLocalCommitPhase.journalCommitted);

    await _storage.clearJournal();
    await _inject(DataLocalCommitPhase.journalCleared);
  }

  Future<void> recover() async {
    final payload = await _storage.readJournal();
    if (payload == null) {
      return;
    }
    try {
      final journal = _decodeJournal(payload);
      await _apply(journal.entries, useAfter: journal.state == 'committed');
      await _storage.clearJournal();
    } on DataLocalException {
      rethrow;
    } catch (error, stackTrace) {
      throw DataLocalCorruptionException(
        'Recovery journal could not be decoded.',
        context: const <String, Object?>{'component': 'journal'},
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  Future<void> _apply(
    List<_JournalEntry> entries, {
    required bool useAfter,
  }) async {
    if (_storage case final DataLocalAtomicBatchStorage atomicStorage) {
      await atomicStorage.applyBatch(<DataLocalStorageBatchOperation>[
        for (final entry in entries)
          if ((useAfter ? entry.after : entry.before)
              case final DataLocalStoredRecord record)
            DataLocalStorageBatchOperation.write(record)
          else
            DataLocalStorageBatchOperation.delete(
              collection: entry.collection,
              id: entry.id,
            ),
      ]);
      return;
    }
    for (final entry in entries) {
      final record = useAfter ? entry.after : entry.before;
      if (record == null) {
        await _storage.delete(entry.collection, entry.id);
      } else {
        await _storage.write(record);
      }
    }
  }

  Future<void> _inject(DataLocalCommitPhase phase) async {
    await _failureInjector?.call(phase);
  }

  Uint8List _encodeJournal(
    String transactionId,
    String state,
    List<_JournalEntry> entries,
  ) => Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'format': 'datalocal-journal/1',
        'transactionId': transactionId,
        'state': state,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      }),
    ),
  );

  _Journal _decodeJournal(Uint8List payload) {
    final map = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    if (map['format'] != 'datalocal-journal/1' ||
        (map['state'] != 'prepared' && map['state'] != 'committed')) {
      throw const DataLocalCorruptionException(
        'Recovery journal has an unsupported format or state.',
      );
    }
    return _Journal(
      state: map['state'] as String,
      entries: (map['entries'] as List<dynamic>)
          .map((entry) => _JournalEntry.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

final class _Journal {
  const _Journal({required this.state, required this.entries});

  final String state;
  final List<_JournalEntry> entries;
}

final class _JournalEntry {
  const _JournalEntry({
    required this.collection,
    required this.id,
    required this.before,
    required this.after,
  });

  final String collection;
  final String id;
  final DataLocalStoredRecord? before;
  final DataLocalStoredRecord? after;

  Map<String, Object?> toJson() => <String, Object?>{
    'collection': collection,
    'id': id,
    'before': _recordToJson(before),
    'after': _recordToJson(after),
  };

  factory _JournalEntry.fromJson(Map<String, dynamic> map) => _JournalEntry(
    collection: map['collection'] as String,
    id: map['id'] as String,
    before: _recordFromJson(map['before']),
    after: _recordFromJson(map['after']),
  );

  static Map<String, Object?>? _recordToJson(DataLocalStoredRecord? record) =>
      record == null
      ? null
      : <String, Object?>{
          'collection': record.collection,
          'id': record.id,
          'revision': record.revision,
          'formatVersion': record.formatVersion,
          'payload': base64UrlEncode(record.payload),
        };

  static DataLocalStoredRecord? _recordFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    final map = value as Map<String, dynamic>;
    return DataLocalStoredRecord(
      collection: map['collection'] as String,
      id: map['id'] as String,
      revision: map['revision'] as int,
      formatVersion: map['formatVersion'] as int,
      payload: base64Url.decode(map['payload'] as String),
    );
  }
}

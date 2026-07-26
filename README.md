# DataLocal

DataLocal 2 is document-style local persistence for Flutter applications that
need more structure than direct preference calls without the weight of a SQL
schema.

It provides:

- map and typed documents with IDs, timestamps, and optimistic revisions
- immutable filters, nested field paths, sorting, cursors, and aggregates
- reactive query snapshots and commit-ordered change events
- serialized writes, logical batches, and crash-recovery journaling
- a `SharedPreferencesAsync` adapter for small datasets
- optional AES-256-GCM encryption with platform secure-key storage
- resumable migration from DataLocal 1.x

DataLocal is not a replacement for SQLite when you need large datasets,
indexes, joins, cross-process transactions, or query pushdown.

## Install

```yaml
dependencies:
  datalocal: ^2.0.0
```

## Open an encrypted database

```dart
import 'package:datalocal/datalocal.dart';

const databaseName = 'my_app';

final keys = DataLocalSecureStorageKeyProvider(
  databaseName: databaseName,
);

final database = await DataLocalDatabase.open(
  name: databaseName,
  storage: DataLocalSharedPreferencesAsyncStorage(),
  encryption: DataLocalAesGcmEncryptionProvider(
    keyProvider: keys,
  ),
);
```

`DataLocalDatabase.open` defaults to explicit plaintext mode for caches and
tests. Pass the AES-GCM provider above when confidentiality at rest is required.

On Apple platforms, configure Keychain Sharing as required by
`flutter_secure_storage`. On web, secure storage requires HTTPS or localhost.

## CRUD

```dart
final notes = database.mapCollection('notes');

final inserted = await notes.insert({
  'title': 'DataLocal 2',
  'completed': false,
  'author': {'id': 'user-1'},
});

final updated = await notes.patch(
  inserted.id,
  {'completed': true},
  expectedRevision: inserted.revision,
);

final sameNote = await notes.require(updated.id);
await notes.delete(sameNote.id, expectedRevision: sameNote.revision);
```

`get(id)` returns `null` for a missing document. `require(id)` throws
`DataLocalNotFoundException`.

## Query and watch

```dart
final query = notes
    .query()
    .where('completed', isEqualTo: false)
    .where('author.id', isEqualTo: 'user-1')
    .orderBy('title')
    .limit(20);

final snapshot = await query.get();

final subscription = query.watch().listen((snapshot) {
  print('${snapshot.documents.length} matching notes');
});
```

Queries execute in memory for the SharedPreferences adapter. Cursor ordering is
stable and uses the document ID as a deterministic tie-breaker.

## Batch

```dart
await database.writeBatch((batch) {
  batch.insert(notes, {'title': 'first'}, id: 'first');
  batch.insert(notes, {'title': 'second'}, id: 'second');
});
```

The SharedPreferences adapter provides one logical, recoverable commit inside a
database instance. It does not claim cross-process ACID transactions.

## Typed documents

```dart
final users = database.collection<User>(
  'users',
  codec: DataLocalFunctionalCodec<User>(
    encode: (user) => user.toJson(),
    decode: User.fromJson,
  ),
);
```

## Migration from 1.x

Migration is explicit, resumable, and preserves legacy values until cleanup:

```dart
final migrator = DataLocalLegacyV1Migrator();
final report = await migrator.migrate(
  databaseName: databaseName,
  stateName: 'notes',
  preferences: DataLocalSharedPreferencesAsyncClient(),
  target: database.mapCollection('notes'),
);

if (report.complete) {
  await migrator.cleanupLegacy(
    databaseName: databaseName,
    stateName: 'notes',
    preferences: DataLocalSharedPreferencesAsyncClient(),
  );
}
```

Read [the migration guide](doc/migration-v2.md) before upgrading an existing
application.

## Security boundary

AES-GCM protects stored document contents and authenticates database,
collection, document ID, and schema context. It does not protect plaintext while
your process is running, and it cannot defeat an attacker who fully controls the
device or application runtime.

See [security and limitations](doc/security-v2.md) and the
[E2E matrix](doc/e2e-v2.md).

Always close databases and cancel subscriptions you no longer need:

```dart
await subscription.cancel();
await database.close();
```

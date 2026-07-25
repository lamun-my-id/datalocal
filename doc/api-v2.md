# DataLocal 2.0 API

Status: prerelease API for `2.0.0-dev.1`.

## Database

```dart
final database = await DataLocalDatabase.open(
  name: 'my_app',
  storage: DataLocalSharedPreferencesAsyncStorage(),
  encryption: DataLocalAesGcmEncryptionProvider(
    keyProvider: DataLocalSecureStorageKeyProvider(databaseName: 'my_app'),
  ),
);
```

Opening performs journal recovery before manifest integrity verification.
`close()` drains accepted writes, closes storage and streams, and is idempotent.
Operations submitted after close begins throw `DataLocalClosedException`.

Memory and custom storage adapters implement `DataLocalStorage`.

## Collections

```dart
final maps = database.mapCollection('notes');
final typed = database.collection<Note>(
  'notes',
  codec: DataLocalFunctionalCodec<Note>(
    encode: (note) => note.toJson(),
    decode: Note.fromJson,
  ),
);
```

Mutation methods:

- `insert(value, id: optional)`
- `replace(id, value, expectedRevision: optional)`
- `patch(id, map, expectedRevision: optional)`
- `delete(id, expectedRevision: optional)`
- `clear()`
- `importDocument(document)` for verified migration tools

Read methods:

- `get(id)` returns `null` when absent
- `require(id)` throws when absent
- `query()` creates an immutable query

Documents contain immutable user data plus `id`, `createdAt`, `updatedAt`, and
`revision`.

## Batch

```dart
await database.writeBatch((batch) {
  batch.insert(notes, {'title': 'one'}, id: 'one');
  batch.replace(notes, 'existing', {'title': 'updated'});
  batch.delete(notes, 'obsolete');
});
```

A batch produces one logical journal commit and one event group. Mutating the
same document twice in a batch is rejected.

## Query

```dart
final query = notes
    .query()
    .where('author.id', isEqualTo: 'user-1')
    .where('priority', isGreaterThanOrEqualTo: 5)
    .orderBy('priority', descending: true)
    .limit(20);
```

Supported operators:

- equal and not equal, including equality with `null`
- greater/less than and inclusive variants
- `whereIn`
- array contains

Queries support nested dot paths, explicit `DataLocalFieldPath`, stable sorting,
`startAfter` cursors, `count`, `sum`, and `average`.

`get()` returns `DataLocalQuerySnapshot<T>`. `totalCount` is the filtered count
before cursor/limit; `documents` is the selected page.

## Reactive API

```dart
final subscription = query.watch().listen((snapshot) {});
final changes = notes.changes.listen((commit) {});
```

`watch()` emits an initial snapshot, then one recomputed snapshot per relevant
commit. Batch changes share one monotonically sequenced
`DataLocalCommitEvent`. Failed commits emit nothing.

## Encryption

Plaintext mode is explicit:

```dart
encryption: const DataLocalNoEncryptionProvider()
```

Authenticated encryption:

```dart
final keys = DataLocalSecureStorageKeyProvider(databaseName: 'my_app');
final encryption = DataLocalAesGcmEncryptionProvider(keyProvider: keys);
await keys.rotate();
```

New records use the active key. Historical keys remain available for old
records. Missing keys and authentication failures throw
`DataLocalEncryptionException`.

## Migration

`DataLocalLegacyV1Migrator.migrate` copies and verifies 1.x records into a map
collection. `cleanupLegacy` is a separate explicit operation allowed only after
complete progress.

## Errors

Expected failures derive from `DataLocalException` and expose a stable
`DataLocalErrorCode`. Messages and context do not include document plaintext or
key bytes.

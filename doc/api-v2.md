# DataLocal 2.0 API

Status: stable API for `2.0.0`.

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
    .where('tags', arrayContainsAny: ['flutter', 'dart'])
    .orderBy(
      'priority',
      descending: true,
      nullOrder: DataLocalNullOrder.last,
    )
    .limit(20);
```

Supported operators:

- equal and not equal, including equality with `null`
- greater/less than and inclusive variants
- `whereIn` and `whereNotIn`
- `arrayContains` and `arrayContainsAny`
- explicit `isNull: true` and `isNotNull: true`

Chained filters use logical AND. Add an OR group with `whereAny`; the group is
then combined with the other predicates using AND:

```dart
final visible = notes.query().whereAny([
  DataLocalFilter(
    path: DataLocalFieldPath.parse('ownerId'),
    operator: DataLocalFilterOperator.equal,
    value: currentUserId,
  ),
  DataLocalFilter(
    path: DataLocalFieldPath.parse('public'),
    operator: DataLocalFilterOperator.equal,
    value: true,
  ),
]);
```

Missing fields do not match filters, including `isNull`, `isNotNull`, and
`whereNotIn`. This distinguishes an absent value from an explicitly stored
`null`.

Queries support nested dot paths, explicit `DataLocalFieldPath`, stable
multi-field sorting, automatic or explicit null placement, and inclusive or
exclusive cursor boundaries through `startAt`, `startAfter`, `endAt`, and
`endBefore`. `limit` selects the first page and `limitToLast` selects the final
page. Aggregates include `count`, `sum`, and `average`.

Cursor signatures include every ordering field, direction, and null-placement
rule. Reusing a cursor with incompatible ordering throws
`DataLocalValidationException`.

`get()` returns `DataLocalQuerySnapshot<T>`. `totalCount` is the filtered count
before cursor/limit; `documents` is the selected page.

Filtering and sorting currently scan and evaluate the collection in memory.
They do not provide Firestore composite indexes or PostgreSQL query planning;
use an indexed storage adapter when collection size makes linear scans
inappropriate.

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

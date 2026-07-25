# DataLocal 2.0 Public API Draft

Status: Draft. Names may change until `2.0.0-beta.1`.

## Open and close

```dart
final database = await DataLocalDatabase.open(
  name: 'my_app',
  storage: SharedPreferencesStorage(),
  encryption: DataLocalEncryption.deviceBound(),
  migrations: const [
    DataLocalV1Migration(),
  ],
);

await database.close();
```

`open` completes only after recovery and required migrations complete.
Operations after `close` throw `DataLocalClosedException`.

## Map collections

```dart
final notes = database.collection('notes');

final inserted = await notes.insert({
  'title': 'DataLocal 2.0',
  'completed': false,
  'priority': 10,
});
```

The returned value is an immutable document snapshot containing the generated
ID, metadata, and user data.

```dart
final note = await notes.get(inserted.id);

await notes.update(inserted.id, {
  'completed': true,
});

await notes.delete(inserted.id);
```

Missing-document behavior is explicit:

- `get(id)` returns `null`.
- `require(id)` throws `DataLocalNotFoundException`.
- `update(id, data)` throws unless an upsert option is supplied.
- `delete(id)` reports whether a document was removed.

## Typed collections

```dart
final notes = database.collection<Note>(
  'notes',
  codec: DataLocalCodec(
    encode: (note) => note.toJson(),
    decode: (map) => Note.fromJson(map),
  ),
);
```

The codec is responsible only for user data. Document ID and timestamps remain
DataLocal metadata.

## Updates

Patch semantics replace only the named fields:

```dart
await notes.patch(id, {
  'completed': true,
});
```

Replace semantics replace all user data:

```dart
await notes.replace(id, {
  'title': 'Replacement',
  'completed': false,
});
```

Functional typed updates use optimistic revision checks:

```dart
await notes.modify(
  id,
  (current) => current.copyWith(completed: true),
);
```

## Batch and transaction

```dart
await database.writeBatch((batch) {
  batch.insert(notes, first);
  batch.update(notes, secondId, secondPatch);
  batch.delete(notes, thirdId);
});
```

For adapters with native transactions:

```dart
await database.transaction((transaction) async {
  final current = await transaction.require(notes, id);
  await transaction.replace(
    notes,
    id,
    current.data,
    expectedRevision: current.revision,
  );
});
```

The SharedPreferences adapter guarantees serialized logical commits and journal
recovery, not cross-process ACID transactions.

## Query

```dart
final query = notes
    .query()
    .where('completed', isEqualTo: false)
    .where('priority', isGreaterThan: 5)
    .orderBy('createdAt', descending: true)
    .limit(20);

final snapshot = await query.get();
```

Nested paths use dot notation:

```dart
notes.query().where('author.id', isEqualTo: 'user-1');
```

Literal keys containing dots require an explicit field path:

```dart
notes.query().whereField(
  const DataLocalFieldPath(['author.name.with.dot']),
  isEqualTo: 'value',
);
```

## Pagination

```dart
final firstPage = await notes
    .query()
    .orderBy('createdAt')
    .limit(20)
    .get();

final secondPage = await notes
    .query()
    .orderBy('createdAt')
    .startAfter(firstPage.cursor!)
    .limit(20)
    .get();
```

Cursors encode query ordering and document identity. They are versioned and
must not expose encrypted document contents.

## Aggregate

```dart
final count = await notes.query().count();
final total = await notes.query().sum('priority');
final average = await notes.query().average('priority');
```

Numeric operations reject non-numeric values according to a documented strict
or skip policy. The default is strict.

## Watch

```dart
final subscription = notes
    .query()
    .where('completed', isEqualTo: false)
    .watch()
    .listen((snapshot) {
      render(snapshot.documents);
    });
```

A change stream is also available for repository integrations:

```dart
notes.changes.listen((change) {
  switch (change) {
    case DataLocalInserted():
    case DataLocalUpdated():
    case DataLocalDeleted():
  }
});
```

## Encryption configuration

No encryption:

```dart
encryption: DataLocalEncryption.none()
```

Device-bound encryption:

```dart
encryption: DataLocalEncryption.deviceBound()
```

Advanced applications may supply providers:

```dart
encryption: DataLocalEncryption.custom(
  cipher: cipherProvider,
  keys: keyProvider,
)
```

## Maintenance

```dart
final report = await database.verify();
await database.repair(report, policy: DataLocalRepairPolicy.safe);
await database.rotateEncryptionKey();
await database.cleanupLegacyData();
```

Repair never silently deletes undecodable data. Destructive policies require an
explicit option.

## Diagnostics

```dart
database.diagnostics.listen((event) {
  logger.info(event);
});
```

Diagnostics contain identifiers and categories, but never encryption keys or
document plaintext by default.


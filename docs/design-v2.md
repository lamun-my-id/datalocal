# DataLocal 2.0 Design

Status: Draft  
Target: `datalocal 2.0.0`

## Product definition

DataLocal is a lightweight, reactive document store for Flutter. Documents use
`Map<String, Object?>` as their canonical public representation. Applications
may add typed codecs without changing the storage model.

DataLocal 2.0 is not presented as a replacement for every local database. The
built-in SharedPreferences adapter targets small datasets such as caches,
drafts, structured preferences, and application state that can be recovered or
reconstructed.

Larger datasets, indexed queries, and durable transactional workloads belong in
optional storage adapters such as `datalocal_sqlite`.

## Goals

- Keep the map/document API simple.
- Separate the public API, query engine, storage, serialization, and encryption.
- Complete every mutation only after persistence succeeds.
- Detect corruption instead of silently returning empty data.
- Support multiple listeners through streams.
- Provide optional authenticated encryption.
- Preserve DataLocal 1.x data through an idempotent migration.
- Allow future SQLite and Firestore packages without redesigning the core API.
- Make behavior testable without Flutter plugins through in-memory adapters.

## Non-goals for 2.0.0

- Relational joins.
- Full-text search.
- Multi-process consistency.
- Large blob or file storage.
- Blind indexes.
- Firestore synchronization.
- SQLite implementation in the core package.
- A custom durable storage engine.

## Architecture

```text
Application
    |
Public collection and query API
    |
Document validation and typed codec
    |
Query and transaction engine
    |
Serialization
    |
Encryption provider
    |
Storage adapter
```

No layer may reach around the layer below it. In particular:

- Documents do not import SharedPreferences.
- The query model does not depend on a storage implementation.
- Encryption does not own application models.
- Storage adapters receive encoded records, not mutable application objects.
- Events are emitted by the transaction engine after a successful commit.

## Proposed source layout

```text
lib/
|-- datalocal.dart
`-- src/
    |-- database/
    |-- document/
    |-- query/
    |-- codec/
    |-- storage/
    |-- encryption/
    |-- migration/
    |-- events/
    `-- exceptions/
```

Only `lib/datalocal.dart` is a supported public entrypoint. Internal files may
change in minor releases.

## Document model

System metadata is separate from user data. Reserved keys such as `#createdAt`
are not injected into the user's map.

```dart
final class DataLocalDocument {
  const DataLocalDocument({
    required this.id,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
  });

  final String id;
  final Map<String, Object?> data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
}
```

JSON-compatible values are supported by the default codec:

- `null`
- `bool`
- `int`
- `double`
- `String`
- lists of supported values
- maps with string keys and supported values

Additional Dart types require an explicit codec. The core must never guess how
to serialize an unsupported object.

## Identifiers and time

- Generated document IDs use a cryptographically secure random source.
- IDs are opaque and stable.
- IDs must be non-empty and have a documented maximum encoded length.
- Timestamps are stored as UTC microseconds since Unix epoch.
- `createdAt` is immutable.
- `updatedAt` changes only when a mutation commits.
- `revision` starts at one and increments for every committed update.

## Mutation semantics

A mutation follows this order:

```text
validate
encode
encrypt
prepare journal
write record and metadata
commit journal
emit event
complete Future
```

If any step before commit fails:

- The returned future completes with a typed exception.
- No success event is emitted.
- Recovery restores the last committed state.

All mutations in a database instance pass through a serialized write queue.
Batch operations have one logical commit and one ordered event group.

## Query semantics

The query API is immutable. Every method returns a new query value.

The initial stable operators are:

- equality and inequality
- greater/less than comparisons
- `whereIn`
- array contains
- nested map paths
- stable ascending and descending sort
- offset-free cursor pagination where possible
- limit
- count, sum, and average for numeric values

All sorts use the document ID as a final deterministic tie-breaker.

Storage adapters may execute a query themselves when
`supportsQueryPushdown` is true. Otherwise the core query engine evaluates the
same query over decoded documents.

## Reactive semantics

`watch()` emits snapshots, not mutable internal collections.

- More than one listener is supported.
- The first event contains the current committed result.
- Later events follow commit order.
- Failed mutations produce no data-change event.
- Cancelling the last listener releases query resources.
- Closing the database closes all streams with a defined terminal behavior.

## Storage boundary

Storage adapters declare capabilities:

```dart
abstract interface class DataLocalStorageCapabilities {
  bool get supportsAtomicBatch;
  bool get supportsIndexes;
  bool get supportsQueryPushdown;
  bool get supportsTransactions;
}
```

The core must not pretend an unsupported capability exists. It may emulate a
logical transaction with a journal, but it must document the durability level.

The first implementations are:

- memory storage for tests and ephemeral data
- SharedPreferencesAsync storage for small persisted datasets

## Encryption boundary

Encryption is optional and uses authenticated encryption. The initial
implementation is AES-256-GCM with a new random nonce for every encryption.

Keys are provided by a separate key provider. Production keys are never
hardcoded in Dart source.

Encryption protects data at rest. It does not promise secrecy when an attacker
controls the application process, device runtime, or user session.

See [data-format-v2.md](data-format-v2.md) for the envelope format.

## Error model

All expected failures use a `DataLocalException` subtype:

- initialization
- validation
- read
- write
- serialization
- encryption
- corruption
- migration
- not found
- conflict
- unsupported capability
- closed database

Exceptions retain the cause and stack trace when available. Sensitive plaintext,
keys, and full document contents must not appear in exception messages or logs.

## Migration

Version 1.x data is read using an isolated legacy decoder. New code must not
reuse the legacy cipher for new writes.

Migration is:

- explicit or automatically approved by a documented policy
- idempotent
- resumable
- written into a temporary v2 namespace
- verified before legacy data is removed
- observable through a migration report

The default policy preserves legacy data until the application explicitly
requests cleanup.

## Package evolution

The intended family is:

```text
datalocal
datalocal_sqlite
datalocal_for_firestore
```

All adapters share contract tests and the public collection/query model.

## Release gates

`2.0.0` stable requires:

- no analyzer findings
- unit and contract tests passing
- restart persistence E2E passing
- migration E2E passing against real 1.x fixtures
- corruption and journal recovery E2E passing
- encryption tamper tests passing
- documented benchmark results
- reviewed upgrade and threat-model documentation


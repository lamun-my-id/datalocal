# DataLocal roadmap

This roadmap describes the intended direction after `2.0.0`. It is a planning
document, not a compatibility promise. Stable APIs follow semantic versioning;
future integrations may begin as prereleases while their contracts mature.

## Product position

DataLocal is document-style local persistence for small and medium Flutter
datasets. It combines Map/JSON-shaped documents, immutable queries, reactive
snapshots, recoverable writes, and optional authenticated encryption.

DataLocal is not intended to replace an indexed relational database for large
datasets. Encryption protects data at rest from casual inspection and
unauthorized file access, but it cannot make secrets inaccessible to an
attacker who fully controls an unlocked device and application process.

## Release path

### 2.0.0-dev.2: approachable and documented

- Reduce the public API to intentional user and provider contracts.
- Add Dartdoc to every exported public API element.
- Add convenience constructors for memory, plaintext, and encrypted storage.
- Document complete examples for CRUD, queries, reactive UI, migration, and
  dependency injection.
- Publish a query compatibility matrix and explicit null/missing-field rules.
- Extend composite predicates beyond the initial `whereAny` OR groups when
  real applications require nested boolean expressions.
- Add convenience result methods such as `first` and `firstOrNull`.

### 2.0.0-rc.1: validation and API freeze

- Collect feedback from real applications.
- Run repeatable benchmarks on physical Android and iOS devices.
- Document recommended collection sizes and performance limits.
- Exercise migration, crash recovery, and key rotation across supported
  platforms.
- Freeze storage, encryption, query, and migration contracts.

### 2.0.0: stable core

- Publish only after supported CI and E2E targets are green.
- Follow semantic versioning for the stable public API.
- Maintain migration documentation for every data-format change.

## Optional integrations after core stability

Integrations should remain separate packages so that the core stays small and
remote database semantics do not leak into local persistence.

### `datalocal_http_cache`

A read-through REST/JSON cache with configurable cache keys, TTL, stale-while-
revalidate behavior, and safe per-user namespaces.

### `datalocal_supabase`

A Supabase cache and synchronization adapter. Development should begin with a
read-through cache, then add realtime reconciliation and finally an offline
mutation queue with retry, idempotency, tombstones, and explicit conflict
resolution.

### `datalocal_firestore`

A DataLocal 2.x integration for Firestore snapshots and offline materialized
views. It should replace legacy coupling with an adapter over the stable core.

### `datalocal_sqlite`

An indexed storage adapter for larger collections and query-heavy workloads.
It should preserve DataLocal document semantics while clearly documenting
which operations are executed through SQLite indexes.

## Remote synchronization principles

DataLocal should not pretend that REST, Firestore, Supabase/PostgreSQL, and
local storage share identical semantics. Remote adapters should instead map
remote records into local materialized views and preserve provenance:

- remote source and collection;
- remote record identifier and revision;
- last successful synchronization time;
- pending local mutation state;
- deletion tombstone and conflict status.

Every adapter must define logout cleanup, user isolation, retry behavior,
conflict resolution, and failure recovery before it supports offline writes.

## Success criteria

The stable release should have:

- complete Dartdoc for the exported API;
- no analyzer warnings;
- unit, contract, integration, and restart E2E coverage;
- documented performance boundaries from physical-device benchmarks;
- no known data-loss or cross-user data-isolation defects;
- an onboarding example that a Flutter developer can run in under ten minutes.

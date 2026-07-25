# DataLocal 2.0 Implementation Plan

Each task should be reviewable and leave the branch in a tested state. A task
may be split into smaller pull requests, but its acceptance criteria remain the
release gate for that milestone.

## Task 01: Design and contracts

Deliverables:

- product scope and non-goals
- public API draft
- logical record and encrypted envelope formats
- threat model and storage limitations
- testing and E2E strategy

Acceptance:

- architecture has no dependency cycle
- legacy migration is represented in the format and API
- SQLite and Firestore can be future adapters without changing collection APIs

## Task 02: Core domain

Deliverables:

- immutable document and metadata values
- identifier and clock abstractions
- map and typed codecs
- validation
- exception hierarchy

Acceptance:

- pure core unit tests pass
- unsupported values fail with typed exceptions
- metadata cannot collide with user keys

Depends on: Task 01.

## Task 03: Provider contracts

Deliverables:

- storage interfaces and capabilities
- encryption and key-provider interfaces
- memory storage and memory key provider
- reusable provider contract test harnesses

Acceptance:

- providers can be tested without Flutter plugins
- future packages implement interfaces through supported public extension APIs

Depends on: Task 02.

## Task 04: CRUD and query engine

Deliverables:

- database and collection lifecycle
- map and typed CRUD
- immutable queries
- nested field paths
- filters, stable sorting, cursors, limits, and initial aggregates

Acceptance:

- memory storage passes CRUD and query contracts
- queries are deterministic
- no mutable internal data escapes through the public API

Depends on: Tasks 02 and 03.

## Task 05: Consistency and recovery

Deliverables:

- serialized write queue
- revision conflict checks
- batch API
- logical transaction journal
- startup recovery
- failure-injection hooks for tests

Acceptance:

- concurrent mutation tests pass
- every injected interruption recovers to a documented state
- events are never emitted before commit

Depends on: Task 04.

## Task 06: SharedPreferencesAsync adapter

Deliverables:

- versioned key namespace
- database and collection manifests
- record persistence
- journal persistence
- orphan and missing-record verification

Acceptance:

- adapter passes the shared storage contract
- reopen persistence integration tests pass
- limitations are documented

Depends on: Task 05.

## Task 07: Encryption and keys

Deliverables:

- AES-256-GCM provider
- envelope encoder
- secure random nonce generation
- device-bound key provider on Android and Apple platforms
- key rotation

Acceptance:

- encryption contract tests pass
- tampering and associated-data mismatch are detected
- no hardcoded production key exists
- diagnostics contain no plaintext or key material

Depends on: Tasks 03 and 06.

## Task 08: Migration from 1.x

Deliverables:

- isolated read-only legacy decoder
- immutable legacy fixtures
- resumable migration state machine
- verification report
- explicit legacy cleanup

Acceptance:

- all supported fixtures migrate without data loss
- interrupted migration resumes safely
- new writes never use the legacy cipher

Depends on: Tasks 06 and 07.

## Task 09: Reactive behavior and lifecycle

Deliverables:

- collection change stream
- query snapshots and `watch`
- listener lifecycle
- database close behavior

Acceptance:

- multiple listeners receive commit-ordered snapshots
- failed writes emit no change
- close and cancellation release all resources

Depends on: Tasks 04 and 05.

## Task 10: End-to-end harness

Deliverables:

- real Flutter E2E application
- restart/reload checkpoint protocol
- platform storage reset and fixture installation
- required scenarios from `testing-v2.md`
- CI jobs for required platforms

Acceptance:

- persistence, recovery, encryption, migration, upgrade, and lifecycle E2E pass
- failures provide actionable artifacts and logs without leaking plaintext

Depends on: Tasks 06 through 09. E2E scenario design begins in Task 01 and test
hooks are added during the task that owns each feature.

## Task 11: Release hardening

Deliverables:

- complete documentation and examples
- reproducible benchmarks
- API review
- compatibility audit
- prerelease sequence
- migration guide

Acceptance:

- all release gates in `testing-v2.md` pass
- no analyzer findings
- public API is frozen at beta
- stable is published only after release-candidate feedback

Depends on: all previous tasks.

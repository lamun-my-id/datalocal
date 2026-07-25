# Migrating from DataLocal 1.x

DataLocal 2 is a breaking redesign. The `DataLocal`, `DataItem`, `find`, and
legacy filter/sort APIs are not exported by the v2 entrypoint.

## Before upgrading

1. Upgrade the production application to the latest 1.x release first.
2. Back up test fixtures from every platform you support.
3. Do not delete application preferences or rename the 1.x state.
4. Test the migration using an application upgrade, not only a fresh install.

## API mapping

| DataLocal 1.x | DataLocal 2 |
| --- | --- |
| `DataLocal.create('notes')` | `DataLocalDatabase.open(...)` then `mapCollection('notes')` |
| `insertOne(map)` | `collection.insert(map)` |
| `get(id)` | `collection.get(id)` or `require(id)` |
| `updateOne(id, value: patch)` | `collection.patch(id, patch)` |
| `removeOne(id)` | `collection.delete(id)` |
| `find(...)` | `collection.query()...get()` |
| `onRefresh` | `query.watch()` or `collection.changes` |

## Migration behavior

`DataLocalLegacyV1Migrator`:

- decodes the historical fixed-key Salsa20 layout read-only
- preserves document IDs and available timestamps
- writes only v2 records through the configured storage and encryption provider
- records progress after every verified document
- treats an existing identical target document as a safely resumed copy
- reports missing or undecodable legacy paths
- never deletes legacy values during `migrate`

Call `cleanupLegacy` only after `report.complete` is true and application-level
verification succeeds. Cleanup is intentionally separate and irreversible.

The 1.x decoder exists solely for migration. New writes never use the legacy
cipher.

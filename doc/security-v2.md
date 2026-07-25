# Security and limitations

## What encryption provides

`DataLocalAesGcmEncryptionProvider` uses:

- 256-bit AES keys
- GCM authenticated encryption
- a new cryptographically secure 96-bit nonce per write
- a 128-bit authentication tag
- associated data binding the database, collection, document ID, and schema

`DataLocalSecureStorageKeyProvider` stores active and historical keys through
`flutter_secure_storage`, outside DataLocal's SharedPreferences namespace.

## What encryption does not provide

DataLocal does not claim protection when an attacker:

- controls the running application process
- can instrument or debug the Flutter runtime
- has access to plaintext shown by the application
- can invoke application code under the authenticated user session
- controls an unlocked or rooted/jailbroken device

Client-side encryption raises the cost of casual offline inspection and detects
tampering. It is not a substitute for server-side authorization or hardware
attestation.

## Storage limitations

The SharedPreferences adapter is intended for small document sets and scans
collections in memory. It has:

- no indexes or query pushdown
- no joins
- no cross-process locking or ACID guarantee
- platform-dependent preference size/performance limits
- logical recovery only for commits managed by one DataLocal database instance

Use a future SQLite adapter or a dedicated database when indexed queries,
high write volume, or large collections matter.

## Platform notes

- Android secure storage requires Android 6.0/API 23 or newer.
- Apple applications must enable Keychain Sharing.
- Web secure storage requires HTTPS or localhost.
- Backup/restore behavior can separate encrypted data from device-bound keys;
  applications must handle unavailable keys as data-recovery events.

Diagnostics and exception strings omit document plaintext and key material.
Applications should preserve that property in their own logging.

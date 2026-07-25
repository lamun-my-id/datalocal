# DataLocal 2.0 E2E Harness

The Flutter application in `example/` is both a usable v2 sample and the real
plugin E2E harness.

## Scenarios

`example/integration_test/datalocal_e2e_test.dart` covers:

- encrypted CRUD and reopen persistence
- key rotation and plaintext-at-rest inspection
- concurrent writes and reactive snapshots
- interruption at every journal phase
- missing-record corruption
- migration of a real 1.x preference layout and explicit cleanup
- database close and reopen behavior

`example/integration_test/restart_checkpoint_test.dart` implements a two-process
checkpoint. The seed process writes and exits. A new verify process opens the
same platform storage and checks the document.

## Local commands

```sh
cd example
flutter test integration_test/datalocal_e2e_test.dart -d macos
cd ..
tool/run_e2e_checkpoint.sh macos false
```

The macOS ad-hoc test runner uses a memory-backed AES key because Keychain
access groups require a signed entitlement. Android and iOS CI set
`DATALOCAL_E2E_DEVICE_KEYS=true`, exercising the real platform secure-key
adapter. Production macOS applications must enable Keychain Sharing as required
by `flutter_secure_storage`.

Web integration tests use `flutter drive` and ChromeDriver because current
Flutter tooling does not support web devices through `flutter test` for
integration tests.

## CI matrix

`.github/workflows/v2-ci.yml` defines:

- analyzer, unit, contract, publish dry-run, and formatting gates
- required Android emulator E2E with device-bound keys
- required iOS simulator E2E with device-bound keys
- required macOS E2E and two-process restart checkpoint
- required Chrome E2E through ChromeDriver
- Linux and Windows contract test jobs

Mobile and web jobs are release gates. A workflow definition is not evidence
that a platform passed: the corresponding GitHub Actions run must be green
before a stable release.

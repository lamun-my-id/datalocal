#!/usr/bin/env bash
set -euo pipefail

device="${1:-macos}"
device_keys="${2:-false}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
repository_dir="$(cd "$script_dir/.." && pwd)"
cd "$repository_dir/example"

flutter test integration_test/restart_checkpoint_test.dart \
  -d "$device" \
  --dart-define=DATALOCAL_E2E_PHASE=seed \
  --dart-define=DATALOCAL_E2E_DEVICE_KEYS="$device_keys"
flutter test integration_test/restart_checkpoint_test.dart \
  -d "$device" \
  --dart-define=DATALOCAL_E2E_PHASE=verify \
  --dart-define=DATALOCAL_E2E_DEVICE_KEYS="$device_keys"

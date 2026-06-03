#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="${ROOT_DIR}/example/android"

if [[ ! -d "${ROOT_DIR}/node_modules/react-native" ]]; then
  echo "Missing react-native in node_modules. Run npm install from the repo root first." >&2
  exit 1
fi

cd "${ANDROID_DIR}"

echo "Building Android example (assembleDebug)..."
./gradlew :app:assembleDebug --no-daemon "$@"

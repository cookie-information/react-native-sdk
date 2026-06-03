#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${ROOT_DIR}/example/ios"
WORKSPACE="${IOS_DIR}/cookieinformationrnsdkexample.xcworkspace"
SCHEME="cookieinformationrnsdkexample"
DERIVED_DATA="${IOS_DIR}/build/DerivedData"

if [[ ! -d "${ROOT_DIR}/node_modules/react-native" ]]; then
  echo "Missing react-native in node_modules. Run npm install from the repo root first." >&2
  exit 1
fi

cd "${IOS_DIR}"

echo "Installing CocoaPods dependencies..."
pod install

echo "Building iOS example (${SCHEME})..."
xcodebuild build \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO \
  "$@"

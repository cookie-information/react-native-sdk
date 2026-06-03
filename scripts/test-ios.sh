#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="${ROOT_DIR}/ios/Tests"
WORKSPACE="${TESTS_DIR}/CookieInformationRNSDKTests.xcworkspace"
SCHEME="CookieInformationRNSDK-Unit-Tests"
DERIVED_DATA="${TESTS_DIR}/build/DerivedData"

if [[ ! -d "${ROOT_DIR}/node_modules/react-native" ]]; then
  echo "Missing react-native in node_modules. Run npm install from the repo root first." >&2
  exit 1
fi

cd "${TESTS_DIR}"

echo "Installing CocoaPods dependencies..."
pod install

# Keep in sync with CI / ios-simulator.env
ENV_FILE="$(dirname "${BASH_SOURCE[0]}")/ios-simulator.env"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

SIMULATOR="${IOS_SIMULATOR:-iPhone 16}"
SIMULATOR_OS="${IOS_SIMULATOR_OS:-18.5}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR},OS=${SIMULATOR_OS}"

echo "Running iOS tests (${SCHEME}) on ${SIMULATOR} (${SIMULATOR_OS})..."
xcodebuild test \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO

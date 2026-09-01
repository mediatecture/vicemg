#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="VicEmergency Monitor"
EXEC_NAME="VicEmergencyMonitor"
APP_BUNDLE="${APP_NAME}.app"

echo "Building release binary..."
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)/${EXEC_NAME}

echo "Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${EXEC_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

echo "Ad-hoc code signing..."
xattr -cr "${APP_BUNDLE}"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done: $(pwd)/${APP_BUNDLE}"

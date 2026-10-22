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
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "Ad-hoc code signing..."
# macOS occasionally re-attaches extended attributes between the cleanup and the
# signing, which makes codesign fail with "detritus not allowed" — so retry.
for attempt in 1 2 3 4 5; do
    xattr -cr "${APP_BUNDLE}"
    if codesign --force --deep --sign - "${APP_BUNDLE}"; then
        break
    fi
    if [ "${attempt}" = 5 ]; then
        echo "codesign failed after ${attempt} attempts" >&2
        exit 1
    fi
    sleep 1
done

echo "Done: $(pwd)/${APP_BUNDLE}"

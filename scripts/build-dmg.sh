#!/bin/bash
set -e

APP_NAME="CCStatsOSX"
BUILD_DIR=".build/release"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS/"
cp "CCStatsOSX/Info.plist" "${BUILD_DIR}/${APP_NAME}.app/Contents/"
cp "CCStatsOSX/Resources/AppIcon.icns" "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources/" 2>/dev/null || true

echo "Creating DMG..."
rm -f "${BUILD_DIR}/${APP_NAME}.dmg"
hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${BUILD_DIR}/${APP_NAME}.app" \
  -ov -format UDZO \
  "${BUILD_DIR}/${APP_NAME}.dmg"

echo "Done! DMG at: ${BUILD_DIR}/${APP_NAME}.dmg"

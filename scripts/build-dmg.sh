#!/bin/bash
set -e

APP_NAME="CCStatsOSX"
BUILD_DIR=".build/release"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

echo "Running tests..."
swift test
echo "Tests passed!"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS/"
cp "CCStatsOSX/Info.plist" "${BUILD_DIR}/${APP_NAME}.app/Contents/"
cp "CCStatsOSX/Resources/AppIcon.icns" "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources/" 2>/dev/null || true

echo "Creating DMG installer..."
rm -f "${BUILD_DIR}/${APP_NAME}.dmg"

if command -v create-dmg &> /dev/null; then
    create-dmg \
      --volname "${APP_NAME}" \
      --volicon "CCStatsOSX/Resources/AppIcon.icns" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "${APP_NAME}.app" 150 200 \
      --hide-extension "${APP_NAME}.app" \
      --app-drop-link 450 200 \
      "${BUILD_DIR}/${APP_NAME}.dmg" \
      "${BUILD_DIR}/${APP_NAME}.app" \
      || true  # create-dmg returns non-zero even on success sometimes
else
    echo "create-dmg not found, falling back to basic DMG..."
    echo "  Install for nicer installer: brew install create-dmg"
    hdiutil create -volname "${APP_NAME}" \
      -srcfolder "${BUILD_DIR}/${APP_NAME}.app" \
      -ov -format UDZO \
      "${BUILD_DIR}/${APP_NAME}.dmg"
fi

DMG_SIZE=$(du -h "${BUILD_DIR}/${APP_NAME}.dmg" | cut -f1 | xargs)
echo "Done! DMG at: ${BUILD_DIR}/${APP_NAME}.dmg (${DMG_SIZE})"

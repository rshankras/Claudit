#!/bin/bash
# Claudit Build, Sign, Notarize, and DMG Creation Script
# Usage: ./scripts/notarize.sh

set -e

# Configuration - Update these values
APP_NAME="Claudit"
SCHEME="Claudit"
TEAM_ID="${TEAM_ID:?Error: TEAM_ID environment variable required}"
APPLE_ID="${APPLE_ID:-your@email.com}"  # Set via environment
APP_PASSWORD="${APP_PASSWORD:-}"  # App-specific password, set via environment

# Paths
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

echo "=== Claudit Build & Notarization Script ==="
echo ""

# Create ExportOptions.plist with actual Team ID
echo "Preparing export options with Team ID..."
mkdir -p "$BUILD_DIR"
sed "s/REPLACE_WITH_YOUR_TEAM_ID/$TEAM_ID/g" scripts/ExportOptions.plist > "$EXPORT_OPTIONS"

# Step 1: Clean and Archive
echo "Step 1: Building archive..."
xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive

# Step 2: Export the app
echo "Step 2: Exporting app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

# Step 3: Create ZIP for notarization
echo "Step 3: Creating ZIP for notarization..."
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"
cd ..

# Step 4: Submit for notarization
echo "Step 4: Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

# Step 5: Staple the notarization ticket
echo "Step 5: Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# Step 6: Create DMG
echo "Step 6: Creating DMG..."
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 185 \
        "$DMG_PATH" \
        "$APP_PATH"
else
    echo "create-dmg not found, using hdiutil..."
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$APP_PATH" \
        -ov -format UDZO \
        "$DMG_PATH"
fi

# Step 7: Notarize DMG
echo "Step 7: Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

xcrun stapler staple "$DMG_PATH"

echo ""
echo "=== Build Complete ==="
echo "DMG: $DMG_PATH"
echo ""
echo "Verify notarization:"
echo "  spctl -a -vvv -t install $APP_PATH"
echo "  spctl -a -vvv -t install $DMG_PATH"

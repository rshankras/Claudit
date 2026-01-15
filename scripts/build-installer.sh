#!/bin/bash

# Claudit Installer Build Script
# Creates a distributable DMG installer

set -e

# Configuration
APP_NAME="Claudit"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Export"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
SCHEME="${APP_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Claudit Installer Builder${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Clean previous build
echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build Release archive
echo -e "${YELLOW}🔨 Building Release archive...${NC}"
xcodebuild -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | while read line; do
        if [[ "$line" == *"error:"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" == *"warning:"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" == *"BUILD SUCCEEDED"* ]] || [[ "$line" == *"ARCHIVE SUCCEEDED"* ]]; then
            echo -e "${GREEN}$line${NC}"
        fi
    done

# Check if archive was created
if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}❌ Archive failed to create${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive created successfully${NC}"

# Export the app from archive
echo -e "${YELLOW}📦 Exporting app from archive...${NC}"

# Create export options plist
cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

# Copy app directly from archive (simpler than export for unsigned builds)
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
if [ -d "${APP_PATH}" ]; then
    mkdir -p "${EXPORT_PATH}"
    cp -R "${APP_PATH}" "${EXPORT_PATH}/"
    echo -e "${GREEN}✅ App exported successfully${NC}"
else
    echo -e "${RED}❌ App not found in archive at ${APP_PATH}${NC}"
    # Try to find it
    echo "Archive contents:"
    find "${ARCHIVE_PATH}" -name "*.app" 2>/dev/null || true
    exit 1
fi

# Create DMG
echo -e "${YELLOW}💿 Creating DMG installer...${NC}"

# Create a temporary directory for DMG contents
DMG_TEMP="${BUILD_DIR}/dmg_temp"
mkdir -p "${DMG_TEMP}"

# Copy the app
cp -R "${EXPORT_PATH}/${APP_NAME}.app" "${DMG_TEMP}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP}/Applications"

# Optional: Add a background image or custom folder view
# You can customize this section later for a prettier DMG

# Create the DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${DMG_PATH}"

# Clean up temp
rm -rf "${DMG_TEMP}"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Build Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "📦 DMG Installer: ${YELLOW}${DMG_PATH}${NC}"
echo ""
echo -e "${BLUE}To install:${NC}"
echo -e "  1. Open the DMG file"
echo -e "  2. Drag ${APP_NAME} to Applications"
echo -e "  3. Eject the DMG"
echo -e "  4. Launch ${APP_NAME} from Applications"
echo ""

# Get file size
DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)
echo -e "DMG Size: ${DMG_SIZE}"

echo ""
echo -e "${BLUE}Next steps for distribution:${NC}"
echo -e "  1. Sign the app with your Developer ID:"
echo -e "     ${YELLOW}codesign --deep --force --verify --verbose --sign \"Developer ID Application: Your Name\" \"${EXPORT_PATH}/${APP_NAME}.app\"${NC}"
echo -e ""
echo -e "  2. Notarize the app with Apple:"
echo -e "     ${YELLOW}xcrun notarytool submit \"${DMG_PATH}\" --keychain-profile \"YOUR_PROFILE\" --wait${NC}"
echo -e ""
echo -e "  3. Staple the notarization ticket:"
echo -e "     ${YELLOW}xcrun stapler staple \"${DMG_PATH}\"${NC}"
echo ""

# Open the build folder
open "${BUILD_DIR}"

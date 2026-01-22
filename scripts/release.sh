#!/bin/bash
set -e

# GitFit Release Script
# Usage: ./scripts/release.sh 1.0.0
#
# Prerequisites:
# 1. Developer ID Application certificate in Keychain
# 2. App-specific password stored: xcrun notarytool store-credentials "GitFit-Notarize"
#    (You'll be prompted for Apple ID, Team ID, and app-specific password)

VERSION=$1
APP_NAME="GitFit"
BUNDLE_ID="com.chrisbongers.GitFit"
TEAM_ID="9LY22W4ZY3"
IDENTITY="Developer ID Application: Chris Bongers (${TEAM_ID})"

# Paths
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}

# Validate version argument
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.0"
    exit 1
fi

echo "========================================"
echo "  ${APP_NAME} Release Builder v${VERSION}"
echo "========================================"

# Check for Developer ID certificate
print_step "Checking for Developer ID certificate..."
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    print_error "Developer ID Application certificate not found in Keychain.

To fix this:
1. Go to https://developer.apple.com/account/resources/certificates
2. Create a 'Developer ID Application' certificate
3. Download and double-click to install in Keychain"
fi

# Check for notarytool credentials
print_step "Checking notarytool credentials..."
if ! xcrun notarytool history --keychain-profile "GitFit-Notarize" &>/dev/null; then
    print_warning "Notarization credentials not found. Setting up now..."
    echo "You'll need:"
    echo "  - Your Apple ID email"
    echo "  - An app-specific password (create at appleid.apple.com)"
    echo "  - Team ID: ${TEAM_ID}"
    echo ""
    xcrun notarytool store-credentials "GitFit-Notarize" --team-id "${TEAM_ID}"
fi

# Clean build directory
print_step "Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build archive
print_step "Building release archive..."
xcodebuild archive \
    -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    MARKETING_VERSION="${VERSION}" \
    CURRENT_PROJECT_VERSION="${VERSION}" \
    CODE_SIGN_IDENTITY="${IDENTITY}" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_STYLE="Manual" \
    | xcpretty || xcodebuild archive \
    -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    MARKETING_VERSION="${VERSION}" \
    CURRENT_PROJECT_VERSION="${VERSION}" \
    CODE_SIGN_IDENTITY="${IDENTITY}" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_STYLE="Manual"

# Export app from archive
print_step "Exporting app from archive..."
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_PATH}"

# Sign the app (with hardened runtime for notarization)
print_step "Signing app with hardened runtime..."
codesign --force --deep --options runtime \
    --sign "${IDENTITY}" \
    --timestamp \
    "${APP_PATH}"

# Verify signature
print_step "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

# Create ZIP for notarization
print_step "Creating ZIP for notarization..."
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

# Submit for notarization
print_step "Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "${ZIP_PATH}" \
    --keychain-profile "GitFit-Notarize" \
    --wait

# Staple the notarization ticket
print_step "Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"

# Verify notarization
print_step "Verifying notarization..."
spctl --assess --type execute --verbose "${APP_PATH}"

# Create DMG
print_step "Creating DMG..."
# Create a temporary folder for DMG contents
DMG_TEMP="${BUILD_DIR}/dmg-temp"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create symlink to Applications folder
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${DMG_PATH}"

# Sign the DMG
print_step "Signing DMG..."
codesign --force --sign "${IDENTITY}" --timestamp "${DMG_PATH}"

# Notarize the DMG
print_step "Notarizing DMG..."
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "GitFit-Notarize" \
    --wait

# Staple DMG
xcrun stapler staple "${DMG_PATH}"

# Calculate SHA256
print_step "Calculating SHA256..."
SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

# Cleanup
rm -rf "${DMG_TEMP}" "${ZIP_PATH}" "${ARCHIVE_PATH}"

# Done!
echo ""
echo "========================================"
echo -e "${GREEN}  Build complete!${NC}"
echo "========================================"
echo ""
echo "DMG: ${DMG_PATH}"
echo "SHA256: ${SHA256}"
echo ""
echo "Next steps:"
echo "1. Create a GitHub release tagged 'v${VERSION}'"
echo "2. Upload ${DMG_PATH} to the release"
echo "3. Update the Homebrew cask with:"
echo ""
echo "   version \"${VERSION}\""
echo "   sha256 \"${SHA256}\""
echo ""

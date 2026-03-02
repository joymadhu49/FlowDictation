#!/bin/bash
# Build FlowDictation.app bundle
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="FlowDictation"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
RESOURCES_DIR="$PROJECT_DIR/Sources/FlowDictation/Resources"

echo "Building $APP_NAME..."

# Build with Swift PM
cd "$PROJECT_DIR"
swift build -c release 2>&1

# Get the binary path
BINARY_PATH=$(swift build -c release --show-bin-path)/"$APP_NAME"

# Create .app bundle structure
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Update executable name in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

# Copy app icon
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "Copied app icon"
fi

# Copy entitlements (for reference)
if [ -f "$RESOURCES_DIR/FlowDictation.entitlements" ]; then
    cp "$RESOURCES_DIR/FlowDictation.entitlements" "$APP_BUNDLE/Contents/Resources/FlowDictation.entitlements"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Code sign the app
echo "Code signing..."
ENTITLEMENTS="$RESOURCES_DIR/FlowDictation.entitlements"

# Check for Developer ID certificate
DEVELOPER_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')

if [ -n "$DEVELOPER_ID" ]; then
    echo "Signing with Developer ID: $DEVELOPER_ID"
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$DEVELOPER_ID" "$APP_BUNDLE"
else
    echo "No Developer ID found, using ad-hoc signing"
    codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP_BUNDLE"
fi

echo "Verifying signature..."
codesign --verify --verbose "$APP_BUNDLE" 2>&1 || echo "Warning: signature verification had issues"

# Create DMG
echo ""
echo "Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_TEMP="$BUILD_DIR/dmg_temp"

rm -rf "$DMG_TEMP" "$DMG_PATH"
mkdir -p "$DMG_TEMP"

# Copy app to temp directory
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$DMG_TEMP/Applications"

# Create the double-click installer script inside DMG
cat > "$DMG_TEMP/Install FlowDictation.command" << 'INSTALLER'
#!/bin/bash
# FlowDictation Installer — Double-click to install!
set -e

APP_NAME="FlowDictation"
DMG_MOUNT="$(dirname "$0")"
INSTALL_DIR="/Applications"

clear
echo "============================================"
echo "   FlowDictation Installer"
echo "============================================"
echo ""

# Check if app exists in DMG
if [ ! -d "$DMG_MOUNT/$APP_NAME.app" ]; then
    echo "Error: $APP_NAME.app not found!"
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Remove old version if exists
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing previous version..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Copy app
echo "Installing $APP_NAME to Applications..."
cp -R "$DMG_MOUNT/$APP_NAME.app" "$INSTALL_DIR/"

# Remove quarantine attribute (this is the key fix!)
echo "Configuring for first launch..."
xattr -cr "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "Installation complete!"
echo ""
echo "Launching $APP_NAME..."
open -a "$APP_NAME"

echo ""
echo "You can close this window now."
echo ""

# Keep window open briefly so user sees the success message
sleep 2
INSTALLER
chmod +x "$DMG_TEMP/Install FlowDictation.command"

# Create the DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH" 2>&1

# Clean up temp directory
rm -rf "$DMG_TEMP"

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"
echo "DMG: $DMG_PATH"
echo ""
echo "To run: open \"$APP_BUNDLE\""
echo ""
echo "IMPORTANT: First-time setup:"
echo "  1. Set your Groq API key in the Settings window"
echo "  2. Grant Accessibility permission when prompted"
echo "  3. Grant Microphone permission when prompted"

#!/bin/bash
# FlowDictation Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/joymadhu49/FlowDictation/main/scripts/install.sh | bash
set -e

APP_NAME="FlowDictation"
REPO="joymadhu49/FlowDictation"
INSTALL_DIR="/Applications"

echo "Installing $APP_NAME..."

# Get latest release DMG URL
LATEST_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep "browser_download_url.*\.dmg" | head -1 | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "Error: Could not find latest release. Falling back to main branch build..."
    echo "Please download manually from: https://github.com/$REPO/releases"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
DMG_PATH="$TEMP_DIR/$APP_NAME.dmg"
MOUNT_POINT="$TEMP_DIR/mount"

cleanup() {
    # Unmount if mounted
    if [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Download DMG
echo "Downloading $APP_NAME..."
curl -fsSL -o "$DMG_PATH" "$LATEST_URL"

# Mount DMG
echo "Mounting DMG..."
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

# Check if app exists in mounted DMG
if [ ! -d "$MOUNT_POINT/$APP_NAME.app" ]; then
    echo "Error: $APP_NAME.app not found in DMG"
    exit 1
fi

# Remove old version if exists
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing previous version..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Copy app to Applications
echo "Installing to $INSTALL_DIR..."
cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"

# Remove quarantine attribute
echo "Removing quarantine attribute..."
xattr -cr "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "$APP_NAME installed successfully!"
echo ""
echo "To launch: open -a $APP_NAME"
echo ""
echo "First-time setup:"
echo "  1. Set your Groq API key in the Settings window"
echo "  2. Grant Accessibility permission when prompted"
echo "  3. Grant Microphone permission when prompted"

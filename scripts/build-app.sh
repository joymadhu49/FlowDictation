#!/bin/bash
# Build FlowDictation.app bundle
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="FlowDictation"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

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
cp "$PROJECT_DIR/Sources/FlowDictation/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Update executable name in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

# Copy app icon
cp "$PROJECT_DIR/Sources/FlowDictation/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run: open \"$APP_BUNDLE\""
echo ""
echo "IMPORTANT: First-time setup:"
echo "  1. Set your Groq API key in the Settings window"
echo "  2. Grant Accessibility permission when prompted"
echo "  3. Grant Microphone permission when prompted"

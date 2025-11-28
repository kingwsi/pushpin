#!/bin/bash

#
# build.sh - macOS App bundler for Swift Package Manager projects
#

# Stop on first error
set -e

# --- Configuration ---
APP_NAME="Pushpin"
# Use the directory of the script as the project root
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"
RESOURCES_DIR="$PROJECT_DIR/Sources/Pushpin/Resources"
OUTPUT_DIR="$PROJECT_DIR" # Output to project directory
APP_BUNDLE_PATH="$OUTPUT_DIR/$APP_NAME.app"
EXECUTABLE_PATH="$BUILD_DIR/$APP_NAME"

# --- Main ---

# Check for Xcode command line tools
if ! command -v xcrun &> /dev/null; then
    echo "Error: Xcode Command Line Tools are not installed. Please install them by running 'xcode-select --install' and try again."
    exit 1
fi

echo "--- Building Universal Binary ---"
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64

echo "--- Creating .app Bundle Structure ---"
rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS"
mkdir -p "$APP_BUNDLE_PATH/Contents/Resources"

echo "--- Copying Executable ---"
cp "$EXECUTABLE_PATH" "$APP_BUNDLE_PATH/Contents/MacOS/"

echo "--- Creating Info.plist ---"
INFO_PLIST_PATH="$APP_BUNDLE_PATH/Contents/Info.plist"
cat > "$INFO_PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.pushpin</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

ASSETS_PATH="$RESOURCES_DIR/Assets.xcassets"
if [ -d "$ASSETS_PATH" ]; then
    echo "--- Compiling Asset Catalog ---"
    xcrun actool "$ASSETS_PATH" \
      --compile "$APP_BUNDLE_PATH/Contents/Resources" \
      --platform macosx \
      --minimum-deployment-target 14.0 \
      --app-icon AppIcon \
      --output-partial-info-plist /dev/null
fi

echo "--- Performing Ad-hoc Code Signing ---"
codesign --force --deep --sign - "$APP_BUNDLE_PATH"

echo ""
echo "✅ Success! Application bundle created at: $APP_BUNDLE_PATH"
echo "You can now drag this file to your /Applications folder."


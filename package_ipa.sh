#!/bin/bash
set -e

# Configuration
APP_NAME="Clip"
PROJECT="Clip.xcodeproj"
SCHEME="Clip"
ENTITLEMENTS_MAIN="Clip/ClipTS.entitlements"
ENTITLEMENTS_KEYBOARD="ClipBoard/ClipBoard.entitlements"
ENTITLEMENTS_READER="ClipboardReader/ClipboardReader.entitlements"
BUILD_DIR="build"
OUTPUT_IPA="Clip_TrollStore.ipa"

# Cleanup
echo "🧹 Cleaning up previous builds..."
rm -rf "$BUILD_DIR" "$OUTPUT_IPA"

# Build
echo "🏗 Building Project..."
# Using xcodebuild to archive the project
# We disable code signing to manually sign later
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$BUILD_DIR/Clip.xcarchive" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    > /dev/null

if [ ! -d "$BUILD_DIR/Clip.xcarchive" ]; then
    echo "❌ Build failed. Please check your Xcode setup."
    exit 1
fi

# Prepare Payload
echo "📦 Preparing Payload..."
mkdir -p "$BUILD_DIR/Payload"
cp -R "$BUILD_DIR/Clip.xcarchive/Products/Applications/$APP_NAME.app" "$BUILD_DIR/Payload/"

APP_PATH="$BUILD_DIR/Payload/$APP_NAME.app"

# Sign Frameworks
if [ -d "$APP_PATH/Frameworks" ]; then
    echo "🔏 Signing Frameworks..."
    find "$APP_PATH/Frameworks" -name "*.framework" -exec codesign --force --sign - {} \;
fi

# Sign Extensions
# We use the original entitlements for extensions to ensure App Group access works
if [ -d "$APP_PATH/PlugIns/ClipBoard.appex" ]; then
    echo "🔏 Signing Keyboard Extension..."
    codesign --force --sign - --entitlements "$ENTITLEMENTS_KEYBOARD" "$APP_PATH/PlugIns/ClipBoard.appex"
fi

if [ -d "$APP_PATH/PlugIns/ClipboardReader.appex" ]; then
    echo "🔏 Signing Clipboard Reader Extension..."
    codesign --force --sign - --entitlements "$ENTITLEMENTS_READER" "$APP_PATH/PlugIns/ClipboardReader.appex"
fi

# Sign Main App
echo "🔏 Signing Main App with Sandbox Escape Entitlements..."
# This is the critical step for TrollStore/Sandbox Escape
codesign --force --sign - --entitlements "$ENTITLEMENTS_MAIN" "$APP_PATH"

# Package
echo "📦 Packaging IPA..."
cd "$BUILD_DIR"
zip -qr "../$OUTPUT_IPA" Payload

echo "✅ Done! IPA generated at: $OUTPUT_IPA"
echo "👉 You can now install this IPA via TrollStore."

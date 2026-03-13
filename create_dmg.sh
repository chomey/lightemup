#!/bin/bash
set -e

# Build the app first
./build.sh

APP_NAME="LightEmUp"
DMG_NAME="LightEmUp"
VERSION="1.0"
VOLUME_NAME="Light Em Up"
DMG_DIR="dist"
DMG_PATH="$DMG_DIR/$DMG_NAME-$VERSION.dmg"
STAGING_DIR="$DMG_DIR/staging"

echo "Creating DMG..."

# Clean
rm -rf "$DMG_DIR"
mkdir -p "$STAGING_DIR"

# Copy app
cp -r "build/$APP_NAME.app" "$STAGING_DIR/"

# Ad-hoc sign
codesign --force --deep --sign - "$STAGING_DIR/$APP_NAME.app"

# Create symlink to Applications
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean staging
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"

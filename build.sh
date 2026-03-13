#!/bin/bash
set -e

APP_DIR="build/LightEmUp.app/Contents"

mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

swiftc \
    -o "$APP_DIR/MacOS/LightEmUp" \
    -framework Cocoa \
    -framework CoreGraphics \
    LightEmUp/main.swift \
    LightEmUp/AppDelegate.swift \
    LightEmUp/BrightnessBooster.swift \
    LightEmUp/OnboardingWindow.swift \
    LightEmUp/HotkeyRecorder.swift

cp LightEmUp/Info.plist "$APP_DIR/Info.plist"
cp LightEmUp/LightEmUp.icns "$APP_DIR/Resources/LightEmUp.icns"

echo "Built: build/LightEmUp.app"
echo "Run with: open build/LightEmUp.app"

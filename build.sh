#!/bin/bash
# Builds MouseScroll.app; pass "install" to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/MouseScroll.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
if [ "${UNIVERSAL:-}" = "1" ]; then
    for arch in arm64 x86_64; do
        swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" Sources/main.swift -o "build/MouseScroll-$arch"
    done
    lipo -create build/MouseScroll-arm64 build/MouseScroll-x86_64 -output "$APP/Contents/MacOS/MouseScroll"
    rm build/MouseScroll-arm64 build/MouseScroll-x86_64
else
    swiftc -O -swift-version 5 Sources/main.swift -o "$APP/Contents/MacOS/MouseScroll"
fi
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
codesign --force --sign - --identifier com.ag.mousescroll "$APP"
echo "Built $APP"
if [ "${1:-}" = "install" ]; then
    pkill -x MouseScroll 2>/dev/null || true
    rm -rf /Applications/MouseScroll.app
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/MouseScroll.app"
fi

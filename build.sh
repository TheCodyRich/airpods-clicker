#!/bin/bash
# Builds a universal (Apple Silicon + Intel) AirPodClicker.app in ./build and ad-hoc signs it.
# Pass --dmg to also package build/AirPodClicker.dmg for a release.
set -euo pipefail
cd "$(dirname "$0")"

for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx13.0"
done

APP=build/AirPodClicker.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
lipo -create -output "$APP/Contents/MacOS/AirPodClicker" \
    .build/arm64-apple-macosx/release/AirPodClicker \
    .build/x86_64-apple-macosx/release/AirPodClicker
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - --identifier com.example.AirPodClicker "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/AirPodClicker"))"

if [[ "${1:-}" == "--dmg" ]]; then
    DMG=build/AirPodClicker.dmg
    STAGE=build/dmg
    rm -rf "$STAGE" "$DMG"
    mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -quiet -volname "AirPod Clicker" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
    rm -rf "$STAGE"
    echo "Built $DMG"
fi

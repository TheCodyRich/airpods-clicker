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

# The DMG opens to a window with the app, an arrow, and an Applications shortcut.
# Needs dmgbuild (`pip install dmgbuild`); set DMGBUILD to use a specific copy.
if [[ "${1:-}" == "--dmg" ]]; then
    DMG=build/AirPodClicker.dmg
    rm -f "$DMG"
    "${DMGBUILD:-dmgbuild}" -s dmg/settings.py -D app="$APP" -D background=dmg/background.tiff "AirPod Clicker" "$DMG"
    echo "Built $DMG"
fi

#!/bin/bash
# Builds AirPodClicker.app in ./build and ad-hoc signs it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/AirPodClicker.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/AirPodClicker "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - --identifier com.example.AirPodClicker "$APP"
echo "Built $APP"

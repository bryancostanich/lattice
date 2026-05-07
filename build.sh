#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="Lattice.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp .build/release/Lattice "$APP/Contents/MacOS/Lattice"
codesign -s - --force "$APP/Contents/MacOS/Lattice"
codesign -s - --force "$APP"

echo "Built $APP"

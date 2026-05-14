#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

IDENTITY="${LATTICE_SIGN_IDENTITY:-Developer ID Application: bryan costanich (4HPM47RCM4)}"
NOTARIZE_PROFILE="${LATTICE_NOTARIZE_PROFILE:-Lattice}"
ENTITLEMENTS="Resources/Lattice.entitlements"
SKIP_NOTARIZE="${LATTICE_SKIP_NOTARIZE:-0}"

swift build -c release

APP="Lattice.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp .build/release/Lattice "$APP/Contents/MacOS/Lattice"

codesign --force \
    --sign "$IDENTITY" \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    "$APP/Contents/MacOS/Lattice"

codesign --force \
    --sign "$IDENTITY" \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    "$APP"

echo "Signed $APP"

if [[ "$SKIP_NOTARIZE" == "1" ]]; then
    echo "Skipping notarization (LATTICE_SKIP_NOTARIZE=1)"
    exit 0
fi

ZIP="Lattice-notarize.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting for notarization (this may take a minute)..."
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait

xcrun stapler staple "$APP"
rm -f "$ZIP"

echo "Notarized $APP"
spctl --assess --verbose "$APP"

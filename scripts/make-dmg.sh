#!/bin/bash
# Build a Developer ID–signed, notarized, stapled Jiggle-X DMG in dist/.
#
# One-time setup (stores an app-specific password in the keychain):
#   xcrun notarytool store-credentials notary --apple-id <you> --team-id GT69QL2KK5
#
# Usage: scripts/make-dmg.sh            # build, sign, notarize, staple
#        SKIP_NOTARIZE=1 scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
BUILD=build/release
ARCHIVE="$BUILD/Jiggle-X.xcarchive"
EXPORT="$BUILD/export"
TEAM=$(grep -m1 'DEVELOPMENT_TEAM' JiggleX.xcodeproj/project.pbxproj | sed -E 's/.*= ([A-Z0-9]+);/\1/')

rm -rf "$BUILD" && mkdir -p "$BUILD" dist

xcodebuild archive -project JiggleX.xcodeproj -scheme JiggleX -configuration Release \
  -archivePath "$ARCHIVE" -quiet

cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" -quiet

APP="$EXPORT/Jiggle-X.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG="dist/Jiggle-X-$VERSION.dmg"
codesign --verify --deep --strict "$APP"

STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Jiggle-X $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" -quiet

IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "$TEAM" | head -1 | sed -E 's/.*"(.*)"/\1/')
codesign --sign "$IDENTITY" --timestamp "$DMG"

if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature -v "$DMG"
fi

shasum -a 256 "$DMG"
echo "Built $DMG"

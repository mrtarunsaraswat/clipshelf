#!/bin/bash
# Builds an ad-hoc signed, NOT notarized DMG for publishing on GitHub Releases.
# Gatekeeper will block the first launch on other Macs; users approve it once
# in System Settings → Privacy & Security → Open Anyway (see README).
# For a notarized release, use release_macos.sh with a Developer ID instead.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter analyze --no-fatal-infos
flutter test
./scripts/build_macos.sh
./scripts/test_native.sh

app="$PWD/build/macos/Build/Products/Release/ClipShelf.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
release="$PWD/dist"
dmg="$release/ClipShelf-$version.dmg"
mkdir -p "$release"

staging="$(mktemp -d "$release/dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/ClipShelf.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname "ClipShelf $version" -srcfolder "$staging" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
(cd "$release" && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")

printf '\nUnnotarized DMG: %s\n' "$dmg"
cat "$dmg.sha256"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPER_ID_APPLICATION:?Set your Developer ID Application signing identity}"
: "${NOTARY_PROFILE:?Set the name of your notarytool Keychain profile}"
flutter analyze
flutter test
python3 scripts/test_signing.py
./scripts/build_macos.sh
./scripts/test_native.sh
app="$PWD/build/macos/Build/Products/Release/ClipShelf.app"
entitlements="$PWD/macos/Runner/Release.entitlements"
widget_entitlements="$PWD/macos/ClipShelfWidgets/Widget.entitlements"
widget="$app/Contents/PlugIns/ClipShelfWidgets.appex"
if [[ -n "${ICLOUD_CONTAINER_IDENTIFIER:-}${WIDGET_APP_GROUP_ID:-}" ]]; then
  : "${HOST_PROVISIONING_PROFILE:=${ICLOUD_PROVISIONING_PROFILE:-}}"
  : "${HOST_PROVISIONING_PROFILE:?Set the host Developer ID provisioning profile path}"
  security cms -D -i "$HOST_PROVISIONING_PROFILE" > build/host-profile.plist
  bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
  python3 scripts/icloud_entitlements.py build/host-profile.plist "${ICLOUD_CONTAINER_IDENTIFIER:-}" "$bundle_id" build/host.entitlements "${WIDGET_APP_GROUP_ID:-}" host
  entitlements="$PWD/build/host.entitlements"
  cp "$HOST_PROVISIONING_PROFILE" "$app/Contents/embedded.provisionprofile"
fi
if [[ -n "${WIDGET_APP_GROUP_ID:-}" ]]; then
  : "${WIDGET_PROVISIONING_PROFILE:?Set the widget Developer ID provisioning profile path}"
  security cms -D -i "$WIDGET_PROVISIONING_PROFILE" > build/widget-profile.plist
  widget_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$widget/Contents/Info.plist")
  python3 scripts/icloud_entitlements.py build/widget-profile.plist "" "$widget_id" build/widget.entitlements "$WIDGET_APP_GROUP_ID" widget
  python3 - <<'CHECK_TEAMS'
import plistlib
from pathlib import Path
host = plistlib.loads(Path('build/host.entitlements').read_bytes())
widget = plistlib.loads(Path('build/widget.entitlements').read_bytes())
if host['com.apple.developer.team-identifier'] != widget['com.apple.developer.team-identifier']:
    raise SystemExit('Host and widget profiles must belong to the same Apple Developer team.')
CHECK_TEAMS
  widget_entitlements="$PWD/build/widget.entitlements"
  cp "$WIDGET_PROVISIONING_PROFILE" "$widget/Contents/embedded.provisionprofile"
fi
release="$PWD/dist"
mkdir -p "$release"
for framework in "$app"/Contents/Frameworks/*.framework; do
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$framework"
done
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" \
  --entitlements "$widget_entitlements" "$widget"
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" \
  --entitlements "$entitlements" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$release/ClipShelf-notarization.zip"
xcrun notarytool submit "$release/ClipShelf-notarization.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
staging="$(mktemp -d "$release/dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/ClipShelf.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname ClipShelf -srcfolder "$staging" -ov -format UDZO "$release/ClipShelf.dmg"
codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$release/ClipShelf.dmg"
xcrun notarytool submit "$release/ClipShelf.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$release/ClipShelf.dmg"
xcrun stapler validate "$release/ClipShelf.dmg"
shasum -a 256 "$release/ClipShelf.dmg" > "$release/ClipShelf.dmg.sha256"
printf '\nReady for distribution: %s\n' "$release/ClipShelf.dmg"

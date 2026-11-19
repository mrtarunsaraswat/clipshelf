#!/bin/bash
# Experimental local development signing; no paid Developer ID or CloudKit/profile.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${LOCAL_TEAM_ID:?Set LOCAL_TEAM_ID to your Xcode Personal Team ID}"
: "${LOCAL_SIGNING_IDENTITY:?Set LOCAL_SIGNING_IDENTITY to your Apple Development identity name or SHA-1}"
group="${LOCAL_WIDGET_APP_GROUP:-$LOCAL_TEAM_ID.clipshelf}"
entitlements="$PWD/build/local-widget"
python3 scripts/local_widget_entitlements.py "$LOCAL_TEAM_ID" "$group" "$entitlements"
# Fail before building when the private-key identity is unavailable to this shell.
identity_listing="$(security find-identity -v -p codesigning)"
printf '%s\n' "$identity_listing" | python3 -c '
import re, sys
requested = sys.argv[1]
identities = re.findall(r"\b([0-9A-Fa-f]{40})\s+\"([^\"]+)\"", sys.stdin.read())
if not any(requested.lower() == digest.lower() or requested == name for digest, name in identities):
    raise SystemExit("Signing identity is unavailable. In Xcode → Settings → Accounts → Personal Team → Manage Certificates, create Apple Development. Ensure its private key is accessible from this Terminal.")
' "$LOCAL_SIGNING_IDENTITY"
# Use the ordinary release build, with CloudKit explicitly left off.
ICLOUD_CONTAINER_IDENTIFIER="" WIDGET_APP_GROUP_ID="$group" bash scripts/build_macos.sh
app="$PWD/build/macos/Build/Products/Release/ClipShelf.app"
widget="$app/Contents/PlugIns/ClipShelfWidgets.appex"
for framework in "$app"/Contents/Frameworks/*.framework; do
  codesign --force --options runtime --timestamp=none --sign "$LOCAL_SIGNING_IDENTITY" "$framework"
done
codesign --force --options runtime --timestamp=none --sign "$LOCAL_SIGNING_IDENTITY" \
  --entitlements "$entitlements/widget.entitlements" "$widget"
codesign --force --options runtime --timestamp=none --sign "$LOCAL_SIGNING_IDENTITY" \
  --entitlements "$entitlements/host.entitlements" "$app"
for bundle in "$widget" "$app"; do
  actual_team="$(codesign --display --verbose=4 "$bundle" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  if [[ "$actual_team" != "$LOCAL_TEAM_ID" ]]; then
    echo "Signing certificate belongs to a different team. The app has not been launched." >&2
    exit 1
  fi
  configured_group=$(/usr/libexec/PlistBuddy -c 'Print :ClipShelfAppGroup' "$bundle/Contents/Info.plist")
  if [[ "$configured_group" != "$group" ]]; then
    echo 'The built App Group does not match the signing configuration.' >&2
    exit 1
  fi
done
codesign --verify --deep --strict "$app"
printf '\nLocal development app: %s\n' "$app"
printf 'Quit older ClipShelf instances before opening this build. Enable Desktop Favorites only after the shared-storage check succeeds.\n'
printf 'This is an experimental local test build, not a notarized distribution release. Live widget operation still needs testing.\n'

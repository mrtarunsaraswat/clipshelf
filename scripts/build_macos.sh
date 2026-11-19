#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter build macos --release --config-only
# Building the project also works in environments where workspace discovery fails.
xcodebuild -project macos/Runner.xcodeproj -scheme Runner \
  -configuration Release -derivedDataPath build/macos \
  CLIPSHELF_CLOUD_CONTAINER="${ICLOUD_CONTAINER_IDENTIFIER:-}" \
  CLIPSHELF_APP_GROUP_ID="${WIDGET_APP_GROUP_ID:-}" \
  CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/macos/Build/Products/Release/ClipShelf.app"
# A plain `xcodebuild build` leaves debug-map symbols that embed absolute build
# paths (including the builder's home folder). Strip them before signing; the
# separate dSYM keeps full debug info for local crash symbolication.
strip -S "$app/Contents/MacOS/ClipShelf" \
  "$app/Contents/PlugIns/ClipShelfWidgets.appex/Contents/MacOS/ClipShelfWidgets" 2>/dev/null
# Ad-hoc signing makes a local test build. Distribution needs release_macos.sh.
for framework in "$app"/Contents/Frameworks/*.framework; do
  codesign --force --sign - "$framework"
done
codesign --force --sign - --entitlements macos/ClipShelfWidgets/Widget.entitlements "$app/Contents/PlugIns/ClipShelfWidgets.appex"
codesign --force --sign - --entitlements macos/Runner/Release.entitlements "$app"
codesign --verify --deep --strict "$app"
printf '\nLocal app: %s\n' "$app"

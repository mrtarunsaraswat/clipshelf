#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
frameworks="$PWD/build/macos/Build/Products/Release"
if [[ ! -d "$frameworks/FlutterMacOS.framework" ]]; then
  echo 'Run scripts/build_macos.sh first.' >&2; exit 1
fi
mkdir -p build/native-tests
swiftc -module-cache-path build/native-tests/module-cache \
  -F "$frameworks" -framework FlutterMacOS \
  -Xlinker -rpath -Xlinker "$frameworks" \
  macos/Shared/WidgetFavorites.swift macos/Runner/FloatingPanelState.swift macos/Runner/WidgetLibraryExporter.swift \
  macos/Runner/Screenshots/ScreenshotMonitor.swift macos/Runner/Screenshots/ScreenshotCaptureBridge.swift \
  macos/Runner/MainFlutterWindow.swift macos/Flutter/GeneratedPluginRegistrant.swift \
  native_tests/main.swift -o build/native-tests/run
build/native-tests/run "$@"

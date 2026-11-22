# Developing ClipShelf

Building, testing, project layout, and release scripts. See also the [architecture guide](ARCHITECTURE.md) and [widget signing](WIDGETS.md).

## Build and test

Requires macOS 12+, Flutter stable, Xcode, and the macOS build tools. Built and tested with Flutter 3.50.0.

**CI:** [.github/workflows/macos.yml](../.github/workflows/macos.yml) runs on every push and pull request: analyze, Flutter tests, universal build, and native tests. Each run uploads `ClipShelf.app` as a ZIP under **Actions → the run → Artifacts** (kept 30 days, GitHub sign-in required). Pushing a tag such as `v1.0.1` — matching `version:` in `pubspec.yaml` — also builds the unnotarized DMG and publishes it as a GitHub release.

The current binary contains arm64 and x86_64; Intel runtime testing is still required if you distribute it. Future Flutter releases may change Intel support.

```sh
flutter pub get
flutter run -d macos
flutter analyze
flutter test
./scripts/build_macos.sh
./scripts/test_native.sh
```

The local app is at `build/macos/Build/Products/Release/ClipShelf.app`. The build script configures Flutter, builds through Xcode's project entry point, and ad-hoc signs/verifies the result. The workspace entry point failed in the restricted development environment. Swift Package Manager is disabled because there are no native plugin dependencies and nested manifest sandboxing was unavailable.

Regenerate the sample UI renderings (saved in `screenshots/`, used by the README) on macOS with:

```sh
flutter test --update-goldens tool/preview_test.dart
flutter test --update-goldens --dart-define=QUICK_PREVIEW=true tool/preview_test.dart
```

## Project structure

- `lib/main.dart`: app bootstrap and Riverpod `ProviderScope`.
- `lib/app/`: app widget and theme.
- `lib/features/clipboard/domain/`: immutable models and repository interface.
- `lib/features/clipboard/data/`: method-channel repository.
- `lib/features/clipboard/application/`: Riverpod state controllers and derived selectors.
- `lib/features/clipboard/presentation/`: screen, UI actions, and modular shelf/panel/card/preview widgets.
- `lib/features/screenshots/`: typed screenshot settings and reactive Preferences controls.
- `lib/features/settings/`, `pinboards/`, `snippets/`: feature-specific views, forms, and drafts.
- `docs/ARCHITECTURE.md`: data flow, ownership, lifecycle, errors, and test strategy.
- `test/clipboard_controller_test.dart`: independent controller tests using a fake repository.
- `macos/Runner/MainFlutterWindow.swift`: native clipboard, window placement, history persistence, merge/version logic, and CloudKit transport.
- `macos/Shared/WidgetFavorites.swift`: bounded, version-local widget snapshot and copy lookup.
- `macos/ClipShelfWidgets/`: configurable SwiftUI WidgetKit extension and copy AppIntent.
- `macos/Runner/FloatingPanelState.swift`: device-local panel preferences and geometry.
- `macos/Runner/WidgetLibraryExporter.swift`: saved-text-only export policy and timeline refresh.
- `macos/Runner/Screenshots/`: screenshot file tracking, image decoding, folder observation, and clipboard/history integration.
- `native_tests/main.swift`: native checks, including simulated offline Macs.
- `test/widget_test.dart`: Flutter behavior checks.
- `scripts/`: local build, native test, provisioning validation, and release workflow.
- `tool/`: preview rendering and reproducible app-icon generation.

## Verification and remaining checks

Flutter analysis, 36 unit/widget tests, the native logic suite, the universal release build, and ad-hoc signature verification have been exercised. Controller tests cover initial loading, out-of-order reads, native updates during loading/refresh, failure recovery, lifecycle cleanup, typed actions, filtering/selection, and immutable data. The shelf and quick-panel previews remain covered; a floating preview was added. Small and medium SwiftUI widget layouts were rendered with sample content (link labels are substituted only in preview builds because ImageRenderer cannot render system Links). Widget checks include row/numbered default paste, the side Copy button, the Paste-first context menu, live permission grant/revocation, updating an already-open Preferences dialog, switching to the shelf, drag-to-pin, compact layout, snippet validation, and explicit sync consent. Native permission checks verify that grants and revocations push UI updates even without clipboard changes, and unchanged permission does not repeatedly publish history. Native geometry checks cover screen-edge placement, short displays, and secondary displays with negative coordinates. Native checks cover HTML/image/multi-item restoration, persistence, saved-item retention, archive migration, merging offline additions, and preventing deleted records from returning after stale updates/restarts.

New native checks cover floating dismissal policy and saved geometry, widget export exclusions, exact Unicode text, size limits, unchanged snapshots, feedback expiry, and clearing shared data when disabled. The widget extension compiles for both Mac architectures and is embedded and ad-hoc signed. Personal Team signing and host shared-container read/write access were verified in 1.4.2. The user subsequently confirmed widget discovery, text display, and operation after a clean installation; see docs/VALIDATION-1.4.2.md for the original signing checks.

The environment denied an isolated real pasteboard write, so the native suite uses an in-memory boundary by default. `./scripts/test_native.sh --system-pasteboard` exercises a unique named macOS pasteboard without touching the user's clipboard; run this outside the restricted environment. Native UI automation still times out inspecting ClipShelf, so the fullscreen/Spaces fix is compiled but not verified interactively here. Test actual OS capture/restore, hotkey conflicts, multiple displays/Spaces, returning focus, Accessibility grant/deny/revoke, and clean-Mac Gatekeeper behavior interactively.

After provisioning, use two Macs on the same Apple Account to verify initial sync, text/images/pinboards, offline edits, concurrent pinning/deleting, network interruptions, account changes, quota errors, and restart recovery. Live CloudKit transfer is not yet verified.

## References

- [Paste's Mac workflow](https://pasteapp.io/help/paste-on-mac)
- [Flutter macOS build and distribution](https://docs.flutter.dev/platform-integration/macos/building)
- [Apple iCloud capability configuration](https://developer.apple.com/documentation/xcode/configuring-icloud-services/)
- [Apple NSPasteboard changeCount](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)

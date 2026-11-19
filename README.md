# ClipShelf

A Flutter macOS clipboard manager with a bottom-of-screen card shelf, pinboards, snippets, a floating mini-panel, a native Favorites widget, and an optional iCloud sync layer. Inspired by Paste's Mac workflow, with its own interface and branding. Flutter shared state is managed with Riverpod; see [the architecture guide](docs/ARCHITECTURE.md).

## Install

Requires macOS 12 or later on Apple Silicon or Intel.

1. Download `ClipShelf-<version>.dmg` from the GitHub **Releases** page. Optionally check it against the `.sha256` file: `shasum -a 256 -c ClipShelf-<version>.dmg.sha256`.
2. Open the DMG and drag **ClipShelf** into **Applications**.
3. Open ClipShelf from Applications. **The first launch is blocked** because this build is not notarized by Apple (it is ad-hoc signed, without a paid Developer ID). To allow it:
   - **macOS 15 Sequoia and later:** after the warning, open **System Settings → Privacy & Security**, scroll to Security, click **Open Anyway** next to ClipShelf, and confirm.
   - **macOS 12–14:** Control-click ClipShelf in Applications, choose **Open**, then **Open** again.
4. ClipShelf lives in the menu bar (no Dock icon). Press **⌥⌘V** or click its menu-bar icon.
5. For direct paste, allow ClipShelf in **System Settings → Privacy & Security → Accessibility**.

**Updating:** quit ClipShelf from its menu-bar menu, replace the app in Applications, and open it again. Because each unnotarized build has a new ad-hoc signature, macOS may treat it as a different app: if direct paste stops working, remove the old ClipShelf entry under Accessibility and allow it again.

The **Desktop Favorites widget** and **iCloud sync** need a Developer ID–signed build and are unavailable in these unnotarized releases. Everything else — history, shelf, snippets, pinboards, floating panel, direct paste, and screenshot copying — works.

To build the release DMG yourself, run `./scripts/package_unnotarized.sh`; it runs the checks, builds the universal app, and writes `dist/ClipShelf-<version>.dmg` plus its checksum. `./scripts/release_macos.sh` is the notarized path for a Developer ID account.

## Current status

Version 1.5.0 adds automatic screenshot copying and supports two local build paths. The ordinary ad-hoc build includes all clipboard/floating features but cannot claim a Team-ID App Group. The Personal Team build uses an Apple Development certificate and a macOS-only Team-ID group; a universal archive was built with a free Personal Team, both signatures/group entitlements were verified, and shared-folder access plus the Desktop Favorites switch were tested in the running app. No paid membership was used for that local build.

**iCloud remains disabled** until its own CloudKit provisioning is configured. Public Developer ID signing/notarization and two-Mac sync are still unverified. The user confirmed the desktop Favorites widget displays text and works after installation at a single stable app path.

`preview.png` renders the real Flutter interface with sample history, not private user data.

## Menu dismissal fix in 1.4.1

The native outside-click monitor now checks whether the pointer is inside the panel, its child windows, or its menu-bar icon. An in-panel click reported by the global monitor no longer closes it. App focus notifications are checked after AppKit completes focus transfer, and notifications from an older panel session cannot hide a newly opened one. Actual outside clicks still dismiss transient views; pinned floating mode remains visible.

Native hide events now clear Flutter popup-menu routes, and opening a panel clears any stale menu left from an earlier session. Preferences and editor dialogs are preserved. Regression checks repeat the More menu cycle four times, cover collection-menu reopening, and preserve Preferences through a hide/reopen. Native pointer/focus policy checks cover inside/outside clicks and floating pin behavior. Interactive verification is still required because native UI inspection timed out in this environment.

## Use

Quit any earlier ClipShelf instance before opening the new build, since macOS may otherwise reuse the already-running app. ClipShelf runs as a menu-bar agent (`LSUIElement = true`), so it does not appear in the Dock or ⌘Tab switcher. Use its menu-bar icon or ⌥⌘V to open it, and its menu-bar menu to quit. If an old icon was pinned with Keep in Dock, remove that pinned shortcut separately.

- Copy text, images, rich text, or file references in another app. ClipShelf starts with the next clipboard change rather than importing the clipboard at launch.
- Click the menu-bar clipboard icon to open a compact, searchable history list below that icon. **Click a row to paste directly into the previously active app.** The trailing icon is a separate **Copy** button that only copies the item. Without Accessibility access it copies the item and explains how to enable direct paste.
- In the compact panel, **⌘1–⌘9** and Return also request direct paste. Its collection menu includes snippets and pinboards. Right-click a row for copy-only, plain-text copying, previews, and item actions. Use **Open full shelf** for the larger interface. Click the menu-bar icon again, press Escape, or switch apps to dismiss it.
- Right-click the menu-bar icon for Open Shelf, Open floating panel, Pause/Resume, and Quit. The compact panel's More menu also provides Quit and Clear History.
- Press **⌥⌘V** to open the full shelf near the bottom of the display containing the mouse pointer. It hides when you switch away.
- Click a card, press Return, or press **⌘1–⌘9** for one of the first nine results to paste by default. **Paste** is also the first context-menu action; **Copy to clipboard** remains a separate action.
- Grant ClipShelf access in **System Settings → Privacy & Security → Accessibility** using **Allow** in the panel or **Allow access** in Preferences. Permission is checked continuously, on panel focus, and before pasting. Once macOS reports access granted, the yellow banner disappears and Preferences shows a green check instead of an Allow button. Revoking access restores the warning and copy-only fallback.
- Use **New snippet** / **⌘N** for reusable text. The item menu can also save captured text as a snippet.
- Use the **+** beside the collection tabs / **⇧⌘N** to create a colored pinboard. Drag a card's content onto its tab, or choose **Pin to…** from the card menu.
- The card menu also offers preview, plain-text copying, unpinning, and deleting. Space opens a preview when the library has focus. **⌘F** searches; arrows move between cards when the library has focus; Escape hides the shelf.
- Clicking outside dismisses the visible ClipShelf window, including the first window after launch. This hides the UI while capture continues; it does not quit the process. Clicks inside the panel, its child sheets, and the menu-bar button remain interactive.
- Pause capture from the toolbar or menu bar. Quit from the menu-bar menu. Closing or hiding the shelf keeps monitoring running.

Both views use a non-activating NSPanel with fullscreen auxiliary / all-Spaces behavior. Opening a view does not activate ClipShelf or switch the active app. Outside clicks, application changes, and Space changes dismiss it. Pasting only reactivates the target if it is no longer active.

The global shortcut is fixed in this version. If registration fails, use the menu bar. There is no login-launch control, app exclusion list, OCR, multi-select paste, paste stack, snippet editing, cross-platform sync, team sharing, or automatic updater yet.

## Automatic screenshot copying (1.5.0)

While ClipShelf is running, normal macOS screenshots saved with **⌘⇧3**, **⌘⇧4**, or the Screenshot toolbar are copied automatically to the clipboard and added as image history. The original saved file stays in place. Screenshots taken directly to the clipboard with Control continue through the normal clipboard capture path.

The **Automatically copy screenshots** switch in Preferences is on by default. ClipShelf watches the configured macOS screenshot save folder (Desktop by default). If access is unavailable, use **Choose screenshot folder** and select the actual save location; macOS may ask for Desktop access. **Use macOS screenshot location** follows the system setting again. Selecting a folder in ClipShelf does not change where macOS saves screenshots.

Only newly saved images with macOS's screenshot metadata are imported. Existing files and ordinary images are ignored. Pause also pauses screenshot import, and resuming does not backfill missed screenshots. Files must finish saving and fit the 10 MB image limit; decoding is limited to 64 million pixels. A clipboard copy made after file detection is preserved while the screenshot still enters history. Screenshots sent only to another app, without a saved file or clipboard image, cannot be discovered by this folder watcher.

For faster copying, open macOS Screenshot with **⌘⇧5**, then **Options → Show Floating Thumbnail** and turn that option off. The thumbnail normally holds the screenshot for a few seconds before saving. ClipShelf can import once the file exists and finishes writing; it does not read the thumbnail before macOS saves it.

This feature reads saved files and does not request Screen Recording permission. The app must stay running. The desktop Favorites widget continues to show saved text favorites.

## Build and test

Requires macOS 12+, Flutter stable, Xcode, and the macOS build tools. Developed with Flutter 3.47.8 / Dart 3.13.7. The current binary contains arm64 and x86_64; Intel runtime testing is still required if you distribute it. Future Flutter releases may change Intel support.

```sh
flutter pub get
flutter run -d macos
flutter analyze
flutter test
./scripts/build_macos.sh
./scripts/test_native.sh
```

The local app is at `build/macos/Build/Products/Release/ClipShelf.app`. The build script configures Flutter, builds through Xcode's project entry point, and ad-hoc signs/verifies the result. The workspace entry point failed in the restricted development environment. Swift Package Manager is disabled because there are no native plugin dependencies and nested manifest sandboxing was unavailable.

Regenerate the sample UI rendering on macOS with:

```sh
flutter test --update-goldens tool/preview_test.dart
flutter test --update-goldens --dart-define=QUICK_PREVIEW=true tool/preview_test.dart
```

## Floating mini-panel and desktop Favorites

Open the **floating panel** from the menu-bar icon's right-click menu, the quick panel's More menu, or Preferences. Drag the heading, resize an edge, and use the pin button to toggle **Keep visible**. Position, size, and pin preference are saved on this Mac. With Keep visible on, outside clicks and pasting leave the panel available. Turn it off to dismiss on outside click. Escape and Close always hide it. While visible, clicking the menu-bar icon brings it forward. The full shelf, quick panel, and floating panel share one window and the same Riverpod library, so opening the full shelf replaces the floating view.

**Desktop Favorites** requires macOS 14 or later and an App Group-enabled signed build. In that build, enable Desktop Favorites in Preferences, then use macOS **Edit Widgets → ClipShelf Favorites**. Add a small (up to 3 favorites) or medium (up to 6) widget to the desktop or Notification Center. Edit Widget selects Snippets or an existing pinboard and optionally shows text previews. Titles remain visible when previews are off; choose suitable snippet names.

Clicking a widget favorite **copies** its full text without opening ClipShelf. Paste it in your app with ⌘V. The header opens the floating panel; Open history opens the shelf. Direct paste is available from the floating panel. WidgetKit controls refresh timing; host changes request a refresh, with a periodic fallback rather than an instant-update guarantee.

Sharing is off by default. Only saved **text** snippets and text pinned to existing boards are exported to the local App Group. History, images, files, and original rich-format payloads are excluded. Each collection exports its first six eligible items in library order; text over 8 KiB stays in ClipShelf and is never silently truncated for copying. The shared snapshot has a 2 MB total budget; overflow entries stay in the app. Labels may be shortened for display. Disabling sharing replaces the shared snapshot with an empty one; copy actions re-read it, so stale widget buttons cannot copy a removed favorite. A cached widget display may remain briefly until WidgetKit refreshes. iCloud and Desktop Favorites are separate opt-ins.

See [widget signing and validation](docs/WIDGETS.md) for the remaining owner setup. The ordinary ad-hoc build includes the extension but cannot establish the authorized shared container. For free local testing, use the Personal Team workflow in that guide. The Preferences switch now checks real shared-folder read/write access, and the widget distinguishes missing signing setup from sharing being off. Floating-panel functionality is independent of signing setup.

## iCloud between Macs

The sync layer uses the **current Apple Account's private CloudKit database**, not an app-operated server. Each clip and pinboard has its own record. Versions and deletion tombstones persist locally, allowing offline changes to retry later without replacing another Mac's whole archive. Conflicting changes to the same item use the later timestamp, with deterministic ties; a deletion wins an exact-time tie. Keep system clocks accurate.

Sync is opt-in. Enabling it explicitly confirms that existing history, snippets, and pinboards will upload. Small metadata queries run about every 30 seconds while the app is running, with debounced uploads after local changes and a manual **Sync now** action. Asset payloads download only for changed/new items. CloudKit throttling backoff is respected. This is eventual sync, not an instant-transfer guarantee. The app must be running to participate.

An Apple Account change stops sync and requires another explicit enable action, reducing accidental uploads to a different account. Disabling sync retains local and previously uploaded data. Explicit item deletions and clearing history propagate through tombstones; saved snippets and pinned items survive Clear History. Local capacity eviction does not delete older cloud history. Tombstones retain identifiers/version metadata, not the deleted payload. CloudKit/iCloud backups and server retention are outside the app's control.

File references sync as references: the original file contents do not upload, and a path on one Mac may not exist on another. There is no app-level end-to-end encryption claim. CloudKit's platform protections apply; local history is not encrypted by the app.

### Provision an iCloud release when ready

1. Join the Apple Developer Program. Choose a unique bundle identifier in `macos/Runner/Configs/AppInfo.xcconfig` and create its explicit App ID.
2. Enable **iCloud / CloudKit** for that App ID, create a container such as `iCloud.your.company.ClipShelf`, and associate it with the App ID.
3. In CloudKit Console, create record type **ClipShelfEntity** with **stamp** (Bytes) and **payload** (Asset). Make **recordName** / the system record ID queryable so the type can be enumerated with a true predicate. Deploy the schema to Production. The app uses a private custom zone named **ClipShelf**; the app creates this zone.
4. Create/install a **Developer ID Application** signing certificate and an explicit **Developer ID provisioning profile** authorizing the bundle ID, Production CloudKit, and that container. The profile must not permit debugging. Put the profile somewhere outside source control.
5. Store notarization credentials locally with `xcrun notarytool store-credentials`; do not send or commit passwords/private keys.
6. Run:

```sh
ICLOUD_CONTAINER_IDENTIFIER='iCloud.your.company.ClipShelf' \
ICLOUD_PROVISIONING_PROFILE='/absolute/path/ClipShelf.provisionprofile' \
DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-keychain-profile' \
./scripts/release_macos.sh
```

The release script runs checks, builds, validates the profile's App ID/container/services/environment, embeds the profile, and signs with production entitlements derived from it. It signs frameworks explicitly, notarizes/staples the app, builds a DMG, signs/notarizes/staples it, and writes its checksum under `dist/`. It uploads signed artifacts to Apple's notarization service. This flow has not been run with real owner credentials.

For a local-only public release, omit the two `ICLOUD_…` variables; Developer ID signing and notarization are still needed. The bundled ad-hoc test app is not a trusted public download, and Gatekeeper may block downloaded copies. An ad-hoc update can also change the identity macOS uses for Accessibility authorization. Install the new app at a stable path, quit earlier running copies, and if access still appears denied, remove the older ClipShelf entry in Accessibility and authorize the installed build. The banner follows the running process’s actual permission, not whether the Allow button was clicked. A Mac App Store build needs a separate sandbox/permission review.

## Local storage and capture limits

History is stored at `~/Library/Application Support/ClipShelf/history.json` with owner-only permissions. Version 1 history files migrate without discarding their clips. Corrupt files are backed up and capture paused; if backup fails, writes are disabled to preserve the original.

Capture polls `NSPasteboard.changeCount` every 650 ms. It preserves materialized pasteboard representations, including HTML/RTF and original image bytes, with small image previews. File promises are omitted because their providers may not remain available. Provider-specific formats can depend on the source application. Rich content is previewed as text/images rather than executed. Rapidly overwritten copies between polling intervals may be missed.

Copies marked concealed, transient, or autogenerated, and the OnePassword marker, are skipped. This is best effort: unmarked passwords/secrets can still be captured. Pause before copying sensitive data. Copies made while paused are not imported on resume.

Captured history keeps up to 200 local items within a 100 MB combined raw-payload budget, evicting the oldest unsaved items. Copies over 10 MB are skipped. New saved items are limited to 500 entries / 50 MB, with text snippets under 1 MB. Saved content received from other Macs is preserved even if aggregate saved content exceeds the new-item limit. JSON/base64 encoding, image previews, and version metadata add disk overhead. Duplicate captured payloads move to the front. System backups may retain older data.

## Verification and remaining checks

Flutter analysis, 36 unit/widget tests, the native logic suite, the universal release build, and ad-hoc signature verification have been exercised. Controller tests cover initial loading, out-of-order reads, native updates during loading/refresh, failure recovery, lifecycle cleanup, typed actions, filtering/selection, and immutable data. The shelf and quick-panel previews remain covered; a floating preview was added. Small and medium SwiftUI widget layouts were rendered with sample content (link labels are substituted only in preview builds because ImageRenderer cannot render system Links). Widget checks include row/numbered default paste, the side Copy button, the Paste-first context menu, live permission grant/revocation, updating an already-open Preferences dialog, switching to the shelf, drag-to-pin, compact layout, snippet validation, and explicit sync consent. Native permission checks verify that grants and revocations push UI updates even without clipboard changes, and unchanged permission does not repeatedly publish history. Native geometry checks cover screen-edge placement, short displays, and secondary displays with negative coordinates. Native checks cover HTML/image/multi-item restoration, persistence, saved-item retention, archive migration, merging offline additions, and preventing deleted records from returning after stale updates/restarts.

New native checks cover floating dismissal policy and saved geometry, widget export exclusions, exact Unicode text, size limits, unchanged snapshots, feedback expiry, and clearing shared data when disabled. The widget extension compiles for both Mac architectures and is embedded and ad-hoc signed. Personal Team signing and host shared-container read/write access were verified in 1.4.2. The user subsequently confirmed widget discovery, text display, and operation after a clean installation; see docs/VALIDATION-1.4.2.md for the original signing checks.

The environment denied an isolated real pasteboard write, so the native suite uses an in-memory boundary by default. `./scripts/test_native.sh --system-pasteboard` exercises a unique named macOS pasteboard without touching the user's clipboard; run this outside the restricted environment. Native UI automation still times out inspecting ClipShelf, so the fullscreen/Spaces fix is compiled but not verified interactively here. Test actual OS capture/restore, hotkey conflicts, multiple displays/Spaces, returning focus, Accessibility grant/deny/revoke, and clean-Mac Gatekeeper behavior interactively.

After provisioning, use two Macs on the same Apple Account to verify initial sync, text/images/pinboards, offline edits, concurrent pinning/deleting, network interruptions, account changes, quota errors, and restart recovery. Live CloudKit transfer is not yet verified.

## Structure

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

## References

- [Paste's Mac workflow](https://pasteapp.io/help/paste-on-mac)
- [Flutter macOS build and distribution](https://docs.flutter.dev/platform-integration/macos/building)
- [Apple iCloud capability configuration](https://developer.apple.com/documentation/xcode/configuring-icloud-services/)
- [Apple NSPasteboard changeCount](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)

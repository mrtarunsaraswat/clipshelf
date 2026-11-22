# Desktop Favorites setup

The widget and the app share a small favorites snapshot through a folder both can reach:

- **Ad-hoc / unpaid builds (the public download):** `~/Library/Application Support/ClipShelf/Widget/`. The host app isn't sandboxed and writes it directly; the sandboxed widget reaches only that folder through a `temporary-exception.files.home-relative-path.read-write` entitlement in `macos/ClipShelfWidgets/Widget.entitlements`. This needs no Apple account and is confirmed working with an ad-hoc build installed in /Applications. The exception is not allowed on the Mac App Store.
- **Team-signed builds:** if the build has an authorized App Group (Personal Team or Developer ID, below), that container is used instead.

The rest of this guide covers the App Group paths. A paid membership is not required for the macOS-only local path below. In 1.4.2, a free Personal Team archive was built and its signatures/group entitlements verified; the running app successfully accessed the shared folder and enabled Desktop Favorites. Widget display/copy still needs a live favorite check.

## Free local testing on this Mac

1. Add your regular Apple Account in **Xcode → Settings → Apple Accounts**. Select your Personal Team and ensure **Manage Certificates** lists an Apple Development certificate. Its computer-name label is not necessarily your Team ID.
2. From the project root, configure the actual signing Team ID (10 characters):

```sh
python3 scripts/configure_widget_xcode.py YOURTEAMID
flutter pub get
flutter build macos --release --config-only
```

The script creates ignored `macos/Runner/Configs/LocalWidgetSigning.xcconfig` and a neighboring `LocalWidgetSigning/` entitlement directory. It uses `YOURTEAMID.clipshelf`, a macOS-specific group that requires the matching code-signing team, not a registered `group.*` identifier/profile. No private keys are exported or written to the project. Keep these device-local files out of source archives.

3. Open `macos/Runner.xcodeproj` in Xcode. The host and widget should resolve the same Personal Team, Apple Development identity and local entitlements. Use **Product → Archive** for a universal release build. Xcode signs through your Keychain. Handle any Keychain password prompt directly on your Mac.
4. In Organizer, locate the archive's `Products/Applications/ClipShelf.app`. Quit older ClipShelf instances, then run this signed app from a stable location. Enable **Desktop Favorites widget** in Preferences. The toggle remains disabled if real shared-folder access fails.
5. Create a text snippet or pin text to a board, add/re-add **ClipShelf Favorites** using macOS Edit Widgets, and choose that collection. A stale widget from a differently signed ad-hoc build may need to be removed and added again.

If your own Terminal can access the development signing identity, this alternative builds and signs without Xcode UI:

```sh
LOCAL_TEAM_ID='YOURTEAMID' \
LOCAL_SIGNING_IDENTITY='Apple Development: Your Name (IDENTIFIER)' \
bash scripts/build_widget_local.sh
```

The script verifies the actual signer on both bundles and keeps CloudKit off. A command-line environment that cannot access your Keychain may report no valid identities even when Xcode lists the certificate; use Xcode's normal archive workflow in that case. Personal Team development signing is for local testing; it is not Developer ID distribution/notarization, and certificate validity still applies. iCloud is separate and is not enabled by this setup.

Apple documents this macOS-only group format in [Accessing app group containers](https://developer.apple.com/documentation/xcode/accessing-app-group-containers). This route does not apply to iOS widgets.

## Developer ID distribution setup

1. Enroll in Apple Developer Program and choose your permanent host bundle identifier in `macos/Runner/Configs/AppInfo.xcconfig` (`CLIPSHELF_HOST_BUNDLE_ID`). The widget identifier is the host identifier plus `.widgets`.
2. Register explicit identifiers for both the host and widget. Register an App Group such as `group.your.company.clipshelf` and authorize the same group for both identifiers. The widget does not need CloudKit capability; the host only needs it if iCloud sync is desired.
3. Create matching **Developer ID distribution provisioning profiles** for the host and extension, authorizing that group. Use the same team and Developer ID Application certificate. Keep profiles and keys outside the repository.
4. Store notarization credentials in Keychain. Run:

```sh
WIDGET_APP_GROUP_ID='group.your.company.clipshelf' \
HOST_PROVISIONING_PROFILE='/absolute/path/ClipShelf.provisionprofile' \
WIDGET_PROVISIONING_PROFILE='/absolute/path/ClipShelfWidgets.provisionprofile' \
DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-keychain-profile' \
./scripts/release_macos.sh
```

For iCloud as well, add `ICLOUD_CONTAINER_IDENTIFIER` and authorize Production CloudKit in the **host** profile, following the README. `ICLOUD_PROVISIONING_PROFILE` is retained as an alias for `HOST_PROVISIONING_PROFILE`. The release script checks explicit bundle IDs, expiry, team agreement, App Group authorization, and CloudKit environment where requested. It signs the embedded extension before the host. The script uploads the signed app/DMG to Apple's notarization service.

An App Group string passed to the ordinary ad-hoc build script alone does not grant permission. Use the signed Personal Team path for local Mac tests, or the provisioned Developer ID path for distribution. Widget sharing is off by default and requires explicit enablement.

## Enable and use

Install the signed build at a stable path, launch it, and enable **Desktop Favorites widget** in Preferences. Save text snippets or pin text to a board. On macOS 14+, choose **Edit Widgets**, find **ClipShelf Favorites**, and add a small or medium widget. Edit Widget selects the collection and preview preference. Click a favorite to copy, then ⌘V in the destination app. Open history and the header shortcut open the existing app window.

The widget is a view of the same local library. There is no second favorites database to edit. Images/files and unsaved history never enter its shared snapshot. Up to 12 text entries per collection, at most 8 KiB of UTF-8 text each, are available. Small shows 3, Medium 6 and Large 12; with previews enabled they show 2, 4 and 8 to keep text legible. The header shows the app icon, the collection's name and, for a pinboard, its colour (tiles take the same tint). The ⏸ / ▶ button pauses or resumes clipboard capture: the widget leaves a request in the shared folder and ClipShelf applies it within about a second (requests older than two minutes, e.g. while ClipShelf wasn't running, are ignored). While paused the widget says *Capture paused*. Long text remains accessible in the app. The shared snapshot has a 2 MB total budget; overflow entries stay in the app. Text is copied exactly; titles may be shortened. Previews are off by default, but titles are visible.

## Remaining live widget checks

- Confirm widget discovery after installing/launching the notarized app, including a clean Mac.
- Add both sizes to desktop and Notification Center; test light/dark and full-color/tinted appearances.
- Choose each pinboard, toggle previews, and verify deleted boards show the empty state rather than another collection.
- Click Copy with ClipShelf running and stopped; confirm the exact Unicode/multiline text and no unwanted host activation.
- Open both links with the host running and cold, including another app in fullscreen.
- Edit/delete/pin favorites, disable sharing, and verify refresh and that stale buttons cannot copy removed content. OS refresh scheduling can delay a visual update.
- Test missing/unavailable App Group storage and a removed favorite during a copy action.
- Confirm the widget copy feedback expires and small/medium layouts fit on supported OS versions.

Local verification now also includes a Personal Team-signed universal archive and a live host shared-folder/Preferences enablement check. It does not yet establish live WidgetKit display or AppIntent pasteboard behavior.

## Reproduce sample previews

```sh
flutter test tool/preview_test.dart --update-goldens \
  --dart-define=FLOATING_PREVIEW=true --dart-define=ACCESSIBILITY_PREVIEW=true
swiftc -parse-as-library -DCLIPSHELF_WIDGET_PREVIEW \
  -module-cache-path build/native-tests/module-cache \
  macos/Shared/WidgetFavorites.swift macos/ClipShelfWidgets/ClipShelfWidgets.swift \
  tool/render_widget_preview.swift -o build/native-tests/render-widget
build/native-tests/render-widget   # run from the repository root; writes screenshots/widget-*.png
```

The SwiftUI tool uses the actual widget content with sample favorites; system Link labels are rendered statically only for this preview because ImageRenderer cannot draw Links. These are layout previews, not screenshots of a registered desktop widget.

Apple references: [WidgetKit extensions](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension), [interactive widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities), [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups).

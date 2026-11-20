# ClipShelf user guide

Everything about using ClipShelf day to day. For the quick version, see the [README](../README.md).

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

**iCloud sync** is coming soon; Preferences shows it as *Coming soon* in these releases. Everything else works, including the Desktop Favorites widget on macOS 14+. After an update you may need to remove and re-add the widget.

To build the release DMG yourself, run `./scripts/package_unnotarized.sh`; it runs the checks, builds the universal app, and writes `dist/ClipShelf-<version>.dmg` plus its checksum. `./scripts/release_macos.sh` is the notarized path for a Developer ID account.

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

## Automatic screenshot copying

While ClipShelf is running, normal macOS screenshots saved with **⌘⇧3**, **⌘⇧4**, or the Screenshot toolbar are copied automatically to the clipboard and added as image history. The original saved file stays in place. Screenshots taken directly to the clipboard with Control continue through the normal clipboard capture path.

The **Automatically copy screenshots** switch in Preferences is on by default. ClipShelf watches the configured macOS screenshot save folder (Desktop by default). If access is unavailable, use **Choose screenshot folder** and select the actual save location; macOS may ask for Desktop access. **Use macOS screenshot location** follows the system setting again. Selecting a folder in ClipShelf does not change where macOS saves screenshots.

Only newly saved images with macOS's screenshot metadata are imported. Existing files and ordinary images are ignored. Pause also pauses screenshot import, and resuming does not backfill missed screenshots. Files must finish saving and fit the 10 MB image limit; decoding is limited to 64 million pixels. A clipboard copy made after file detection is preserved while the screenshot still enters history. Screenshots sent only to another app, without a saved file or clipboard image, cannot be discovered by this folder watcher.

For faster copying, open macOS Screenshot with **⌘⇧5**, then **Options → Show Floating Thumbnail** and turn that option off. The thumbnail normally holds the screenshot for a few seconds before saving. ClipShelf can import once the file exists and finishes writing; it does not read the thumbnail before macOS saves it.

This feature reads saved files and does not request Screen Recording permission. The app must stay running. The desktop Favorites widget continues to show saved text favorites.

## Floating mini-panel and desktop Favorites

Open the **floating panel** from the menu-bar icon's right-click menu, the quick panel's More menu, or Preferences. Drag the heading, resize an edge, and use the pin button to toggle **Keep visible**. Position, size, and pin preference are saved on this Mac. With Keep visible on, outside clicks and pasting leave the panel available. Turn it off to dismiss on outside click. Escape and Close always hide it. While visible, clicking the menu-bar icon brings it forward. The full shelf, quick panel, and floating panel share one window and the same Riverpod library, so opening the full shelf replaces the floating view.

**Desktop Favorites** requires macOS 14 or later. Enable Desktop Favorites in Preferences, then use macOS **Edit Widgets → ClipShelf Favorites**. Add a small (up to 3 favorites) or medium (up to 6) widget to the desktop or Notification Center. Edit Widget selects Snippets or an existing pinboard and optionally shows text previews. Titles remain visible when previews are off; choose suitable snippet names.

Clicking a widget favorite **copies** its full text without opening ClipShelf. Paste it in your app with ⌘V. The header opens the floating panel; Open history opens the shelf. Direct paste is available from the floating panel. WidgetKit controls refresh timing; host changes request a refresh, with a periodic fallback rather than an instant-update guarantee.

Sharing is off by default. Only saved **text** snippets and text pinned to existing boards are exported to the widget's shared folder (the App Group in Team-signed builds, otherwise `~/Library/Application Support/ClipShelf/Widget/`). History, images, files, and original rich-format payloads are excluded. Each collection exports its first six eligible items in library order; text over 8 KiB stays in ClipShelf and is never silently truncated for copying. The shared snapshot has a 2 MB total budget; overflow entries stay in the app. Labels may be shortened for display. Disabling sharing replaces the shared snapshot with an empty one; copy actions re-read it, so stale widget buttons cannot copy a removed favorite. A cached widget display may remain briefly until WidgetKit refreshes. iCloud and Desktop Favorites are separate opt-ins.

The Preferences switch checks real read/write access to the shared folder. See [widget storage and signing](WIDGETS.md) for how the folder is chosen and for Team-signed builds.

## Local storage and capture limits

History is stored at `~/Library/Application Support/ClipShelf/history.json` with owner-only permissions. Version 1 history files migrate without discarding their clips. Corrupt files are backed up and capture paused; if backup fails, writes are disabled to preserve the original.

Capture polls `NSPasteboard.changeCount` every 650 ms. It preserves materialized pasteboard representations, including HTML/RTF and original image bytes, with small image previews. File promises are omitted because their providers may not remain available. Provider-specific formats can depend on the source application. Rich content is previewed as text/images rather than executed. Rapidly overwritten copies between polling intervals may be missed.

Copies marked concealed, transient, or autogenerated, and the OnePassword marker, are skipped. This is best effort: unmarked passwords/secrets can still be captured. Pause before copying sensitive data. Copies made while paused are not imported on resume.

Captured history follows **Preferences → History**: *History size* keeps 100, 200 (default), 500 or 1,000 items, with a storage budget that scales with it (200 items → 100 MB; 1,000 → 500 MB), evicting the oldest unsaved items first. *Keep history for* (Forever by default, or 1 day, 1 week, 1 month) removes older items automatically, also while ClipShelf is running. *Storage used* shows the current total. Copies over 10 MB are skipped. Snippets and pinned items are never removed by these settings; new saved items are limited to 500 entries / 50 MB, with text snippets under 1 MB. Saved content received from other Macs is preserved even if aggregate saved content exceeds the new-item limit. JSON/base64 encoding, image previews, and version metadata add disk overhead. Copying the same content again moves the existing item to the front instead of adding a duplicate. System backups may retain older data.

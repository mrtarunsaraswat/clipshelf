# Changelog

## 1.1.0 — 2026-11-20

A fresh look, smarter cards and search, and the desktop widget in the free download.

### New look
- **Liquid Glass** window on macOS 26, and a frosted glass window on earlier versions.
- **Dark mode** that follows macOS, using your system accent colour.
- **Redesigned cards, shelf, menu-bar panel, Preferences, and dialogs**, with the **Geist** typeface (bundled, so no font downloads).
- The **in-app logo** now matches the app icon.

### Cards and search
- **Richer cards:** the icon of the app you copied from, "N characters" for text, the pixel size for images, and the icon and path for files.
- **Link previews (opt-in):** Preferences → History → *Show link previews* shows the page's title and picture. Off by default; when on, ClipShelf contacts only that website, without cookies.
- **New-copy animation:** new copies slide in at the front; deleted items shrink away.
- **Smart search:** start typing to search, and add filters for type, date, or source app as chips.

### Desktop widget
- **Now works in the free download.** Builds without an App Group share favorites through `~/Library/Application Support/ClipShelf/Widget/`, using a sandbox exception scoped to that folder. Team-signed builds still use their App Group.
- A **Large** size (up to 12 favorites), a **Pause / Resume** button, the app icon in the header, pinboard colours, and a **Copied** state after a click.

### More
- **History settings:** Preferences → History adds *Keep history for* (Forever, 1 day, 1 week, 1 month) and *History size* (100–1,000 items), with a storage-used meter.
- **⌘1–⌘9 work while searching** in the menu-bar panel, which also gets a **New snippet** button.
- **No more duplicates from repeat ⌘C** in VS Code and other Chromium apps; repeat copies move the existing item to the front.
- **iCloud sync is marked Coming soon** in Preferences for builds without CloudKit provisioning.

### Fixes
- Closing the shelf after opening it from the widget no longer leaves a ghosted, shifted window behind.
- Preferences no longer flickers when the panel reopens.

## 1.0.0 — 2026-11-19

First public release.

- Menu-bar clipboard history with search and direct paste (⌘1–⌘9)
- Bottom-of-screen shelf (⌥⌘V), snippets, and colored pinboards
- Floating mini-panel that can stay visible
- Automatic screenshot copying
- Universal (Apple Silicon + Intel) unnotarized DMG; see the [install steps](README.md#install)
- Builds on Flutter 3.50; GitHub Actions CI builds and tests every change

Desktop Favorites widget and iCloud sync needed a Developer ID–signed build and were not included in the 1.0.0 download.

## Development history (before 1.0.0)

Internal builds 1.4.0–1.5.0 were renumbered to 1.0.0 for the first public release. Detailed validation notes for those builds are in [docs/](docs/).

### State at 1.5.0

Version 1.5.0 adds automatic screenshot copying and supports two local build paths. The ordinary ad-hoc build includes all clipboard/floating features but cannot claim a Team-ID App Group. The Personal Team build uses an Apple Development certificate and a macOS-only Team-ID group; a universal archive was built with a free Personal Team, both signatures/group entitlements were verified, and shared-folder access plus the Desktop Favorites switch were tested in the running app. No paid membership was used for that local build.

**iCloud remains disabled** until its own CloudKit provisioning is configured. Public Developer ID signing/notarization and two-Mac sync are still unverified. The user confirmed the desktop Favorites widget displays text and works after installation at a single stable app path.

`preview.png` (in the repository root) renders the real Flutter interface with sample history, not private user data.

### Menu dismissal fix (1.4.1)

The native outside-click monitor now checks whether the pointer is inside the panel, its child windows, or its menu-bar icon. An in-panel click reported by the global monitor no longer closes it. App focus notifications are checked after AppKit completes focus transfer, and notifications from an older panel session cannot hide a newly opened one. Actual outside clicks still dismiss transient views; pinned floating mode remains visible.

Native hide events now clear Flutter popup-menu routes, and opening a panel clears any stale menu left from an earlier session. Preferences and editor dialogs are preserved. Regression checks repeat the More menu cycle four times, cover collection-menu reopening, and preserve Preferences through a hide/reopen. Native pointer/focus policy checks cover inside/outside clicks and floating pin behavior. Interactive verification is still required because native UI inspection timed out in this environment.

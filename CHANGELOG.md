# Changelog

## Unreleased

- **iCloud sync is marked Coming soon** in Preferences for builds without CloudKit provisioning.
- **Desktop Favorites widget now works in the free download.** Builds without an App Group share favorites through `~/Library/Application Support/ClipShelf/Widget/`, using a sandbox exception scoped to that folder. Team-signed builds still use their App Group.

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

# ClipShelf 1.4.0 validation

Local verification on November 18, 2026:

- Flutter analyzer: no issues.
- Flutter unit/widget suite: 30 tests passed.
- Shelf, quick-panel and floating sample golden checks passed.
- Native suite passed with an in-memory pasteboard, including floating dismissal/preferences/geometry and Favorites export, exact Unicode copying, size budgets, corruption handling, stale lookup and disabling sharing.
- Signing validation: 7 checks passed using fictional profiles, with no credentials/network.
- Release host and embedded WidgetKit extension built for arm64 and x86_64; embedded-extension validation and ad-hoc signature verification passed.
- Small/medium SwiftUI widget layouts rendered with previews off/on. These use sample favorites, and preview compilation substitutes system Link labels for ImageRenderer. They are not live desktop screenshots.

Live OS validation remains pending for floating-panel drag/resize/focus/paste and fullscreen/Spaces behavior. The native UI automation available in this environment has previously timed out. No successful interactive claim is made from the compiled build or fake-pasteboard tests.

Widget discovery, App Group access, AppIntent pasteboard writes, real widget links, clean-Mac installation, and notarization require owner Developer ID provisioning. The extension and release setup are included; Desktop Favorites sharing is disabled in the local ad-hoc build. iCloud also remains disabled until owner provisioning and two-Mac validation.

Quit any earlier ClipShelf instance before opening the updated local test app. Existing archive storage is preserved. See README and WIDGETS.md for use, limits, and signing setup.

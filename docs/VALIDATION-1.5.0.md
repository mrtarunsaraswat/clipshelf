# ClipShelf 1.5.0 validation

## Automated and build checks

- Flutter analysis: passed.
- Flutter tests: all 36 passed.
- Native logic and isolated directory event checks: all 105 passed.
- Universal Release archive: succeeded for Apple Silicon and Intel.
- Host and embedded widget signatures: strict/deep verification passed, matching existing Apple Development team and shared App Group.
- Installed at the existing `/Applications/ClipShelf.app` path, preserving library/preferences. The previous version was archived outside app discovery. Build products were retained in a `.noindex` directory; distributable output is ZIP only.

Screenshot checks cover: baseline/no historical imports, incomplete writes, late metadata, stable-file detection, symlink exclusion, ordinary image exclusion, decode/size limits, original-file preservation, screenshot/clipboard duplicate suppression, pause/disable, newer clipboard copy preservation, chronological insertion, and an actual directory event delivering a marked image once. Flutter controls follow native status updates and issue typed repository commands.

## Interactive validation

The installed 1.5.0 app launched successfully with its existing history. Further accessibility inspection of the transient panel timed out. The user then took a normal screenshot and confirmed it appeared automatically after saving. Desktop access may need to be granted to ClipShelf, or the save folder selected in Preferences. The automated suite uses an isolated marked fixture file and an in-memory pasteboard boundary; the normal screenshot check was confirmed separately by the user.

CloudKit, production Developer ID signing/notarization, and Intel runtime checks remain outside this local update's validation.

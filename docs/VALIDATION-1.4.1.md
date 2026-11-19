# ClipShelf 1.4.1 — popup menu dismissal

The supplied recording was inspected using locally extracted frames. It shows the panel hiding on a menu-button click and revealing the already-open menu after reopening. No recording data was uploaded.

Changes:

- Global mouse events are classified by screen position instead of automatically dismissing the panel. The panel, owned child windows and status button count as inside.
- App activation/resignation handling defers until key focus settles. Own-panel focus keeps it visible, and a generation counter prevents an older deferred notification hiding a newly opened session.
- A native `closed` event updates the Riverpod panel session. Flutter transient menu routes are removed on close and on open. Preferences/editor dialogs are retained, and deferred focus effects check session sequence.
- Outside-click/Space dismissal and pinned floating behavior remain supported.

Verification:

- Flutter analyzer: no issues.
- 34 Flutter unit/widget tests passed. New cases cover four consecutive More-menu cycles, stale collection-menu cleanup on reopening, Preferences retention, and close-event state/lifecycle behavior.
- 70 native assertions passed, including in-panel/global click geometry, genuine outside clicks, child/status regions, focus policy and floating pin state. Native tests use an in-memory pasteboard.
- Shelf, quick-panel and floating preview baselines passed unchanged.
- Universal arm64/x86_64 release host and widget built; ad-hoc deep/strict signature verification passed.
- Both archive versions are 1.4.1 (build 9).

Native UI inspection timed out, so the physical click sequence could not be replayed interactively in this environment. The regression tests validate state and dismissal policy, not actual OS event delivery. Quit the running 1.4.0 instance before testing 1.4.1, then open/close More repeatedly and confirm outside clicks still dismiss. Test fullscreen/Spaces and both floating pin states as well.

Widget App Group/iCloud signing limitations are unchanged; see WIDGETS.md and README.

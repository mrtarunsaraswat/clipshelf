import 'dart:async';

import 'package:clipshelf/features/clipboard/domain/clipboard_repository.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_snapshot.dart';
import 'package:clipshelf/features/pinboards/domain/pinboard_draft.dart';
import 'package:clipshelf/features/snippets/domain/snippet_draft.dart';

class FakeClipboardRepository implements ClipboardRepository {
  FakeClipboardRepository(this.snapshot) {
    changes = StreamController<ClipboardEvent>.broadcast(
      sync: true,
      onListen: () => listeners++,
      onCancel: () => listeners--,
    );
  }
  ClipboardSnapshot snapshot;
  late final StreamController<ClipboardEvent> changes;
  int listeners = 0, reads = 0;
  Future<ClipboardSnapshot> Function()? read;
  ClipboardFailure? restoreFailure;
  final restores = <({String id, bool paste, bool plain})>[];
  final snippets = <SnippetDraft>[];
  final pinboards = <PinboardDraft>[];
  final pins = <({String id, String boardID})>[];
  final operations = <String>[];
  @override
  Stream<ClipboardEvent> get events => changes.stream;
  void emit(ClipboardSnapshot value) {
    snapshot = value;
    changes.add(SnapshotChanged(value));
  }

  void opened(PanelPresentation presentation) =>
      changes.add(PanelOpened(presentation));
  @override
  Future<ClipboardSnapshot> readSnapshot() {
    reads++;
    return read?.call() ?? Future.value(snapshot);
  }

  @override
  Future<String?> restoreItem(
    String id, {
    required bool paste,
    bool plain = false,
  }) async {
    if (restoreFailure != null) throw restoreFailure!;
    restores.add((id: id, paste: paste, plain: plain));
    return paste ? 'Pasting' : 'Copied';
  }

  @override
  Future<void> createSnippet(SnippetDraft draft) async {
    snippets.add(draft);
  }

  @override
  Future<void> createPinboard(PinboardDraft draft) async {
    pinboards.add(draft);
  }

  @override
  Future<void> pinItem(String id, String boardID) async {
    pins.add((id: id, boardID: boardID));
  }

  @override
  Future<void> deleteItem(String id) async {
    operations.add('delete:$id');
  }

  @override
  Future<void> clearHistory() async {
    operations.add('clear');
  }

  @override
  Future<void> toggleCapture() async {
    operations.add('pause');
  }

  @override
  Future<bool> requestAccessibility() async {
    operations.add('accessibility');
    return snapshot.accessibility;
  }

  @override
  Future<void> setSyncEnabled(bool enabled) async {
    operations.add('sync:$enabled');
  }

  @override
  Future<void> syncNow() async {
    operations.add('syncNow');
  }

  @override
  Future<void> showFloating() async {
    operations.add('showFloating');
  }

  @override
  Future<void> setFloatingPinned(bool value) async {
    operations.add('floatingPinned:$value');
  }

  @override
  Future<void> dragFloating() async {}
  @override
  Future<void> setWidgetSharing(bool value) async {
    operations.add('widgetSharing:$value');
  }

  @override
  Future<void> setScreenshotCopying(bool value) async {
    operations.add('screenshots:$value');
  }

  @override
  Future<void> chooseScreenshotFolder() async {
    operations.add('screenshotFolder');
  }

  @override
  Future<void> useSystemScreenshotFolder() async {
    operations.add('systemScreenshotFolder');
  }

  @override
  Future<void> showShelf() async {
    operations.add('showShelf');
  }

  @override
  Future<void> hide() async {
    operations.add('hide');
  }

  @override
  Future<void> quit() async {
    operations.add('quit');
  }

  Future<void> dispose() => changes.close();
}

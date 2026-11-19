import 'clipboard_snapshot.dart';
import '../../pinboards/domain/pinboard_draft.dart';
import '../../snippets/domain/snippet_draft.dart';

class ClipboardFailure implements Exception {
  const ClipboardFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Platform-independent contract, overridden with a fake in controller tests.
abstract interface class ClipboardRepository {
  Stream<ClipboardEvent> get events;
  Future<ClipboardSnapshot> readSnapshot();
  Future<String?> restoreItem(
    String id, {
    required bool paste,
    bool plain = false,
  });
  Future<void> createSnippet(SnippetDraft draft);
  Future<void> createPinboard(PinboardDraft draft);
  Future<void> pinItem(String id, String boardID);
  Future<void> deleteItem(String id);
  Future<void> clearHistory();
  Future<void> toggleCapture();
  Future<bool> requestAccessibility();
  Future<void> setSyncEnabled(bool enabled);
  Future<void> syncNow();
  Future<void> showFloating();
  Future<void> setFloatingPinned(bool value);
  Future<void> dragFloating();
  Future<void> setWidgetSharing(bool value);
  Future<void> setScreenshotCopying(bool value);
  Future<void> chooseScreenshotFolder();
  Future<void> useSystemScreenshotFolder();
  Future<void> showShelf();
  Future<void> hide();
  Future<void> quit();
}

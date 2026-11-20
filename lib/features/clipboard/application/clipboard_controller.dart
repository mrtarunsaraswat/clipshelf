import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/method_channel_clipboard_repository.dart';
import '../domain/clipboard_repository.dart';
import '../domain/clipboard_snapshot.dart';
import '../../pinboards/domain/pinboard_draft.dart';
import '../../snippets/domain/snippet_draft.dart';
import 'panel_session.dart';

final clipboardRepositoryProvider = Provider<ClipboardRepository>((ref) {
  final repository = MethodChannelClipboardRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final clipboardControllerProvider =
    AsyncNotifierProvider<ClipboardController, ClipboardSnapshot>(
      ClipboardController.new,
      retry: (count, error) => null,
    );

class ClipboardController extends AsyncNotifier<ClipboardSnapshot> {
  int _revision = 0, _refreshRequest = 0;
  @override
  Future<ClipboardSnapshot> build() async {
    final repository = ref.watch(clipboardRepositoryProvider);
    ClipboardSnapshot? latest;
    bool ready = false, openedWhileLoading = false;
    final subscription = repository.events.listen(
      (event) {
        if (!ref.mounted) return;
        switch (event) {
          case SnapshotChanged(:final snapshot):
            latest = snapshot;
            _revision++;
            if (ready) state = AsyncData(snapshot);
          case PanelClosed():
            ref.read(panelSessionProvider.notifier).closed();
          case QuickUseRequested(:final index):
            ref.read(quickUseRequestProvider.notifier).request(index);
          case PanelOpened(:final presentation):
            ref.read(panelSessionProvider.notifier).opened(presentation);
            if (ready) {
              unawaited(refresh());
            } else {
              openedWhileLoading = true;
            }
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!ref.mounted || !ready) return;
        _setFailure(error, stack);
      },
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
    try {
      var initial = await repository.readSnapshot();
      if (openedWhileLoading && latest == null && ref.mounted) {
        initial = await repository.readSnapshot();
      }
      ready = true;
      // A newer native event must win over a slow initial read.
      return latest ?? initial;
    } catch (_) {
      ready = true;
      if (latest != null) return latest!;
      rethrow;
    }
  }

  void _setFailure(Object error, StackTrace stack) {
    final current = state.asData?.value;
    state = current == null
        ? AsyncError(error, stack)
        : AsyncData(
            current.withWarning('Could not refresh macOS state: $error'),
          );
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    final repository = ref.read(clipboardRepositoryProvider);
    final request = ++_refreshRequest;
    final revision = _revision;
    try {
      final snapshot = await repository.readSnapshot();
      if (ref.mounted && request == _refreshRequest && revision == _revision) {
        state = AsyncData(snapshot);
      }
    } catch (error, stack) {
      if (ref.mounted && request == _refreshRequest && revision == _revision) {
        _setFailure(error, stack);
      }
    }
  }

  ClipboardRepository get _repository => ref.read(clipboardRepositoryProvider);
  Future<String?> paste(String id, {bool plain = false}) =>
      _repository.restoreItem(id, paste: true, plain: plain);
  Future<String?> copy(String id, {bool plain = false}) =>
      _repository.restoreItem(id, paste: false, plain: plain);
  Future<void> createSnippet(SnippetDraft draft) =>
      _repository.createSnippet(draft);
  Future<void> createPinboard(PinboardDraft draft) =>
      _repository.createPinboard(draft);
  Future<void> pin(String id, String boardID) =>
      _repository.pinItem(id, boardID);
  Future<void> delete(String id) => _repository.deleteItem(id);
  Future<void> clearHistory() => _repository.clearHistory();
  Future<void> toggleCapture() => _repository.toggleCapture();
  Future<void> requestAccessibility() async {
    await _repository.requestAccessibility();
    if (ref.mounted) await refresh();
  }

  Future<void> setSyncEnabled(bool enabled) async {
    await _repository.setSyncEnabled(enabled);
    if (ref.mounted) await refresh();
  }

  Future<void> syncNow() => _repository.syncNow();
  Future<void> showFloating() => _repository.showFloating();
  Future<void> setFloatingPinned(bool value) =>
      _repository.setFloatingPinned(value);
  Future<void> dragFloating() => _repository.dragFloating();
  Future<void> setWidgetSharing(bool value) =>
      _repository.setWidgetSharing(value);
  Future<void> setScreenshotCopying(bool value) =>
      _repository.setScreenshotCopying(value);
  Future<void> chooseScreenshotFolder() => _repository.chooseScreenshotFolder();
  Future<void> useSystemScreenshotFolder() =>
      _repository.useSystemScreenshotFolder();
  Future<void> showShelf() => _repository.showShelf();
  Future<void> hide() => _repository.hide();
  Future<void> quit() => _repository.quit();
}

final clipboardSnapshotProvider = Provider<ClipboardSnapshot>((ref) {
  final value = ref.watch(clipboardControllerProvider);
  return value.asData?.value ??
      ClipboardSnapshot(
        warning: value.hasError
            ? 'Could not connect to macOS: ${value.error}'
            : '',
      );
});

final accessibilityGrantedProvider = Provider<bool>(
  (ref) => ref.watch(clipboardSnapshotProvider.select((s) => s.accessibility)),
);
final syncStatusProvider = Provider<SyncStatus>(
  (ref) => ref.watch(clipboardSnapshotProvider.select((s) => s.sync)),
);

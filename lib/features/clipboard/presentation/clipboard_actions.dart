import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/clipboard_controller.dart';
import '../domain/clipboard_item.dart';
import '../domain/clipboard_repository.dart';
import '../../pinboards/domain/pinboard_draft.dart';
import '../../snippets/domain/snippet_draft.dart';
import '../../snippets/presentation/snippet_dialog.dart';
import '../../pinboards/presentation/pinboard_dialog.dart';
import '../../settings/presentation/preferences_dialog.dart';
import 'widgets/item_preview.dart';

/// Presentation effects (dialogs/snackbars) stay out of repositories/controllers.
class ClipboardActions {
  const ClipboardActions(this.context, this.ref);
  final BuildContext context;
  final WidgetRef ref;
  ClipboardController get _controller =>
      ref.read(clipboardControllerProvider.notifier);
  Future<T?> _run<T>(Future<T> Function() operation) async {
    if (!context.mounted) return null;
    try {
      return await operation();
    } on ClipboardFailure catch (error) {
      _message(error.message);
    } on Exception catch (error) {
      _message('The action could not be completed: $error');
    }
    return null;
  }

  void _message(String text) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> paste(ClipItem item) async {
    final message = await _run(() => _controller.paste(item.id));
    if (message != null) _message(message);
  }

  Future<void> copy(ClipItem item, {bool plain = false}) async {
    final message = await _run(() => _controller.copy(item.id, plain: plain));
    if (message != null) _message(message);
  }

  Future<void> pin(String id, String boardID) async {
    await _run(() => _controller.pin(id, boardID));
  }

  Future<void> delete(ClipItem item) async {
    await _run(() => _controller.delete(item.id));
  }

  Future<void> toggleCapture() async {
    await _run(() => _controller.toggleCapture());
  }

  Future<void> requestAccessibility() async {
    await _run(() => _controller.requestAccessibility());
  }

  Future<void> showFloating() async {
    await _run(() => _controller.showFloating());
  }

  Future<void> setFloatingPinned(bool value) async {
    await _run(() => _controller.setFloatingPinned(value));
  }

  Future<void> dragFloating() async {
    await _run(() => _controller.dragFloating());
  }

  Future<void> setWidgetSharing(bool value) async {
    await _run(() => _controller.setWidgetSharing(value));
  }

  Future<void> setScreenshotCopying(bool value) async {
    await _run(() => _controller.setScreenshotCopying(value));
  }

  Future<void> chooseScreenshotFolder() async {
    await _run(() => _controller.chooseScreenshotFolder());
  }

  Future<void> useSystemScreenshotFolder() async {
    await _run(() => _controller.useSystemScreenshotFolder());
  }

  Future<void> showShelf() async {
    await _run(() => _controller.showShelf());
  }

  Future<void> hide() async {
    await _run(() => _controller.hide());
  }

  Future<void> quit() async {
    await _run(() => _controller.quit());
  }

  Future<void> syncNow() async {
    await _run(() => _controller.syncNow());
  }

  Future<void> showSnippet([ClipItem? item]) async {
    final draft = await showDialog<SnippetDraft>(
      context: context,
      builder: (_) => SnippetDialog(initialText: item?.text ?? ''),
    );
    if (draft != null) await _run(() => _controller.createSnippet(draft));
  }

  Future<void> showPinboardDialog() async {
    final draft = await showDialog<PinboardDraft>(
      context: context,
      builder: (_) => const PinboardDialog(),
    );
    if (draft != null) await _run(() => _controller.createPinboard(draft));
  }

  Future<void> clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear clipboard history?'),
        content: const Text(
          'Captured items will be permanently deleted. Your saved snippets and pinned items will stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run(() => _controller.clearHistory());
  }

  Future<void> toggleSync(bool enabled) async {
    if (enabled) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sync with your other Macs?'),
          content: const Text(
            'Your existing clipboard history, snippets, and pinboards will be uploaded to your current Apple Account’s private iCloud database. Copies on other Macs will appear here. Deleting an item also deletes it on synced Macs. File contents are not uploaded; file references may only work on their original Mac.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable iCloud sync'),
            ),
          ],
        ),
      );
      if (consent != true) return;
    }
    await _run(() => _controller.setSyncEnabled(enabled));
  }

  Future<void> showPreferences() => showDialog<void>(
    context: context,
    builder: (_) => PreferencesDialog(actions: this),
  );
  Future<void> showPreview(ClipItem item) => showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: SizedBox(
        width: 560,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ItemPreview(item: item, actions: this),
        ),
      ),
    ),
  );
  Future<void> handleItem(String value, ClipItem item) async {
    switch (value) {
      case 'paste':
        await paste(item);
      case 'copy':
        await copy(item);
      case 'plain':
        await copy(item, plain: true);
      case 'preview':
        await showPreview(item);
      case 'snippet':
        await showSnippet(item);
      case 'delete':
        await delete(item);
      case 'unpin':
        await pin(item.id, '');
      default:
        if (value.startsWith('pin:')) await pin(item.id, value.substring(4));
    }
  }
}

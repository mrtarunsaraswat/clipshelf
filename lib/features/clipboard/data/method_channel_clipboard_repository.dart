import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/clipboard_repository.dart';
import '../domain/clipboard_snapshot.dart';
import '../../pinboards/domain/pinboard_draft.dart';
import '../../snippets/domain/snippet_draft.dart';

const clipboardChannel = MethodChannel('clipshelf/native');

/// Owns the platform channel and converts its wire protocol into typed events.
class MethodChannelClipboardRepository implements ClipboardRepository {
  MethodChannelClipboardRepository([this._channel = clipboardChannel]) {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }
  final MethodChannel _channel;
  final _events = StreamController<ClipboardEvent>.broadcast(sync: true);
  bool _disposed = false;
  @override
  Stream<ClipboardEvent> get events => _events.stream;

  Future<void> _handleNativeEvent(MethodCall call) async {
    if (_disposed) return;
    try {
      switch (call.method) {
        case 'changed':
          _events.add(
            SnapshotChanged(
              ClipboardSnapshot.fromMap(
                Map<Object?, Object?>.from(call.arguments as Map),
              ),
            ),
          );
        case 'closed':
          _events.add(const PanelClosed());
        case 'opened':
          _events.add(
            PanelOpened(PanelPresentation.fromNative(call.arguments)),
          );
      }
    } catch (error, stack) {
      _events.addError(
        const ClipboardFailure('Could not read an update from macOS.'),
        stack,
      );
    }
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (error) {
      throw ClipboardFailure(error.message ?? error.code);
    } on MissingPluginException {
      throw const ClipboardFailure(
        'The macOS clipboard service is unavailable.',
      );
    }
  }

  @override
  Future<ClipboardSnapshot> readSnapshot() async {
    final data = await _invoke<Map<Object?, Object?>>('state');
    if (data == null) {
      throw const ClipboardFailure('macOS returned no clipboard state.');
    }
    return ClipboardSnapshot.fromMap(data);
  }

  @override
  Future<String?> restoreItem(
    String id, {
    required bool paste,
    bool plain = false,
  }) => _invoke<String>('copy', {
    'id': id,
    'paste': paste,
    if (plain) 'plain': true,
  });
  @override
  Future<void> createSnippet(SnippetDraft draft) =>
      _invoke<void>('snippet', {'title': draft.title, 'text': draft.text});
  @override
  Future<void> createPinboard(PinboardDraft draft) =>
      _invoke<void>('board', {'name': draft.name, 'color': draft.color});
  @override
  Future<void> pinItem(String id, String boardID) =>
      _invoke<void>('pin', {'id': id, 'boardID': boardID});
  @override
  Future<void> deleteItem(String id) => _invoke<void>('delete', {'id': id});
  @override
  Future<void> clearHistory() => _invoke<void>('clear');
  @override
  Future<void> toggleCapture() => _invoke<void>('pause');
  @override
  Future<bool> requestAccessibility() async =>
      await _invoke<bool>('accessibility') ?? false;
  @override
  Future<void> setSyncEnabled(bool enabled) =>
      _invoke<void>('sync', {'value': enabled});
  @override
  Future<void> syncNow() => _invoke<void>('syncNow');
  @override
  Future<void> showFloating() => _invoke<void>('showFloating');
  @override
  Future<void> setFloatingPinned(bool value) =>
      _invoke<void>('floatingPinned', {'value': value});
  @override
  Future<void> dragFloating() => _invoke<void>('dragFloating');
  @override
  Future<void> setWidgetSharing(bool value) =>
      _invoke<void>('widgetSharing', {'value': value});
  @override
  Future<void> setScreenshotCopying(bool value) =>
      _invoke<void>('screenshots', {'value': value});
  @override
  Future<void> chooseScreenshotFolder() => _invoke<void>('screenshotFolder');
  @override
  Future<void> useSystemScreenshotFolder() =>
      _invoke<void>('systemScreenshotFolder');
  @override
  Future<void> showShelf() => _invoke<void>('showShelf');
  @override
  Future<void> hide() => _invoke<void>('hide');
  @override
  Future<void> quit() => _invoke<void>('quit');

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _channel.setMethodCallHandler(null);
    unawaited(_events.close());
  }
}

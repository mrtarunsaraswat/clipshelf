import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/clipboard_controller.dart';
import 'method_channel_clipboard_repository.dart';

/// A web page's title and share image, loaded only when the user opts in.
class LinkPreview {
  const LinkPreview({required this.title, this.image});
  final String title;
  final Uint8List? image;
}

/// Read-only media lookups for cards: app icons, file icons, link previews.
/// Kept apart from the clipboard repository; every call degrades to null.
class ClipMedia {
  const ClipMedia([this._channel = clipboardChannel]);
  final MethodChannel _channel;

  Future<Uint8List?> appIcon(String bundleID) =>
      _bytes('appIcon', {'bundleID': bundleID});
  Future<Uint8List?> fileIcon(String path) =>
      _bytes('fileIcon', {'path': path});

  Future<LinkPreview?> linkPreview(String url) async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'linkPreview',
        {'url': url},
      );
      final title = value?['title'] as String?;
      if (title == null) return null;
      return LinkPreview(title: title, image: value?['image'] as Uint8List?);
    } on Object {
      return null;
    }
  }

  Future<void> setLinkPreviews(bool value) =>
      _channel.invokeMethod('linkPreviews', {'value': value});

  Future<Uint8List?> _bytes(String method, Map<String, Object> args) async {
    try {
      return await _channel.invokeMethod<Uint8List>(method, args);
    } on Object {
      return null;
    }
  }
}

final clipMediaProvider = Provider<ClipMedia>((ref) => const ClipMedia());

final appIconProvider = FutureProvider.family<Uint8List?, String>(
  (ref, bundleID) => bundleID.isEmpty
      ? Future.value()
      : ref.watch(clipMediaProvider).appIcon(bundleID),
);

final fileIconProvider = FutureProvider.family<Uint8List?, String>(
  (ref, path) => ref.watch(clipMediaProvider).fileIcon(path),
);

/// The Preferences switch, as reported by macOS in the snapshot.
final linkPreviewsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(clipboardSnapshotProvider.select((s) => s.linkPreviews)),
);

final linkPreviewProvider = FutureProvider.family<LinkPreview?, String>((
  ref,
  url,
) {
  if (!ref.watch(linkPreviewsEnabledProvider)) return Future.value();
  return ref.watch(clipMediaProvider).linkPreview(url);
});

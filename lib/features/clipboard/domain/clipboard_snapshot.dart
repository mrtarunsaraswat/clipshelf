import 'clipboard_item.dart';
import '../../screenshots/domain/screenshot_settings.dart';
import 'pinboard.dart';

enum PanelPresentation {
  shelf,
  quick,
  floating;

  static PanelPresentation fromNative(Object? value) => switch (value) {
    'quick' => quick,
    'floating' => floating,
    _ => shelf,
  };
}

class SyncStatus {
  const SyncStatus({
    this.enabled = false,
    this.configured = false,
    this.message = 'iCloud sync is off',
  });
  final bool enabled, configured;
  final String message;
  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      enabled == other.enabled &&
      configured == other.configured &&
      message == other.message;
  @override
  int get hashCode => Object.hash(enabled, configured, message);
}

class ClipboardSnapshot {
  ClipboardSnapshot({
    List<ClipItem> clips = const [],
    List<Pinboard> boards = const [],
    this.floatingPinned = true,
    this.widgetConfigured = false,
    this.widgetSharing = false,
    this.screenshots = const ScreenshotSettings(),
    this.paused = false,
    this.accessibility = false,
    this.warning = '',
    this.presentation = PanelPresentation.shelf,
    this.sync = const SyncStatus(),
    this.accentColor,
    this.reduceTransparency = false,
    this.linkPreviews = false,
  }) : clips = List.unmodifiable(clips),
       boards = List.unmodifiable(boards);

  factory ClipboardSnapshot.fromMap(Map<Object?, Object?> data) =>
      ClipboardSnapshot(
        clips: (data['clips'] as List)
            .map((e) => ClipItem.fromMap(Map<Object?, Object?>.from(e as Map)))
            .toList(),
        boards: ((data['boards'] as List?) ?? [])
            .map((e) => Pinboard.fromMap(Map<Object?, Object?>.from(e as Map)))
            .toList(),
        floatingPinned: data['floatingPinned'] != false,
        widgetConfigured: data['widgetConfigured'] == true,
        widgetSharing: data['widgetSharing'] == true,
        screenshots: ScreenshotSettings.fromMap(data),
        paused: data['paused'] as bool,
        accessibility: data['accessibility'] as bool,
        warning: data['warning'] as String,
        presentation: PanelPresentation.fromNative(data['presentation']),
        sync: SyncStatus(
          enabled: data['syncEnabled'] == true,
          configured: data['syncConfigured'] == true,
          message: data['syncStatus'] as String? ?? 'iCloud sync is off',
        ),
        accentColor: data['accentColor'] as int?,
        reduceTransparency: data['reduceTransparency'] == true,
        linkPreviews: data['linkPreviews'] == true,
      );
  final List<ClipItem> clips;
  final List<Pinboard> boards;
  final bool paused,
      accessibility,
      floatingPinned,
      widgetConfigured,
      widgetSharing;
  final String warning;
  final PanelPresentation presentation;
  final SyncStatus sync;
  final ScreenshotSettings screenshots;

  /// macOS accent colour as 0xAARRGGBB; null until the native side reports it.
  final int? accentColor;

  /// macOS Accessibility → Display → Reduce transparency.
  final bool reduceTransparency;

  /// Opt-in: load copied links' page titles and images.
  final bool linkPreviews;

  ClipboardSnapshot withWarning(String value) => ClipboardSnapshot(
    screenshots: screenshots,
    floatingPinned: floatingPinned,
    widgetConfigured: widgetConfigured,
    widgetSharing: widgetSharing,
    clips: clips,
    boards: boards,
    paused: paused,
    accessibility: accessibility,
    presentation: presentation,
    sync: sync,
    warning: value,
    accentColor: accentColor,
    reduceTransparency: reduceTransparency,
    linkPreviews: linkPreviews,
  );
}

sealed class ClipboardEvent {
  const ClipboardEvent();
}

final class SnapshotChanged extends ClipboardEvent {
  const SnapshotChanged(this.snapshot);
  final ClipboardSnapshot snapshot;
}

final class PanelOpened extends ClipboardEvent {
  const PanelOpened(this.presentation);
  final PanelPresentation presentation;
}

/// The native panel caught ⌘1–⌘9 (index 0–8) before a focused text field
/// could swallow it.
final class QuickUseRequested extends ClipboardEvent {
  const QuickUseRequested(this.index);
  final int index;
}

final class PanelClosed extends ClipboardEvent {
  const PanelClosed();
}

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

final class PanelClosed extends ClipboardEvent {
  const PanelClosed();
}

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

/// History size and age limits (Preferences → History) and current usage.
class HistorySettings {
  const HistorySettings({
    this.limit = 200,
    this.retentionDays = 0,
    this.bytes = 0,
    this.byteBudget = 100 * 1024 * 1024,
  });
  factory HistorySettings.fromMap(Map<Object?, Object?> data) =>
      HistorySettings(
        limit: data['historyLimit'] as int? ?? 200,
        retentionDays: data['historyRetentionDays'] as int? ?? 0,
        bytes: data['historyBytes'] as int? ?? 0,
        byteBudget: data['historyByteBudget'] as int? ?? 100 * 1024 * 1024,
      );

  static const limits = [100, 200, 500, 1000];

  /// 0 keeps history until the size limit removes it.
  static const retentions = [0, 1, 7, 30];
  final int limit, retentionDays, bytes, byteBudget;

  static String retentionLabel(int days) => switch (days) {
    0 => 'Forever',
    1 => '1 day',
    7 => '1 week',
    _ => '1 month',
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
    this.history = const HistorySettings(),
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
        history: HistorySettings.fromMap(data),
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

  /// How much history is kept, and how much storage it uses.
  final HistorySettings history;

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
    history: history,
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

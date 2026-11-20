import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/app/widgets/settings_group.dart';

import '../../screenshots/presentation/screenshot_settings_section.dart';

import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/data/clip_media.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_snapshot.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key, required this.actions});
  final ClipboardActions actions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.shelf;
    final snapshot = ref.watch(clipboardSnapshotProvider);
    final accessibility = ref.watch(accessibilityGrantedProvider);
    final sync = ref.watch(syncStatusProvider);
    final syncEnabled = sync.enabled;
    final syncStatus = sync.message;
    final syncConfigured = sync.configured;
    final subtitle = settingsSubtitleStyle(context);
    final history = snapshot.history;
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final allowButton = FilledButton(
      onPressed: () async {
        await actions.requestAccessibility();
      },
      child: const Text('Allow access'),
    );
    return ListView(
      padding: const EdgeInsets.only(right: 4),
      children: [
        SettingsGroup(
          title: 'Panels',
          children: [
            ListTile(
              contentPadding: settingsRowPadding,
              leading: SettingsIcon(
                Icons.picture_in_picture_alt_outlined,
                color: colors.kindImage,
              ),
              title: const Text('Floating mini-panel'),
              subtitle: Text(
                'A compact library you can keep beside your work.',
                style: subtitle,
              ),
              trailing: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  actions.showFloating();
                },
                child: const Text('Open'),
              ),
            ),
            SwitchListTile(
              contentPadding: settingsRowPadding,
              secondary: SettingsIcon(
                Icons.widgets_outlined,
                color: colors.kindSnippet,
              ),
              title: const Text('Desktop Favorites widget'),
              subtitle: Text(
                snapshot.widgetConfigured
                    ? 'Share saved text snippets and pinboards with the widget. Add ClipShelf from Edit Widgets; choose a collection in Edit Widget. Previews are off by default.'
                    : 'ClipShelf cannot reach its Favorites folder in Application Support. Check that folder\'s permissions. The floating panel works now.',
                style: subtitle,
              ),
              value: snapshot.widgetSharing,
              onChanged: snapshot.widgetConfigured
                  ? actions.setWidgetSharing
                  : null,
            ),
          ],
        ),
        SettingsGroup(
          title: 'iCloud',
          children: [
            SwitchListTile(
              contentPadding: settingsRowPadding,
              secondary: SettingsIcon(
                Icons.cloud_outlined,
                color: colors.kindLink,
              ),
              // Public builds have no CloudKit provisioning yet: show the
              // feature as coming soon. Provisioned builds keep the real toggle.
              title: syncConfigured
                  ? const Text('Sync across your Macs')
                  : Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Sync across your Apple devices',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ComingSoonBadge(colors: colors),
                      ],
                    ),
              subtitle: Text(
                syncConfigured ? syncStatus : 'Keep your history, snippets and pinboards in step on every Apple device with iCloud.',
                style: subtitle,
              ),
              value: syncEnabled,
              onChanged: syncConfigured
                  ? (value) async {
                      await actions.toggleSync(value);
                    }
                  : null,
            ),
            if (syncEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(52, 4, 14, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => actions.syncNow(),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Sync now'),
                  ),
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: 'Paste',
          footer: 'Click an item to paste. Use its Copy button or context menu to copy without pasting.',
          children: [
            ListTile(
              contentPadding: settingsRowPadding,
              leading: SettingsIcon(
                Icons.touch_app_outlined,
                color: colors.kindLink,
              ),
              title: Text(
                accessibility
                    ? 'Accessibility is enabled'
                    : 'Allow direct paste',
              ),
              // Narrow windows put the button under the text, not beside it.
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage access in System Settings → Privacy & Security.',
                    style: subtitle,
                  ),
                  if (narrow && !accessibility)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: allowButton,
                    ),
                ],
              ),
              trailing: accessibility
                  ? Icon(
                      Icons.check_circle,
                      color: colors.accentText,
                      semanticLabel: 'Accessibility enabled',
                    )
                  : narrow
                  ? null
                  : allowButton,
            ),
          ],
        ),
        SettingsGroup(
          title: 'Screenshots',
          children: [ScreenshotSettingsSection(actions: actions)],
        ),
        SettingsGroup(
          title: 'History',
          footer: 'Local history is saved without app-level encryption. With sync enabled, items also go to your private iCloud database. Concealed and transient copies are skipped; apps that do not mark secrets may still have them captured. Pause before copying sensitive material.',
          children: [
            SwitchListTile(
              contentPadding: settingsRowPadding,
              secondary: SettingsIcon(
                Icons.link_rounded,
                color: colors.kindLink,
              ),
              title: const Text('Show link previews'),
              subtitle: Text(
                'Load the title and image of links you copy. ClipShelf then contacts that website; nothing is sent anywhere else. Off by default.',
                style: subtitle,
              ),
              value: snapshot.linkPreviews,
              onChanged: (value) =>
                  ref.read(clipMediaProvider).setLinkPreviews(value),
            ),
            ListTile(
              contentPadding: settingsRowPadding,
              leading: SettingsIcon(
                Icons.auto_delete_outlined,
                color: colors.kindFile,
              ),
              title: const Text('Keep history for'),
              subtitle: Text(
                'Older items are removed automatically. Snippets and pinned items are kept.',
                style: subtitle,
              ),
              trailing: _Choice<int>(
                tooltip: 'Keep history for',
                value: history.retentionDays,
                options: HistorySettings.retentions,
                label: HistorySettings.retentionLabel,
                onSelected: (days) => ref
                    .read(clipMediaProvider)
                    .setHistoryPolicy(retentionDays: days),
              ),
            ),
            ListTile(
              contentPadding: settingsRowPadding,
              leading: SettingsIcon(
                Icons.history_rounded,
                color: colors.kindText,
              ),
              title: const Text('History size'),
              subtitle: Text(
                'Oldest items make room for new ones. Copies over 10 MB are skipped.',
                style: subtitle,
              ),
              trailing: _Choice<int>(
                tooltip: 'History size',
                value: history.limit,
                options: HistorySettings.limits,
                label: (limit) => '${_thousands(limit)} items',
                onSelected: (limit) =>
                    ref.read(clipMediaProvider).setHistoryPolicy(limit: limit),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 4, 14, 12),
              child: _StorageMeter(
                bytes: history.bytes,
                budget: history.byteBudget,
              ),
            ),
            ListTile(
              contentPadding: settingsRowPadding,
              leading: SettingsIcon(Icons.delete_outline, color: colors.danger),
              title: const Text('Clear history'),
              subtitle: Text(
                'Snippets and pinned items are kept.',
                style: subtitle,
              ),
              onTap: actions.clearHistory,
              trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(
            children: [
              Text(
                'ClipShelf 1.0.0 · ⌥⌘V to open · ⌘N for a new snippet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ShelfType.caption,
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
              // The developer's signature.
              Text.rich(
                TextSpan(
                  text: 'Made with ',
                  children: [
                    TextSpan(
                      text: '♥',
                      style: TextStyle(color: colors.danger),
                    ),
                    const TextSpan(text: ' by '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: _CreditLink(
                        label: 'Tarun',
                        url: _authorProfile,
                        onOpen: (url) =>
                            ref.read(clipMediaProvider).openURL(url),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ShelfType.meta,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge({required this.colors});
  final ShelfColors colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    // Amber, like the Paused pill: it signals "waiting", not an action.
    decoration: BoxDecoration(
      color: colors.warningSurface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'Coming soon',
      style: TextStyle(
        fontSize: ShelfType.caption,
        fontWeight: FontWeight.w600,
        color: colors.warningText,
      ),
    ),
  );
}

String _thousands(int value) => value >= 1000
    ? '${value ~/ 1000},${(value % 1000).toString().padLeft(3, '0')}'
    : '$value';

String _megabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb < 10 ? '${mb.toStringAsFixed(1)} MB' : '${mb.round()} MB';
}

/// A compact value + chevron menu for a settings row.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.tooltip,
    required this.value,
    required this.options,
    required this.label,
    required this.onSelected,
  });
  final String tooltip;
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: value,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem(value: option, height: 34, child: Text(label(option))),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: colors.surfaceHover,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label(value),
              style: TextStyle(
                fontSize: ShelfType.meta,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 15,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// "12.4 MB of 100 MB" with a thin bar; amber when nearly full.
class _StorageMeter extends StatelessWidget {
  const _StorageMeter({required this.bytes, required this.budget});
  final int bytes, budget;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final fraction = budget <= 0 ? 0.0 : (bytes / budget).clamp(0.0, 1.0);
    final full = fraction > 0.85;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Storage used: ${_megabytes(bytes)} of ${_megabytes(budget)}',
          style: TextStyle(
            fontSize: ShelfType.caption,
            color: colors.textSecondary,
            fontFeatures: ShelfType.tabular,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: colors.surfaceHover,
            color: full ? colors.warningText : colors.accentText,
          ),
        ),
      ],
    );
  }
}

const _authorProfile = 'https://www.linkedin.com/in/mrtarunsaraswat/';

/// The author's name in the credit, linking to their profile; underlines on hover.
class _CreditLink extends StatefulWidget {
  const _CreditLink({
    required this.label,
    required this.url,
    required this.onOpen,
  });
  final String label, url;
  final ValueChanged<String> onOpen;

  @override
  State<_CreditLink> createState() => _CreditLinkState();
}

class _CreditLinkState extends State<_CreditLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Tooltip(
      message: 'Open Tarun’s LinkedIn profile',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onOpen(widget.url),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: ShelfType.meta,
              fontWeight: FontWeight.w600,
              color: colors.accentText,
              decoration: _hovered ? TextDecoration.underline : null,
              decorationColor: colors.accentText,
            ),
          ),
        ),
      ),
    );
  }
}

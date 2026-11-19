import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/app/widgets/settings_group.dart';

import '../../screenshots/presentation/screenshot_settings_section.dart';

import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
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
              title: const Text('Sync across your Macs'),
              subtitle: Text(
                syncConfigured ? syncStatus : 'Requires an iCloud-enabled signed build. Local features work now.',
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
              subtitle: Text(
                'Manage access in System Settings → Privacy & Security.',
                style: subtitle,
              ),
              trailing: accessibility
                  ? Icon(
                      Icons.check_circle,
                      color: colors.accentText,
                      semanticLabel: 'Accessibility enabled',
                    )
                  : FilledButton(
                      onPressed: () async {
                        await actions.requestAccessibility();
                      },
                      child: const Text('Allow access'),
                    ),
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
            ListTile(
              contentPadding: settingsRowPadding,
              leading: SettingsIcon(
                Icons.history_rounded,
                color: colors.kindText,
              ),
              title: const Text('Local history'),
              subtitle: Text(
                'Up to 200 captured items, with a 100 MB total payload budget. Individual copies over 10 MB are skipped. Snippets and pinned items stay until you delete them (up to 500 saved items, within 50 MB).',
                style: subtitle,
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ClipShelf 1.0.0 · ⌥⌘V to open · ⌘N for a new snippet',
            style: TextStyle(
              fontSize: ShelfType.caption,
              color: colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

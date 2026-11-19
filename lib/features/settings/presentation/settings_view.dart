import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';

import '../../screenshots/presentation/screenshot_settings_section.dart';

import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key, required this.actions});
  final ClipboardActions actions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(clipboardSnapshotProvider);
    final accessibility = ref.watch(accessibilityGrantedProvider);
    final sync = ref.watch(syncStatusProvider);
    final syncEnabled = sync.enabled;
    final syncStatus = sync.message;
    final syncConfigured = sync.configured;
    return ListView(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Floating mini-panel'),
          subtitle: const Text(
            'A compact library you can keep beside your work.',
          ),
          trailing: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              actions.showFloating();
            },
            child: const Text('Open'),
          ),
        ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Desktop Favorites widget'),
          subtitle: Text(
            snapshot.widgetConfigured
                ? 'Share saved text snippets and pinboards with the widget. Add ClipShelf from Edit Widgets; choose a collection in Edit Widget. Previews are off by default.'
                : 'Available after App Group signing is configured. The floating panel works now.',
          ),
          value: snapshot.widgetSharing,
          onChanged: snapshot.widgetConfigured
              ? actions.setWidgetSharing
              : null,
        ),
        const Divider(height: 32),
        const Text(
          'ICLOUD',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sync across your Macs'),
          subtitle: Text(
            syncConfigured ? syncStatus : 'Requires an iCloud-enabled signed build. Local features work now.',
            style: const TextStyle(fontSize: 12),
          ),
          value: syncEnabled,
          onChanged: syncConfigured
              ? (value) async {
                  await actions.toggleSync(value);
                }
              : null,
        ),
        if (syncEnabled)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => actions.syncNow(),
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Sync now'),
            ),
          ),
        const Divider(height: 32),
        const Text(
          'WORKFLOW',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Click an item to paste. Use its Copy button or context menu to copy without pasting.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            accessibility ? 'Accessibility is enabled' : 'Allow direct paste',
          ),
          subtitle: const Text(
            'Manage access in System Settings → Privacy & Security.',
            style: TextStyle(fontSize: 12),
          ),
          trailing: accessibility
              ? const Icon(
                  Icons.check_circle,
                  color: accent,
                  semanticLabel: 'Accessibility enabled',
                )
              : OutlinedButton(
                  onPressed: () async {
                    await actions.requestAccessibility();
                  },
                  child: const Text('Allow access'),
                ),
        ),
        const Divider(height: 40),
        ScreenshotSettingsSection(actions: actions),
        const Divider(height: 40),
        const Text(
          'LOCAL HISTORY',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Up to 200 captured items, with a 100 MB total payload budget. Individual copies over 10 MB are skipped. Snippets and pinned items stay until you delete them (up to 500 saved items, within 50 MB).',
          style: TextStyle(fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 12),
        const Text(
          'Local history is saved without app-level encryption. With sync enabled, items also go to your private iCloud database. Concealed and transient copies are skipped; apps that do not mark secrets may still have them captured. Pause before copying sensitive material.',
          style: TextStyle(fontSize: 12, height: 1.7, color: Colors.grey),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: actions.clearHistory,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Clear history'),
          ),
        ),
        const Divider(height: 40),
        const Text(
          'ClipShelf 1.0.0 · ⌥⌘V to open · ⌘N for a new snippet',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

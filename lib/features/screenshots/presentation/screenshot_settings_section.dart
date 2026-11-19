import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../app/widgets/settings_group.dart';
import '../../clipboard/application/clipboard_controller.dart';
import '../../clipboard/presentation/clipboard_actions.dart';

/// Screenshot rows for the Preferences "Screenshots" group.
class ScreenshotSettingsSection extends ConsumerWidget {
  const ScreenshotSettingsSection({super.key, required this.actions});
  final ClipboardActions actions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.shelf;
    final settings = ref.watch(
      clipboardSnapshotProvider.select((s) => s.screenshots),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: settingsRowPadding,
          secondary: SettingsIcon(
            Icons.screenshot_monitor_outlined,
            color: colors.kindFile,
          ),
          title: const Text('Automatically copy screenshots'),
          subtitle: Text(
            'New screenshots saved to this folder are copied to your clipboard and history. Original files stay in place.',
            style: settingsSubtitleStyle(context),
          ),
          value: settings.enabled,
          onChanged: actions.setScreenshotCopying,
        ),
        if (settings.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.folder.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceHover,
                      borderRadius: BorderRadius.circular(ShelfRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 15,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            settings.folder,
                            style: TextStyle(
                              fontSize: ShelfType.meta,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      settings.watching
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 14,
                      color: settings.watching
                          ? colors.kindImage
                          : colors.warningText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        settings.message,
                        style: TextStyle(
                          fontSize: ShelfType.meta,
                          color: settings.watching
                              ? colors.textSecondary
                              : colors.warningText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: actions.chooseScreenshotFolder,
                      child: const Text('Choose screenshot folder'),
                    ),
                    TextButton(
                      onPressed: actions.useSystemScreenshotFolder,
                      child: const Text('Use macOS screenshot location'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

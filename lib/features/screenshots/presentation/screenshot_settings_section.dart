import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clipboard/application/clipboard_controller.dart';
import '../../clipboard/presentation/clipboard_actions.dart';

class ScreenshotSettingsSection extends ConsumerWidget {
  const ScreenshotSettingsSection({super.key, required this.actions});
  final ClipboardActions actions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      clipboardSnapshotProvider.select((s) => s.screenshots),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Automatically copy screenshots'),
          subtitle: const Text(
            'New screenshots saved to this folder are copied to your clipboard and history. Original files stay in place.',
          ),
          value: settings.enabled,
          onChanged: actions.setScreenshotCopying,
        ),
        if (settings.enabled) ...[
          if (settings.folder.isNotEmpty)
            SelectableText(
              settings.folder,
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 6),
          Text(
            settings.message,
            style: TextStyle(
              fontSize: 12,
              color: settings.watching
                  ? null
                  : Theme.of(context).colorScheme.secondary,
            ),
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
      ],
    );
  }
}

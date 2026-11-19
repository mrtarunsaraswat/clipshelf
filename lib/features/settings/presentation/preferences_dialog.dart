import 'package:flutter/material.dart';

import '../../clipboard/presentation/clipboard_actions.dart';
import 'settings_view.dart';

class PreferencesDialog extends StatelessWidget {
  const PreferencesDialog({super.key, required this.actions});
  final ClipboardActions actions;
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 680,
      height: 550,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Preferences',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Close preferences',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(child: SettingsView(actions: actions)),
          ],
        ),
      ),
    ),
  );
}

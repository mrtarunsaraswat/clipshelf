import 'package:flutter/material.dart';

import '../../../app/tokens.dart';
import '../../clipboard/presentation/clipboard_actions.dart';
import 'settings_view.dart';

class PreferencesDialog extends StatelessWidget {
  const PreferencesDialog({super.key, required this.actions});
  final ClipboardActions actions;
  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    // In the narrow menu-bar panel, use nearly the whole width.
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: narrow
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: 640,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 14, 14),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 20, color: colors.accentText),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Preferences',
                      style: TextStyle(
                        fontSize: ShelfType.heading + 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preferences',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.stroke),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
                child: SettingsView(actions: actions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

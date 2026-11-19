import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/clipboard/application/clipboard_controller.dart';
import '../features/clipboard/presentation/clipboard_screen.dart';
import 'theme.dart';

class ClipShelf extends ConsumerWidget {
  const ClipShelf({super.key, this.glass = true, this.themeMode});

  /// False when no native frosted window is behind Flutter (previews, tests).
  final bool glass;

  /// Overrides the macOS appearance; previews use it to render both themes.
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentValue = ref.watch(
      clipboardSnapshotProvider.select((s) => s.accentColor),
    );
    final accent = accentValue == null ? brandAccent : Color(accentValue);
    return MaterialApp(
      title: 'ClipShelf',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light, accent: accent, glass: glass),
      darkTheme: buildAppTheme(Brightness.dark, accent: accent, glass: glass),
      themeMode: themeMode ?? ThemeMode.system,
      home: const ClipboardScreen(),
    );
  }
}

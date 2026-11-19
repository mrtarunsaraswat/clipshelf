import 'package:flutter/material.dart';

import '../features/clipboard/presentation/clipboard_screen.dart';
import 'theme.dart';

class ClipShelf extends StatelessWidget {
  const ClipShelf({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ClipShelf',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const ClipboardScreen(),
  );
}

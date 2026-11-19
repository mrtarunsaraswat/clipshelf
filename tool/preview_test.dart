import 'dart:io';

import 'package:clipshelf/app/app.dart';
import 'package:clipshelf/features/clipboard/data/method_channel_clipboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('render library preview with sample history', (tester) async {
    final font = FontLoader('.AppleSystemUIFont')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('/System/Library/Fonts/SFNS.ttf').readAsBytesSync(),
          ),
        ),
      );
    await tester.runAsync(() => font.load());
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(() => icons.load());
    const floatingPreview = bool.fromEnvironment('FLOATING_PREVIEW');
    const quickPreview =
        bool.fromEnvironment('QUICK_PREVIEW') || floatingPreview;
    // Renders Preferences into build/ for review; not a committed golden.
    const preferencesPreview = bool.fromEnvironment('PREFERENCES_PREVIEW');
    tester.view.physicalSize = preferencesPreview
        ? const Size(760, 640)
        : quickPreview
        ? const Size(440, 560)
        : const Size(1280, 430);
    tester.view.devicePixelRatio = 1;
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final texts = [
      'Small ideas.\nBig possibilities.\n\nA place for everything you want to keep close.',
      'https://flutter.dev',
      'Team sync · Thursday\nReview the new designs and share feedback.',
      'Thanks for reaching out. I’ll get back to you shortly.',
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          clipboardChannel,
          (call) async => call.method == 'state'
              ? {
                  'clips': [
                    for (var i = 0; i < texts.length; i++)
                      {
                        'id': '$i',
                        'title': texts[i].split('\n').first,
                        'text': texts[i],
                        'kind': 'text',
                        'source': i == 1 ? 'Safari' : 'Notes',
                        'snippet': false,
                        'date': now - i * 180,
                        'size': texts[i].length,
                        'formats': ['public.utf8-plain-text'],
                        'boardID': i == 2 ? 'work' : '',
                      },
                  ],
                  'boards': [
                    {'id': 'work', 'name': 'Work', 'color': 0},
                    {'id': 'ideas', 'name': 'Ideas', 'color': 2},
                  ],
                  'presentation': floatingPreview
                      ? 'floating'
                      : quickPreview
                      ? 'quick'
                      : 'shelf',
                  'paused': false,
                  'autoPaste': false,
                  'accessibility': const bool.fromEnvironment(
                    'ACCESSIBILITY_PREVIEW',
                  ),
                  'warning': '',
                }
              : null,
        );
    const dark = bool.fromEnvironment('DARK_PREVIEW');
    // The real window is a native frosted NSVisualEffectView. Approximate it with
    // a wallpaper gradient under a translucent material so the glass reads.
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6A8CAF),
                      Color(0xFF9C7FB8),
                      Color(0xFFE0A07A),
                    ],
                  ),
                ),
              ),
              ColoredBox(
                color: dark ? const Color(0xD91E1E21) : const Color(0xD9F4F4F7),
              ),
              const ProviderScope(
                child: ClipShelf(
                  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (preferencesPreview) {
      await tester.tap(find.byTooltip('Preferences'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('preview')),
        matchesGoldenFile(
          '../build/preferences-preview${dark ? '-dark' : ''}.png',
        ),
      );
      return;
    }
    final name = floatingPreview
        ? 'floating-preview'
        : quickPreview
        ? 'menu-bar-preview'
        : 'preview';
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('../$name${dark ? '-dark' : ''}.png'),
    );
  });
}

import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_snapshot.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/screenshots/domain/screenshot_settings.dart';
import 'package:clipshelf/features/screenshots/presentation/screenshot_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_clipboard_repository.dart';

void main() {
  test('screenshot native settings decode and survive a library warning', () {
    final settings = ScreenshotSettings.fromMap({
      'screenshotsEnabled': true,
      'screenshotsFolder': '/example/Screenshots',
      'screenshotsStatus': 'Watching for new screenshots',
      'screenshotsWatching': true,
    });
    final snapshot = ClipboardSnapshot(screenshots: settings)
        .withWarning('Refresh failed');
    expect(snapshot.screenshots.folder, '/example/Screenshots');
    expect(snapshot.screenshots.watching, isTrue);
    expect(ScreenshotSettings.fromMap({}).enabled, isTrue);
  });

  testWidgets(
    'screenshot controls send typed commands and follow native updates',
    (tester) async {
      final repository = FakeClipboardRepository(
        ClipboardSnapshot(
          screenshots: const ScreenshotSettings(
            folder: '/example/Screenshots',
            message: 'Watching for new screenshots',
            watching: true,
          ),
        ),
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipboardRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ScreenshotSettingsSection(
                  actions: ClipboardActions(context, ref),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('/example/Screenshots'), findsOneWidget);
      await tester.tap(find.text('Choose screenshot folder'));
      await tester.pumpAndSettle();
      expect(repository.operations, contains('screenshotFolder'));
      await tester.tap(find.text('Use macOS screenshot location'));
      await tester.pumpAndSettle();
      expect(repository.operations, contains('systemScreenshotFolder'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(repository.operations, contains('screenshots:false'));
      repository.emit(
        ClipboardSnapshot(
          screenshots: const ScreenshotSettings(enabled: false, message: 'Off'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('/example/Screenshots'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

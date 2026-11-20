import 'dart:convert';

import 'package:clipshelf/app/app.dart';
import 'package:clipshelf/features/clipboard/application/library_view_controller.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/data/method_channel_clipboard_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> clip(String id, String text, {bool snippet = false}) => {
  'id': id,
  'title': text,
  'text': text,
  'kind': 'text',
  'source': 'TextEdit',
  'snippet': snippet,
  'date': 1700000000,
  'size': text.length,
  'formats': ['public.utf8-plain-text'],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var presentation = 'shelf';
  Map<String, dynamic> currentState = {};
  setUp(() {
    calls.clear();
    presentation = 'shelf';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, (call) async {
          calls.add(call);
          if (call.method == 'state') {
            currentState = {
              'clips': [
                clip('a', 'Meeting notes'),
                clip('b', 'Hello there', snippet: true),
                clip('c', 'Second history item'),
              ],
              'boards': [
                {'id': 'work', 'name': 'Work', 'color': 0},
              ],
              'syncConfigured': true,
              'presentation': presentation,
              'paused': false,
              'autoPaste': false,
              'accessibility': false,
              'warning': '',
            };
            return currentState;
          }
          if (call.method == 'copy') return 'Copied to clipboard';
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, null),
  );
  test(
    'Search covers content, source, and native formats with case folding',
    () {
      final item = ClipItem.fromMap(clip('a', 'Meeting notes'));
      expect(item.matches('  MEETING '), isTrue);
      expect(item.matches('textedit'), isTrue);
      expect(item.matches('public.utf8'), isTrue);
      expect(item.matches('absent'), isFalse);
    },
  );
  Future<void> load(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1060, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: ClipShelf()));
    await tester.pumpAndSettle();
  }

  /// The shelf keeps search collapsed behind its search button.
  Future<void> openShelfSearch(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Search (⌘F)'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Floating panel exposes pin and close, with paste and copy actions',
    (tester) async {
      presentation = 'floating';
      await load(tester);
      tester.view.physicalSize = const Size(360, 560);
      await tester.pumpAndSettle();
      expect(find.text('ClipShelf · Floating'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Keep visible: on'));
      await tester.pumpAndSettle();
      expect(calls.lastWhere((c) => c.method == 'floatingPinned').arguments, {
        'value': false,
      });
      await tester.tap(find.text('Meeting notes').first);
      await tester.pumpAndSettle();
      expect(calls.lastWhere((c) => c.method == 'copy').arguments, {
        'id': 'a',
        'paste': true,
      });
      await tester.tap(find.byTooltip('Copy to clipboard').first);
      await tester.pumpAndSettle();
      expect(calls.lastWhere((c) => c.method == 'copy').arguments, {
        'id': 'a',
        'paste': false,
      });
      await tester.tap(find.byTooltip('Close panel'));
      expect(calls.any((c) => c.method == 'hide'), isTrue);
    },
  );
  testWidgets('Quick panel can open the floating view', (tester) async {
    presentation = 'quick';
    await load(tester);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open floating panel'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'showFloating'), isTrue);
  });

  void nativePanelEvent(WidgetTester tester, String method, [Object? value]) {
    tester.binding.channelBuffers.push(
      clipboardChannel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, value)),
      (_) {},
    );
  }

  testWidgets(
    'More menu opens on every cycle and is cleared when native panel hides',
    (tester) async {
      presentation = 'quick';
      await load(tester);
      for (var cycle = 0; cycle < 4; cycle++) {
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        expect(find.text('Open floating panel'), findsOneWidget);
        expect(calls.where((call) => call.method == 'hide'), isEmpty);
        nativePanelEvent(tester, 'closed');
        await tester.pumpAndSettle();
        expect(find.text('Open floating panel'), findsNothing);
        nativePanelEvent(tester, 'opened', 'quick');
        await tester.pumpAndSettle();
        expect(find.text('Open floating panel'), findsNothing);
        expect(find.byKey(const ValueKey('quick-item-a')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Reopening clears a stale collection menu even without a closed event',
    (tester) async {
      presentation = 'quick';
      await load(tester);
      await tester.tap(find.byTooltip('Choose collection'));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      nativePanelEvent(tester, 'opened', 'quick');
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsNothing);
      await tester.tap(find.byTooltip('Choose collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snippets'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quick-item-b')), findsOneWidget);
    },
  );

  Future<void> reopenPanel(WidgetTester tester) async {
    nativePanelEvent(tester, 'closed');
    await tester.pumpAndSettle();
    nativePanelEvent(tester, 'opened', 'quick');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Reopening the panel closes Preferences and shows the clipboard',
    (tester) async {
      presentation = 'quick';
      await load(tester);
      await tester.tap(find.byTooltip('Preferences'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close preferences'), findsOneWidget);
      await reopenPanel(tester);
      expect(find.byTooltip('Close preferences'), findsNothing);
    },
  );

  testWidgets('Preferences is still open after leaving for Allow access', (
    tester,
  ) async {
    presentation = 'quick';
    await load(tester);
    await tester.tap(find.byTooltip('Preferences'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Allow access'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    await reopenPanel(tester); // back from System Settings
    expect(find.byTooltip('Close preferences'), findsOneWidget);
    await reopenPanel(tester); // the next time it starts fresh again
    expect(find.byTooltip('Close preferences'), findsNothing);
  });

  testWidgets('A half-written snippet survives hiding and reopening', (
    tester,
  ) async {
    presentation = 'quick';
    await load(tester);
    await tester.tap(find.byTooltip('New snippet (⌘N)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Draft text');
    await reopenPanel(tester);
    expect(find.text('Draft text'), findsOneWidget);
  });

  testWidgets(
    'History separates snippets, restores selected item, and filters search',
    (tester) async {
      await load(tester);
      expect(find.text('Meeting notes'), findsWidgets);
      expect(find.text('Hello there'), findsNothing);
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is PopupMenuButton<String> && w.tooltip == 'Item actions',
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy as plain text'), findsOneWidget);
      await tester.tap(find.text('Copy to clipboard'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'copy');
      expect(calls.last.arguments, {'id': 'a', 'paste': false});
      await openShelfSearch(tester);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches just yet.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.byTooltip('Snippets'));
      await tester.pumpAndSettle();
      expect(find.text('Hello there'), findsWidgets);
      expect(find.text('Meeting notes'), findsNothing);
    },
  );
  testWidgets('Snippet dialog rejects empty content and submits real text', (
    tester,
  ) async {
    await load(tester);
    await tester.tap(find.byTooltip('New snippet (⌘N)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save snippet'));
    await tester.pumpAndSettle();
    expect(find.text('Add some text to save.'), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Signature');
    await tester.enterText(fields.at(1), 'Best, Tarun');
    await tester.tap(find.text('Save snippet'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls.where((c) => c.method == 'snippet').single.arguments, {
      'title': 'Signature',
      'text': 'Best, Tarun',
    });
  });
  testWidgets('Library and preferences fit the minimum supported window', (
    tester,
  ) async {
    await load(tester);
    tester.view.physicalSize = const Size(880, 360);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preferences'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Allow direct paste'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    expect(find.text('Allow direct paste'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Clear history'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    expect(find.text('Clear history'), findsOneWidget);
  });
  testWidgets('Pin actions and drag both assign items to a pinboard', (
    tester,
  ) async {
    await load(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is PopupMenuButton<String> && w.tooltip == 'Item actions',
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to Work'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'pin').last.arguments, {
      'id': 'a',
      'boardID': 'work',
    });
    final body = find.text('Meeting notes').first;
    await tester.drag(
      body,
      tester.getCenter(find.text('Work')) - tester.getCenter(body),
    );
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'pin').length, 2);
  });
  testWidgets('Quick use selects the numbered visible result', (tester) async {
    await load(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'copy').single.arguments, {
      'id': 'c',
      'paste': true,
    });
  });
  testWidgets('Text cards show their character count', (tester) async {
    await load(tester);
    expect(find.text('13 characters'), findsOneWidget); // "Meeting notes"
  });
  testWidgets('A new copy slides in at the front of the shelf', (tester) async {
    await load(tester);
    currentState = {
      ...currentState,
      'clips': [clip('n', 'Fresh copy'), ...currentState['clips'] as List],
    };
    tester.binding.channelBuffers.push(
      clipboardChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('changed', currentState),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Fresh copy'), findsOneWidget); // mid-animation
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Fresh copy')).dx,
      lessThan(tester.getTopLeft(find.text('Meeting notes')).dx),
    );
  });
  testWidgets('Search offers filters: Tab adds a chip, Backspace removes it', (
    tester,
  ) async {
    await load(tester);
    await openShelfSearch(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextField)),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'tex');
    await tester.pumpAndSettle();
    expect(find.text('TextEdit'), findsOneWidget); // app suggestion in the menu
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final tokens = container.read(libraryViewProvider).tokens;
    expect(tokens.map((t) => t.label), ['Text']);
    expect(container.read(libraryViewProvider).query, isEmpty);
    expect(find.text('Meeting notes'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(container.read(libraryViewProvider).tokens, isEmpty);
  });
  testWidgets(
    'Shelf search: typing opens it, ↓ and Return pick a filter, Escape clears then closes',
    (tester) async {
      await load(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ClipShelf)),
      );
      expect(find.byType(TextField), findsNothing); // collapsed by default
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT, character: 't');
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(container.read(libraryViewProvider).query, 't');
      await tester.enterText(find.byType(TextField), 'tex');
      await tester.pumpAndSettle();
      // Suggestions: Text, then the TextEdit app. ↓ moves to the second.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(container.read(libraryViewProvider).tokens.map((t) => t.label), [
        'TextEdit',
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // clear
      await tester.pumpAndSettle();
      expect(container.read(libraryViewProvider).tokens, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // close
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Search (⌘F)'), findsOneWidget);
      expect(calls.where((c) => c.method == 'hide'), isEmpty);
    },
  );
  testWidgets(
    'Shelf search closes with ✕ or a click away, but only when empty',
    (tester) async {
      await load(tester);
      await openShelfSearch(tester);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await openShelfSearch(tester);
      await tester.tapAt(tester.getCenter(find.textContaining('On this Mac')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing); // empty: collapses
      await openShelfSearch(tester);
      await tester.enterText(find.byType(TextField), 'meeting');
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.textContaining('On this Mac')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget); // has a query: stays
      expect(find.byTooltip('Clear search'), findsOneWidget);
    },
  );
  testWidgets('Clip lists never paint scrolled-out rows over the header', (
    tester,
  ) async {
    presentation = 'quick';
    await load(tester);
    expect(
      tester.widget<AnimatedList>(find.byType(AnimatedList)).clipBehavior,
      Clip.hardEdge,
    );
  });
  testWidgets('Menu-bar image rows show a thumbnail with app, time and size', (
    tester,
  ) async {
    presentation = 'quick';
    await load(tester);
    // A 1×1 PNG stands in for the screenshot thumbnail.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    currentState = {
      ...currentState,
      'clips': [
        {
          ...clip('img', 'Screenshot 2026-11-20.png'),
          'kind': 'image',
          'text': '',
          'source': 'Screenshot',
          'preview': png,
          'pixelWidth': 2880,
          'pixelHeight': 1800,
        },
        ...currentState['clips'] as List,
      ],
    };
    tester.binding.channelBuffers.push(
      clipboardChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('changed', currentState),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Screenshot 2026-11-20.png'), findsOneWidget);
    expect(find.textContaining('Screenshot · '), findsOneWidget);
    expect(find.textContaining('2880 × 1800'), findsOneWidget);
  });
  testWidgets('The shelf handle closes the shelf on a click or a drag down', (
    tester,
  ) async {
    await load(tester);
    await tester.tap(find.byTooltip('Close (esc)'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'hide'), hasLength(1));
    await tester.drag(find.byTooltip('Close (esc)'), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'hide'), hasLength(2));
    await tester.drag(find.byTooltip('Close (esc)'), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'hide'), hasLength(2)); // up: no
  });
  testWidgets('Menu-bar panel opens the snippet editor in one click', (
    tester,
  ) async {
    presentation = 'quick';
    await load(tester);
    await tester.tap(find.byTooltip('New snippet (⌘N)'));
    await tester.pumpAndSettle();
    expect(find.text('A little less typing.'), findsOneWidget);
  });
  testWidgets(
    'Native ⌘-number quick use pastes even while the search field has focus',
    (tester) async {
      presentation = 'quick';
      await load(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      tester.binding.channelBuffers.push(
        clipboardChannel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall('quickUse', 1)),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'copy').single.arguments, {
        'id': 'c',
        'paste': true,
      });
    },
  );
  testWidgets(
    'Sync needs explicit consent before the platform is asked to upload',
    (tester) async {
      await load(tester);
      await tester.tap(find.byTooltip('Preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync across your Macs'));
      await tester.pumpAndSettle();
      expect(find.text('Sync with your other Macs?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'sync'), isEmpty);
      await tester.tap(find.text('Sync across your Macs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable iCloud sync'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'sync').single.arguments, {
        'value': true,
      });
    },
  );
  testWidgets('Menu-bar row click requests direct paste by default', (
    tester,
  ) async {
    presentation = 'quick';
    await load(tester);
    tester.view.physicalSize = const Size(360, 560);
    await tester.pumpAndSettle();
    expect(find.text('Click an item to paste'), findsOneWidget);
    expect(find.textContaining('Enable Accessibility'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick-item-a')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'copy').single.arguments, {
      'id': 'a',
      'paste': true,
    });
  });
  testWidgets('Menu-bar side button copies while numbered shortcuts paste', (
    tester,
  ) async {
    presentation = 'quick';
    await load(tester);
    tester.view.physicalSize = const Size(360, 560);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy to clipboard').first);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.method == 'copy').map((c) => c.arguments).toList(),
      [
        {'id': 'a', 'paste': false},
        {'id': 'c', 'paste': true},
      ],
    );
  });
  testWidgets(
    'Menu-bar context copy stays copy-only and can open the full shelf',
    (tester) async {
      presentation = 'quick';
      await load(tester);
      tester.view.physicalSize = const Size(360, 560);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('quick-item-a')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy to clipboard'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'copy').single.arguments, {
        'id': 'a',
        'paste': false,
      });
      await tester.tap(find.byTooltip('Open full shelf'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'showShelf');
    },
  );
  Future<void> permissionChanged(WidgetTester tester, bool granted) async {
    currentState = {...currentState, 'accessibility': granted};
    tester.binding.channelBuffers.push(
      clipboardChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('changed', currentState),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Permission grant removes the banner and updates an already-open Preferences dialog',
    (tester) async {
      presentation = 'quick';
      await load(tester);
      tester.view.physicalSize = const Size(360, 560);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enable Accessibility for one-click paste.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Preferences'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Allow access'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text('Allow access'), findsOneWidget);
      await permissionChanged(tester, true);
      expect(
        find.textContaining('Enable Accessibility for one-click paste.'),
        findsNothing,
      );
      expect(find.text('Allow access'), findsNothing);
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Scrollable),
                )
                .last,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Accessibility is enabled'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text('Accessibility is enabled'), findsOneWidget);
      expect(find.text('Allow access'), findsNothing);
      await tester.tap(find.byTooltip('Close preferences'));
      await tester.pumpAndSettle();
      await permissionChanged(tester, false);
      expect(
        find.textContaining('Enable Accessibility for one-click paste.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Shelf item selection and the first context action paste by default',
    (tester) async {
      await load(tester);
      await tester.tap(find.text('Meeting notes').first);
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'copy').single.arguments, {
        'id': 'a',
        'paste': true,
      });
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is PopupMenuButton<String> && w.tooltip == 'Item actions',
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.byType(PopupMenuItem<String>).first,
            )
            .value,
        'paste',
      );
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'copy').last.arguments, {
        'id': 'a',
        'paste': true,
      });
    },
  );
  testWidgets(
    'Reopening the menu-bar panel clears stale search and collection state',
    (tester) async {
      await load(tester);
      await openShelfSearch(tester);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.tap(find.byTooltip('Snippets'));
      await tester.pumpAndSettle();
      presentation = 'quick';
      tester.binding.channelBuffers.push(
        clipboardChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('opened', 'quick'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quick-item-a')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('History'), findsOneWidget);
    },
  );
}

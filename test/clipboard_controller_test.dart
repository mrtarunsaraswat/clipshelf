import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/application/library_view_controller.dart';
import 'package:clipshelf/features/clipboard/application/panel_session.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_repository.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_snapshot.dart';
import 'package:clipshelf/features/pinboards/domain/pinboard_draft.dart';
import 'package:clipshelf/features/snippets/domain/snippet_draft.dart';

import 'support/fake_clipboard_repository.dart';

ClipItem item(
  String id, {
  String kind = 'text',
  bool snippet = false,
  String boardID = '',
  List<String> formats = const ['public.utf8-plain-text'],
}) => ClipItem(
  id: id,
  title: 'Notes $id',
  text: 'Content $id',
  kind: kind,
  source: 'TextEdit',
  snippet: snippet,
  date: DateTime(2026),
  size: 12,
  formats: formats,
  boardID: boardID,
);
void main() {
  late FakeClipboardRepository repository;
  late ProviderContainer container;
  setUp(() {
    repository = FakeClipboardRepository(ClipboardSnapshot(clips: [item('a')]));
    container = ProviderContainer(
      overrides: [clipboardRepositoryProvider.overrideWithValue(repository)],
    );
  });
  tearDown(() async {
    container.dispose();
    await repository.dispose();
  });
  Future<ClipboardSnapshot> load() =>
      container.read(clipboardControllerProvider.future);
  test('native panel close tracks visibility without refreshing or discarding the library', () async {
    await load();
    final reads = repository.reads;
    repository.changes.add(const PanelClosed());
    expect(container.read(panelSessionProvider).visible, isFalse);
    expect(repository.reads, reads);
    expect(container.read(clipboardSnapshotProvider).clips.single.id, 'a');
    repository.opened(PanelPresentation.quick);
    expect(container.read(panelSessionProvider).visible, isTrue);
    expect(container.read(panelSessionProvider).sequence, 2);
  });
  test('initial load exposes typed state and subscribes once', () async {
    expect(container.read(clipboardControllerProvider).isLoading, isTrue);
    final result = await load();
    expect(result.clips.single.id, 'a');
    expect(repository.reads, 1);
    expect(repository.listeners, 1);
  });
  test(
    'live permission and sync changes replace the shared snapshot',
    () async {
      await load();
      repository.emit(
        ClipboardSnapshot(
          clips: [item('a')],
          accessibility: true,
          sync: const SyncStatus(
            enabled: true,
            configured: true,
            message: 'Synced',
          ),
        ),
      );
      final state = container.read(clipboardSnapshotProvider);
      expect(state.accessibility, isTrue);
      expect(state.sync.enabled, isTrue);
      expect(state.sync.message, 'Synced');
      repository.emit(
        ClipboardSnapshot(clips: [item('a')], accessibility: false),
      );
      expect(container.read(clipboardSnapshotProvider).accessibility, isFalse);
    },
  );
  test(
    'a native update during a slow initial read wins over the stale read',
    () async {
      final pending = Completer<ClipboardSnapshot>();
      repository.read = () => pending.future;
      final future = load();
      repository.emit(
        ClipboardSnapshot(clips: [item('new')], accessibility: true),
      );
      pending.complete(ClipboardSnapshot(clips: [item('old')]));
      final result = await future;
      expect(result.clips.single.id, 'new');
      expect(result.accessibility, isTrue);
    },
  );
  test('refresh cannot overwrite a more recent native event', () async {
    await load();
    final pending = Completer<ClipboardSnapshot>();
    repository.read = () => pending.future;
    final refreshing = container
        .read(clipboardControllerProvider.notifier)
        .refresh();
    repository.emit(ClipboardSnapshot(clips: [item('new')]));
    pending.complete(ClipboardSnapshot(clips: [item('old')]));
    await refreshing;
    expect(container.read(clipboardSnapshotProvider).clips.single.id, 'new');
  });
  test(
    'initial read errors are visible and explicit refresh recovers',
    () async {
      repository.read = () =>
          Future.error(const ClipboardFailure('Unavailable'));
      await expectLater(load(), throwsA(isA<ClipboardFailure>()));
      expect(container.read(clipboardControllerProvider).hasError, isTrue);
      expect(repository.reads, 1);
      repository.read = null;
      await container.read(clipboardControllerProvider.notifier).refresh();
      expect(container.read(clipboardSnapshotProvider).clips.single.id, 'a');
    },
  );
  test(
    'refresh errors preserve usable history and a later event recovers',
    () async {
      await load();
      repository.read = () =>
          Future.error(const ClipboardFailure('Unavailable'));
      await container.read(clipboardControllerProvider.notifier).refresh();
      expect(container.read(clipboardSnapshotProvider).clips.single.id, 'a');
      expect(
        container.read(clipboardSnapshotProvider).warning,
        contains('Unavailable'),
      );
      repository.emit(ClipboardSnapshot(clips: [item('b')]));
      expect(container.read(clipboardSnapshotProvider).warning, isEmpty);
    },
  );
  test('typed commands distinguish paste, copy, plain text, pinboards and snippets', () async {
    await load();
    final controller = container.read(clipboardControllerProvider.notifier);
    await controller.paste('a');
    await controller.copy('a', plain: true);
    await controller.createSnippet(
      const SnippetDraft(title: 'Signature', text: 'Thanks'),
    );
    await controller.createPinboard(
      const PinboardDraft(name: 'Work', color: 2),
    );
    await controller.pin('a', 'work');
    expect(repository.restores, [
      (id: 'a', paste: true, plain: false),
      (id: 'a', paste: false, plain: true),
    ]);
    expect(repository.snippets.single.text, 'Thanks');
    expect(repository.pinboards.single.name, 'Work');
    expect(repository.pins.single, (id: 'a', boardID: 'work'));
  });
  test('a failed command does not discard the clipboard state', () async {
    await load();
    repository.restoreFailure = const ClipboardFailure('Denied');
    await expectLater(
      container.read(clipboardControllerProvider.notifier).paste('a'),
      throwsA(isA<ClipboardFailure>()),
    );
    expect(container.read(clipboardSnapshotProvider).clips.single.id, 'a');
  });
  test('collection, format and query providers derive results without changing source items', () async {
    repository.snapshot = ClipboardSnapshot(
      clips: [
        item('a'),
        item('s', snippet: true, boardID: 'work'),
        item('i', kind: 'image', boardID: 'work'),
        item('f', kind: 'file'),
      ],
    );
    await load();
    final view = container.read(libraryViewProvider.notifier);
    List<String> ids() =>
        container.read(visibleItemsProvider).map((e) => e.id).toList();
    expect(ids(), ['a', 'i', 'f']);
    view.choose(const ClipboardCollection.snippets());
    expect(ids(), ['s']);
    view.choose(const ClipboardCollection.board('work'));
    expect(ids(), ['s', 'i']);
    view.filter(ItemFilter.image);
    expect(ids(), ['i']);
    view.search('missing');
    expect(ids(), isEmpty);
    view.search(' TEXTEDIT ');
    expect(ids(), ['i']);
    expect(container.read(clipboardSnapshotProvider).clips.length, 4);
  });
  test(
    'selection clamps to visible results and resets on collection changes',
    () async {
      repository.snapshot = ClipboardSnapshot(clips: [item('a'), item('b')]);
      await load();
      final view = container.read(libraryViewProvider.notifier);
      expect(view.move(1), 1);
      expect(container.read(selectedItemProvider)?.id, 'b');
      expect(view.move(1), 1);
      expect(view.move(-1), 0);
      view.choose(const ClipboardCollection.snippets());
      expect(container.read(selectedItemProvider), isNull);
      expect(view.move(1), isNull);
    },
  );
  test('panel-open events preserve the presentation and can repeat', () async {
    await load();
    repository.opened(PanelPresentation.quick);
    repository.opened(PanelPresentation.quick);
    expect(container.read(panelSessionProvider).sequence, 2);
    expect(
      container.read(panelSessionProvider).presentation,
      PanelPresentation.quick,
    );
  });
  test(
    'provider disposal cancels its event subscription and ignores a late read',
    () async {
      final pending = Completer<ClipboardSnapshot>();
      repository.read = () => pending.future;
      container.read(clipboardControllerProvider);
      expect(repository.listeners, 1);
      container.dispose();
      expect(repository.listeners, 0);
      pending.complete(ClipboardSnapshot());
      await Future<void>.delayed(Duration.zero);
      // Avoid disposing the same container in teardown.
      container = ProviderContainer();
    },
  );
  test('model collections and image previews cannot be mutated externally', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final formats = ['text'];
    final clip = ClipItem(
      id: 'x',
      title: 'x',
      text: 'x',
      kind: 'image',
      source: 'test',
      snippet: false,
      date: DateTime(2026),
      size: 3,
      formats: formats,
      preview: bytes,
    );
    bytes[0] = 9;
    formats.add('html');
    expect(clip.preview!.first, 1);
    expect(clip.formats, ['text']);
    expect(() => clip.formats.add('other'), throwsUnsupportedError);
    expect(() => clip.preview![0] = 9, throwsUnsupportedError);
  });
  test(
    'quick-open resets view state without requiring a mounted widget',
    () async {
      await load();
      final view = container.read(libraryViewProvider.notifier);
      view.search('missing');
      view.choose(const ClipboardCollection.snippets());
      repository.opened(PanelPresentation.shelf);
      expect(container.read(libraryViewProvider).query, 'missing');
      repository.opened(PanelPresentation.quick);
      expect(container.read(libraryViewProvider).query, isEmpty);
      expect(
        container.read(libraryViewProvider).collection.kind,
        CollectionKind.history,
      );
    },
  );
  test('the most recent refresh wins when reads finish out of order', () async {
    await load();
    final first = Completer<ClipboardSnapshot>();
    final second = Completer<ClipboardSnapshot>();
    var reads = 0;
    repository.read = () => reads++ == 0 ? first.future : second.future;
    final controller = container.read(clipboardControllerProvider.notifier);
    final oldRequest = controller.refresh();
    final newRequest = controller.refresh();
    second.complete(ClipboardSnapshot(clips: [item('new')]));
    await newRequest;
    first.complete(ClipboardSnapshot(clips: [item('old')]));
    await oldRequest;
    expect(container.read(clipboardSnapshotProvider).clips.single.id, 'new');
  });
}

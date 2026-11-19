import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clipboard_item.dart';
import '../domain/clipboard_snapshot.dart';
import 'panel_session.dart';
import 'clipboard_controller.dart';

enum ItemFilter {
  all('All'),
  text('Text'),
  image('Image'),
  file('File'),
  other('Other');

  const ItemFilter(this.label);
  final String label;
  static ItemFilter fromLabel(String label) =>
      values.firstWhere((e) => e.label == label, orElse: () => all);
}

enum CollectionKind { history, snippets, board }

class ClipboardCollection {
  const ClipboardCollection.history()
    : kind = CollectionKind.history,
      boardID = null;
  const ClipboardCollection.snippets()
    : kind = CollectionKind.snippets,
      boardID = null;
  const ClipboardCollection.board(this.boardID) : kind = CollectionKind.board;
  factory ClipboardCollection.fromKey(String key) => switch (key) {
    'All items' => const ClipboardCollection.history(),
    'Snippets' => const ClipboardCollection.snippets(),
    _ => ClipboardCollection.board(key),
  };
  final CollectionKind kind;
  final String? boardID;
  String get key => switch (kind) {
    CollectionKind.history => 'All items',
    CollectionKind.snippets => 'Snippets',
    CollectionKind.board => boardID!,
  };
}

class LibraryViewState {
  const LibraryViewState({
    this.query = '',
    this.filter = ItemFilter.all,
    this.collection = const ClipboardCollection.history(),
    this.selectedID,
  });
  final String query;
  final ItemFilter filter;
  final ClipboardCollection collection;
  final String? selectedID;
  LibraryViewState copyWith({
    String? query,
    ItemFilter? filter,
    ClipboardCollection? collection,
    String? selectedID,
    bool clearSelection = false,
  }) => LibraryViewState(
    query: query ?? this.query,
    filter: filter ?? this.filter,
    collection: collection ?? this.collection,
    selectedID: clearSelection ? null : selectedID ?? this.selectedID,
  );
}

final libraryViewProvider =
    NotifierProvider<LibraryViewController, LibraryViewState>(
      LibraryViewController.new,
    );

class LibraryViewController extends Notifier<LibraryViewState> {
  @override
  LibraryViewState build() {
    ref.listen(panelSessionProvider, (previous, next) {
      if (!next.visible) return;
      if (next.presentation == PanelPresentation.quick) resetForQuickPanel();
      if (next.presentation == PanelPresentation.floating) {
        filter(ItemFilter.all);
      }
    });
    return const LibraryViewState();
  }

  void search(String query) => state = state.copyWith(query: query);
  void filter(ItemFilter filter) =>
      state = state.copyWith(filter: filter, clearSelection: true);
  void choose(ClipboardCollection collection) => state = state.copyWith(
    collection: collection,
    filter: ItemFilter.all,
    clearSelection: true,
  );
  void select(String id) => state = state.copyWith(selectedID: id);
  void resetForQuickPanel() => state = const LibraryViewState();
  int? move(int direction) {
    final items = filterClipboardItems(
      ref.read(clipboardSnapshotProvider).clips,
      state,
    );
    if (items.isEmpty) return null;
    final index = items.indexWhere((e) => e.id == state.selectedID);
    final next = ((index < 0 ? 0 : index) + direction).clamp(
      0,
      items.length - 1,
    );
    select(items[next].id);
    return next;
  }
}

List<ClipItem> filterClipboardItems(
  List<ClipItem> clips,
  LibraryViewState view,
) => List.unmodifiable(
  clips.where(
    (item) =>
        switch (view.collection.kind) {
          CollectionKind.history => !item.snippet,
          CollectionKind.snippets => item.snippet,
          CollectionKind.board => item.boardID == view.collection.boardID,
        } &&
        (view.filter == ItemFilter.all || item.kind == view.filter.name) &&
        item.matches(view.query),
  ),
);

final visibleItemsProvider = Provider<List<ClipItem>>((ref) {
  final clips = ref.watch(clipboardSnapshotProvider.select((s) => s.clips));
  final (query, filter, collection) = ref.watch(
    libraryViewProvider.select((s) => (s.query, s.filter, s.collection)),
  );
  return filterClipboardItems(
    clips,
    LibraryViewState(query: query, filter: filter, collection: collection),
  );
});
final selectedItemProvider = Provider<ClipItem?>((ref) {
  final items = ref.watch(visibleItemsProvider);
  final selected = ref.watch(libraryViewProvider.select((s) => s.selectedID));
  return items.where((e) => e.id == selected).firstOrNull ?? items.firstOrNull;
});

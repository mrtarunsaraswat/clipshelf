import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clipboard_item.dart';
import '../domain/clipboard_snapshot.dart';
import '../domain/search_token.dart';
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
    this.tokens = const [],
    this.searchOpen = false,
  });

  /// The shelf shows its search field in place of the collection tabs.
  final bool searchOpen;
  final String query;

  /// Filter chips in the search field (Link, Last week, Mail…).
  final List<SearchToken> tokens;
  final ItemFilter filter;
  final ClipboardCollection collection;
  final String? selectedID;
  LibraryViewState copyWith({
    String? query,
    ItemFilter? filter,
    ClipboardCollection? collection,
    String? selectedID,
    List<SearchToken>? tokens,
    bool? searchOpen,
    bool clearSelection = false,
  }) => LibraryViewState(
    searchOpen: searchOpen ?? this.searchOpen,
    tokens: tokens ?? this.tokens,
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

  /// Turns the typed fragment into a filter chip and clears the text.
  void addToken(SearchToken token) {
    if (state.tokens.contains(token)) return;
    state = state.copyWith(
      tokens: [...state.tokens, token],
      query: '',
      clearSelection: true,
    );
  }

  void removeToken(SearchToken token) => state = state.copyWith(
    tokens: [...state.tokens]..remove(token),
    clearSelection: true,
  );

  void openSearch() => state = state.copyWith(searchOpen: true);

  /// Closes search and drops its text and chips.
  void closeSearch() => state = state.copyWith(
    searchOpen: false,
    query: '',
    tokens: const [],
    clearSelection: true,
  );

  void clearSearch() =>
      state = state.copyWith(query: '', tokens: const [], clearSelection: true);

  /// Backspace in an empty search field removes the last chip.
  bool removeLastToken() {
    if (state.tokens.isEmpty) return false;
    removeToken(state.tokens.last);
    return true;
  }

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
  LibraryViewState view, {
  DateTime? now,
}) => List.unmodifiable(
  clips.where(
    (item) =>
        switch (view.collection.kind) {
          CollectionKind.history => !item.snippet,
          CollectionKind.snippets => item.snippet,
          CollectionKind.board => item.boardID == view.collection.boardID,
        } &&
        (view.filter == ItemFilter.all || item.kind == view.filter.name) &&
        matchesTokens(item, view.tokens, now ?? DateTime.now()) &&
        item.matches(view.query),
  ),
);

final visibleItemsProvider = Provider<List<ClipItem>>((ref) {
  final clips = ref.watch(clipboardSnapshotProvider.select((s) => s.clips));
  final (query, filter, collection, tokens) = ref.watch(
    libraryViewProvider.select(
      (s) => (s.query, s.filter, s.collection, s.tokens),
    ),
  );
  return filterClipboardItems(
    clips,
    LibraryViewState(
      query: query,
      filter: filter,
      collection: collection,
      tokens: tokens,
    ),
  );
});

/// Source app name → bundle ID, for app icons on filter chips.
final appBundleIDsProvider = Provider<Map<String, String>>((ref) {
  final clips = ref.watch(clipboardSnapshotProvider.select((s) => s.clips));
  return {
    for (final clip in clips.reversed)
      if (clip.sourceBundleID.isNotEmpty) clip.source: clip.sourceBundleID,
  };
});

/// Filter chips to offer for the text currently typed in search.
final searchSuggestionsProvider = Provider<List<SearchToken>>((ref) {
  final clips = ref.watch(clipboardSnapshotProvider.select((s) => s.clips));
  final (query, tokens) = ref.watch(
    libraryViewProvider.select((s) => (s.query, s.tokens)),
  );
  return suggestTokens(query, clips, tokens);
});
final selectedItemProvider = Provider<ClipItem?>((ref) {
  final items = ref.watch(visibleItemsProvider);
  final selected = ref.watch(libraryViewProvider.select((s) => s.selectedID));
  return items.where((e) => e.id == selected).firstOrNull ?? items.firstOrNull;
});

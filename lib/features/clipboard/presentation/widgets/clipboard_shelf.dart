import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/application/library_view_controller.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_style.dart';

import 'clipboard_card.dart';
import 'collection_tab.dart';
import 'empty_library.dart';

class ClipboardShelf extends ConsumerWidget {
  const ClipboardShelf({
    super.key,
    required this.actions,
    required this.search,
    required this.searchFocus,
    required this.libraryFocus,
    required this.listScroll,
  });
  final ClipboardActions actions;
  final TextEditingController search;
  final FocusNode searchFocus, libraryFocus;
  final ScrollController listScroll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(clipboardSnapshotProvider);
    final view = ref.watch(libraryViewProvider);
    final items = ref.watch(visibleItemsProvider);
    final selectedItem = ref.watch(selectedItemProvider);
    final current = ref.watch(selectedItemProvider);
    final filter = view.filter.label;
    final query = view.query;
    final boards = snapshot.boards;
    final paused = snapshot.paused;
    final warning = snapshot.warning;
    final loading = ref.watch(
      clipboardControllerProvider.select((s) => s.isLoading),
    );
    final syncEnabled = snapshot.sync.enabled;
    final syncStatus = snapshot.sync.message;
    final viewController = ref.read(libraryViewProvider.notifier);
    final section = view.collection.key;
    void chooseCollection(String key) =>
        viewController.choose(ClipboardCollection.fromKey(key));
    Widget tab(String value, String label, IconData icon, Color? color) =>
        CollectionTab(
          value: value,
          label: label,
          icon: icon,
          color: color,
          section: section,
          onSelected: chooseCollection,
        );
    final colors = context.shelf;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.strokeStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.layers_rounded, color: colors.accentText, size: 23),
                const SizedBox(width: 8),
                const Text(
                  'ClipShelf',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        tab(
                          'All items',
                          'Clipboard',
                          Icons.history_rounded,
                          null,
                        ),
                        const SizedBox(width: 6),
                        tab(
                          'Snippets',
                          'Snippets',
                          Icons.bookmark_outline,
                          null,
                        ),
                        for (final board in boards)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: DragTarget<String>(
                              onAcceptWithDetails: (details) =>
                                  actions.pin(details.data, board.id),
                              builder: (context, candidates, rejected) =>
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: candidates.isNotEmpty
                                          ? Border.all(
                                              color: colors.accentText,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: tab(
                                      board.id,
                                      board.name,
                                      Icons.circle,
                                      boardColor(colors, board.color),
                                    ),
                                  ),
                            ),
                          ),
                        IconButton(
                          tooltip: 'New pinboard',
                          onPressed: actions.showPinboardDialog,
                          icon: const Icon(Icons.add, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: paused ? 'Resume capture' : 'Pause capture',
                  onPressed: () => actions.toggleCapture(),
                  icon: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip: 'Preferences',
                  onPressed: actions.showPreferences,
                  icon: const Icon(Icons.tune, size: 19),
                ),
                IconButton(
                  tooltip: 'Hide shelf',
                  onPressed: () => actions.hide(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: search,
                      focusNode: searchFocus,
                      onChanged: (value) => viewController.search(value),
                      onSubmitted: (_) {
                        if (current != null) actions.paste(current);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search your clipboard…',
                        hintStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  search.clear();
                                  viewController.search('');
                                },
                                icon: const Icon(Icons.close, size: 15),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  tooltip: 'Filter by format',
                  initialValue: filter,
                  onSelected: (value) =>
                      viewController.filter(ItemFilter.fromLabel(value)),
                  itemBuilder: (_) => [
                    for (final value in [
                      'All',
                      'Text',
                      'Image',
                      'File',
                      'Other',
                    ])
                      PopupMenuItem(value: value, child: Text(value)),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.stroke),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          filter == 'All' ? 'All formats' : filter,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => actions.showSnippet(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'New snippet',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            if (warning.isNotEmpty || paused)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  paused
                      ? 'Capture paused — your saved items are still here.'
                      : warning,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.warningText),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const EmptyLibrary()
                  : Scrollbar(
                      controller: listScroll,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: listScroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 10),
                        itemCount: items.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) => SizedBox(
                          width: 248,
                          child: ClipboardCard(
                            item: items[index],
                            index: index,
                            active: selectedItem?.id == items[index].id,
                            boards: boards,
                            actions: actions,
                            onSelected: () {
                              viewController.select(items[index].id);
                              libraryFocus.requestFocus();
                            },
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  syncEnabled ? Icons.cloud_done_outlined : Icons.lock_outline,
                  size: 12,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    syncEnabled ? syncStatus : 'On this Mac · ⌥⌘V to open',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: colors.textTertiary),
                  ),
                ),
                Text(
                  '${items.length} items',
                  style: TextStyle(fontSize: 10, color: colors.textTertiary),
                ),
                const SizedBox(width: 20),
                Text(
                  '← → Navigate   ↵ Use   ⌘1–9 Quick use   esc Hide',
                  style: TextStyle(fontSize: 10, color: colors.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

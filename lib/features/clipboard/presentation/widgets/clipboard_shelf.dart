import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/app/widgets/toolbar_button.dart';
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
                Icon(Icons.layers_rounded, color: colors.accentText, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'ClipShelf',
                  style: TextStyle(
                    fontSize: ShelfType.title,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (paused) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warningSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Paused',
                      style: TextStyle(
                        fontSize: ShelfType.caption,
                        fontWeight: FontWeight.w600,
                        color: colors.warningText,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 20),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.surfaceHover,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              tab(
                                'All items',
                                'Clipboard',
                                Icons.history_rounded,
                                null,
                              ),
                              const SizedBox(width: 2),
                              tab(
                                'Snippets',
                                'Snippets',
                                Icons.bookmark_outline,
                                null,
                              ),
                              for (final board in boards)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: DragTarget<String>(
                                    onAcceptWithDetails: (details) =>
                                        actions.pin(details.data, board.id),
                                    builder: (context, candidates, rejected) =>
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          decoration: BoxDecoration(
                                            color: candidates.isNotEmpty
                                                ? colors.surfaceSelected
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'New pinboard',
                          style: toolbarButtonStyle(colors),
                          onPressed: actions.showPinboardDialog,
                          icon: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: paused ? 'Resume capture' : 'Pause capture',
                  style: toolbarButtonStyle(colors),
                  onPressed: () => actions.toggleCapture(),
                  icon: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 18,
                  ),
                ),
                IconButton(
                  tooltip: 'Preferences',
                  style: toolbarButtonStyle(colors),
                  onPressed: actions.showPreferences,
                  icon: const Icon(Icons.tune, size: 18),
                ),
                IconButton(
                  tooltip: 'Hide shelf',
                  style: toolbarButtonStyle(colors),
                  onPressed: () => actions.hide(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: search,
                      focusNode: searchFocus,
                      onChanged: (value) => viewController.search(value),
                      onSubmitted: (_) {
                        if (current != null) actions.paste(current);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search your clipboard…',
                        hintStyle: TextStyle(
                          fontSize: ShelfType.body,
                          color: colors.textTertiary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 17),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 20,
                        ),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  search.clear();
                                  viewController.search('');
                                },
                                icon: const Icon(Icons.close, size: 15),
                              )
                            : const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Keycap('⌘F', dense: true),
                              ),
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
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.stroke),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          filter == 'All' ? 'All formats' : filter,
                          style: const TextStyle(fontSize: ShelfType.meta),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more, size: 15),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => actions.showSnippet(),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surfaceSelected,
                    foregroundColor: colors.accentText,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'New snippet',
                    style: TextStyle(
                      fontSize: ShelfType.meta,
                      fontWeight: FontWeight.w600,
                    ),
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
                        padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
                        clipBehavior: Clip.none,
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
                    style: TextStyle(
                      fontSize: ShelfType.caption,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                Text(
                  '${items.length} items',
                  style: TextStyle(
                    fontSize: ShelfType.caption,
                    color: colors.textTertiary,
                  ),
                ),
                // Hints need ~430 pt; the window can be narrower while it
                // switches between shelf and panel layouts.
                if (MediaQuery.sizeOf(context).width >= 760) ...[
                  const SizedBox(width: 18),
                  const KeyHint(keys: ['←', '→'], label: 'Navigate'),
                  const SizedBox(width: 12),
                  const KeyHint(keys: ['return'], label: 'Use'),
                  const SizedBox(width: 12),
                  const KeyHint(keys: ['⌘1–9'], label: 'Quick use'),
                  const SizedBox(width: 12),
                  const KeyHint(keys: ['esc'], label: 'Hide'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

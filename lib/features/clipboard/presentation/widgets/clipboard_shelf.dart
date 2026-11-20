import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/app/widgets/toolbar_button.dart';
import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/application/library_view_controller.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_style.dart';

import 'animated_clip_list.dart';
import 'smart_search_field.dart';
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
    final searchOpen =
        view.searchOpen || view.query.isNotEmpty || view.tokens.isNotEmpty;
    // Drag a card onto a pinboard to pin it.
    Widget boardDropTarget(String boardID, Widget child) => DragTarget<String>(
      onAcceptWithDetails: (details) => actions.pin(details.data, boardID),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? colors.surfaceSelected
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: candidates.isNotEmpty
              ? Border.all(color: colors.accentText, width: 2)
              : null,
        ),
        child: child,
      ),
    );
    // While searching, collections shrink to icons and colour dots.
    Widget compactTab(String value, String label, IconData icon, Color? dot) {
      final selected = section == value;
      final button = IconButton(
        tooltip: label,
        style:
            toolbarButtonStyle(
              colors,
              foreground: selected ? colors.textPrimary : colors.textSecondary,
            ).copyWith(
              backgroundColor: WidgetStatePropertyAll(
                selected ? colors.surfaceHover : Colors.transparent,
              ),
            ),
        onPressed: () => chooseCollection(value),
        icon: dot == null
            ? Icon(icon, size: 17)
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
      );
      return dot == null ? button : boardDropTarget(value, button);
    }

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
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.97, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: searchOpen
                        ? Row(
                            key: const ValueKey('search'),
                            children: [
                              Expanded(
                                child: SmartSearchField(
                                  controller: search,
                                  focusNode: searchFocus,
                                  autofocus: true,
                                  hintText: 'Search',
                                  onSubmitted: () {
                                    if (current != null) actions.paste(current);
                                  },
                                  onClose: () {
                                    search.clear();
                                    viewController.closeSearch();
                                    libraryFocus.requestFocus();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              compactTab(
                                'All items',
                                'Clipboard',
                                Icons.history_rounded,
                                null,
                              ),
                              compactTab(
                                'Snippets',
                                'Snippets',
                                Icons.bookmark_outline,
                                null,
                              ),
                              for (final board in boards)
                                compactTab(
                                  board.id,
                                  board.name,
                                  Icons.circle,
                                  boardColor(colors, board.color),
                                ),
                            ],
                          )
                        : Center(
                            key: const ValueKey('tabs'),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Search (⌘F)',
                                    style: toolbarButtonStyle(colors),
                                    onPressed: viewController.openSearch,
                                    icon: const Icon(Icons.search, size: 19),
                                  ),
                                  const SizedBox(width: 6),
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
                                            padding: const EdgeInsets.only(
                                              left: 2,
                                            ),
                                            child: boardDropTarget(
                                              board.id,
                                              tab(
                                                board.id,
                                                board.name,
                                                Icons.circle,
                                                boardColor(colors, board.color),
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
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'New snippet (⌘N)',
                  style: toolbarButtonStyle(
                    colors,
                    foreground: colors.accentText,
                  ),
                  onPressed: () => actions.showSnippet(),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
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
                      child: AnimatedClipList(
                        items: items,
                        controller: listScroll,
                        extent: 248,
                        padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
                        itemBuilder: (context, item, index) => ClipboardCard(
                          item: item,
                          index: index,
                          active: selectedItem?.id == item.id,
                          boards: boards,
                          actions: actions,
                          onSelected: () {
                            viewController.select(item.id);
                            libraryFocus.requestFocus();
                          },
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
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/app/widgets/app_logo.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/app/widgets/toolbar_button.dart';
import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/application/library_view_controller.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_style.dart';

import 'animated_clip_list.dart';
import 'search_morph.dart';
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
            Center(child: _ShelfHandle(onClose: () => actions.hide())),
            const SizedBox(height: 6),
            Row(
              children: [
                const AppLogo(size: 24),
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
                  child: SearchMorph(
                    open: searchOpen,
                    onOpen: () {
                      viewController.openSearch();
                      // autofocus only works the first time; focus every open.
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => searchFocus.requestFocus(),
                      );
                    },
                    focusNode: searchFocus,
                    field: SmartSearchField(
                      controller: search,
                      focusNode: searchFocus,
                      autofocus: true,
                      bare: true,
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
                    compact: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                    ),
                    tabs: Row(
                      mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 10),
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
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 22),
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

/// The grip at the top of the shelf: click it, or drag it down, to close.
class _ShelfHandle extends StatefulWidget {
  const _ShelfHandle({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_ShelfHandle> createState() => _ShelfHandleState();
}

class _ShelfHandleState extends State<_ShelfHandle> {
  bool _hovered = false;
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Tooltip(
      message: 'Close (esc)',
      waitDuration: const Duration(milliseconds: 700),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          onVerticalDragStart: (_) => _drag = 0,
          onVerticalDragUpdate: (details) =>
              setState(() => _drag = (_drag + details.delta.dy).clamp(0, 40)),
          onVerticalDragEnd: (details) {
            final flung = (details.primaryVelocity ?? 0) > 300;
            if (_drag > 18 || flung) widget.onClose();
            setState(() => _drag = 0);
          },
          child: SizedBox(
            width: 96,
            height: 16,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                transform: Matrix4.translationValues(0, _drag / 3, 0),
                width: _hovered ? 44 : 36,
                height: 5,
                decoration: BoxDecoration(
                  color: _hovered ? colors.textTertiary : colors.strokeStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

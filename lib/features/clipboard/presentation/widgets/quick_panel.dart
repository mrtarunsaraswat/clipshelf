import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/app/widgets/toolbar_button.dart';
import 'package:clipshelf/features/clipboard/application/clipboard_controller.dart';
import 'package:clipshelf/features/clipboard/application/library_view_controller.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';

import '../../domain/clipboard_snapshot.dart';
import 'quick_item_row.dart';
import 'empty_library.dart';

class QuickPanel extends ConsumerWidget {
  const QuickPanel({
    super.key,
    required this.actions,
    required this.search,
    required this.searchFocus,
    required this.listScroll,
  });
  final ClipboardActions actions;
  final TextEditingController search;
  final FocusNode searchFocus;
  final ScrollController listScroll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(clipboardSnapshotProvider);
    final floating = snapshot.presentation == PanelPresentation.floating;
    final view = ref.watch(libraryViewProvider);
    final items = ref.watch(visibleItemsProvider);
    final current = ref.watch(selectedItemProvider);
    final section = view.collection.key;
    final query = view.query;
    final boards = snapshot.boards;
    final paused = snapshot.paused;
    final accessibility = snapshot.accessibility;
    final warning = snapshot.warning;
    final loading = ref.watch(
      clipboardControllerProvider.select((s) => s.isLoading),
    );
    final viewController = ref.read(libraryViewProvider.notifier);
    void chooseCollection(String key) => ref
        .read(libraryViewProvider.notifier)
        .choose(ClipboardCollection.fromKey(key));
    final label = section == 'All items'
        ? 'History'
        : section == 'Snippets'
        ? 'Snippets'
        : boards.where((b) => b.id == section).firstOrNull?.name ?? 'History';
    final colors = context.shelf;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                Icon(Icons.layers_rounded, color: colors.accentText, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Listener(
                    onPointerDown: floating
                        ? (_) => actions.dragFloating()
                        : null,
                    child: MouseRegion(
                      cursor: floating
                          ? SystemMouseCursors.move
                          : SystemMouseCursors.basic,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          floating ? 'ClipShelf · Floating' : 'ClipShelf',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: floating ? 14 : ShelfType.title,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (floating)
                  IconButton(
                    style: toolbarButtonStyle(colors),
                    tooltip: snapshot.floatingPinned
                        ? 'Keep visible: on'
                        : 'Keep visible: off',
                    onPressed: () =>
                        actions.setFloatingPinned(!snapshot.floatingPinned),
                    icon: Icon(
                      snapshot.floatingPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 18,
                      color: snapshot.floatingPinned ? colors.accentText : null,
                    ),
                  ),
                // New snippet is a primary action: keep it one click away
                // instead of only in the More menu.
                IconButton(
                  style: toolbarButtonStyle(
                    colors,
                    foreground: colors.accentText,
                  ),
                  tooltip: 'New snippet (⌘N)',
                  onPressed: () => actions.showSnippet(),
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
                IconButton(
                  style: toolbarButtonStyle(colors),
                  tooltip: 'Open full shelf',
                  onPressed: () => actions.showShelf(),
                  icon: const Icon(Icons.view_carousel_outlined, size: 18),
                ),
                IconButton(
                  style: toolbarButtonStyle(colors),
                  tooltip: 'Preferences',
                  onPressed: actions.showPreferences,
                  icon: const Icon(Icons.tune, size: 18),
                ),
                if (floating)
                  IconButton(
                    style: toolbarButtonStyle(colors),
                    tooltip: 'Close panel',
                    onPressed: actions.hide,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  onSelected: (value) {
                    if (value == 'floating') actions.showFloating();
                    if (value == 'pause') actions.toggleCapture();
                    if (value == 'clear') actions.clearHistory();
                    if (value == 'snippet') actions.showSnippet();
                    if (value == 'quit') actions.quit();
                  },
                  itemBuilder: (_) => [
                    if (!floating)
                      const PopupMenuItem(
                        value: 'floating',
                        child: Text('Open floating panel'),
                      ),
                    PopupMenuItem(
                      value: 'pause',
                      child: Text(paused ? 'Resume capture' : 'Pause capture'),
                    ),
                    const PopupMenuItem(
                      value: 'snippet',
                      child: Text('New snippet'),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text('Clear history'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'quit',
                      child: Text('Quit ClipShelf'),
                    ),
                  ],
                  icon: const Icon(Icons.more_horiz, size: 19),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: search,
                focusNode: searchFocus,
                onChanged: (value) => viewController.search(value),
                onSubmitted: (_) {
                  if (current != null) actions.paste(current);
                },
                decoration: InputDecoration(
                  hintText: 'Search clipboard history',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            search.clear();
                            viewController.search('');
                          },
                          icon: const Icon(Icons.close, size: 15),
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Choose collection',
                  onSelected: chooseCollection,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'All items',
                      child: Text('History'),
                    ),
                    const PopupMenuItem(
                      value: 'Snippets',
                      child: Text('Snippets'),
                    ),
                    for (final board in boards)
                      PopupMenuItem(value: board.id, child: Text(board.name)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 15),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} items',
                  style: TextStyle(
                    fontSize: ShelfType.caption,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (!accessibility)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                decoration: BoxDecoration(
                  color: colors.warningSurface,
                  borderRadius: BorderRadius.circular(ShelfRadius.sm + 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: colors.warningText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enable Accessibility for one-click paste.\nUntil then, items are copied for manual paste.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: colors.warningText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await actions.requestAccessibility();
                      },
                      child: const Text(
                        'Allow',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (paused || warning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                paused ? 'Capture paused' : warning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: colors.warningText),
              ),
            ),
          Divider(height: 1, color: colors.stroke),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? const EmptyLibrary()
                : Scrollbar(
                    controller: listScroll,
                    child: ListView.separated(
                      controller: listScroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 2),
                      itemBuilder: (context, index) => QuickItemRow(
                        item: items[index],
                        index: index,
                        active: current?.id == items[index].id,
                        actions: actions,
                        boards: boards,
                        onSelected: () =>
                            viewController.select(items[index].id),
                      ),
                    ),
                  ),
          ),
          Divider(height: 1, color: colors.stroke),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    floating && snapshot.floatingPinned
                        ? 'Keep visible · Click to paste'
                        : 'Click an item to paste',
                    style: TextStyle(
                      fontSize: ShelfType.caption,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                const KeyHint(keys: ['⌘1–9'], label: ''),
                const SizedBox(width: 6),
                const KeyHint(keys: ['esc'], label: ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

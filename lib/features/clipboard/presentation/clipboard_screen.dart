import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/clipboard_controller.dart';
import '../application/library_view_controller.dart';
import '../application/panel_session.dart';
import '../domain/clipboard_snapshot.dart';
import 'clipboard_actions.dart';
import 'widgets/clipboard_shelf.dart';
import 'widgets/quick_panel.dart';

/// Owns only widget resources; all shared state lives in providers.
class ClipboardScreen extends ConsumerStatefulWidget {
  const ClipboardScreen({super.key});
  @override
  ConsumerState<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends ConsumerState<ClipboardScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _libraryFocus = FocusNode();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _libraryFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    final index = ref.read(libraryViewProvider.notifier).move(direction);
    if (index == null || !_scroll.hasClients) return;
    final quick =
        ref.read(clipboardSnapshotProvider).presentation !=
        PanelPresentation.shelf;
    _scroll.animateTo(
      // Quick rows are 64 pt plus a 2 pt gap; shelf cards 248 pt plus 14.
      (index * (quick ? 66.0 : 262.0)).clamp(
        0,
        _scroll.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = ClipboardActions(context, ref);
    ref.listen(libraryViewProvider.select((s) => s.query), (previous, query) {
      if (_search.text != query) {
        _search.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
      }
    });
    ref.listen(panelSessionProvider, (previous, next) {
      // Menus belong to the visible panel session. Keep Preferences/editor dialogs,
      // but never reveal a menu left behind when the native window was hidden.
      Navigator.of(context)
          .popUntil((route) => route is! PopupRoute || route is DialogRoute);
      if (!next.visible) {
        _searchFocus.unfocus();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref.read(panelSessionProvider).sequence != next.sequence) {
          return;
        }
        _searchFocus.requestFocus();
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    });
    ref.listen(quickUseRequestProvider, (previous, request) {
      if (request == null) return;
      final visible = ref.read(visibleItemsProvider);
      if (request.index >= 0 && request.index < visible.length) {
        actions.paste(visible[request.index]);
      }
    });
    final items = ref.watch(visibleItemsProvider);
    final current = ref.watch(selectedItemProvider);
    final quick = ref.watch(
      clipboardSnapshotProvider.select(
        (s) => s.presentation != PanelPresentation.shelf,
      ),
    );
    const numbers = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): actions.hide,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            actions.showSnippet(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
            actions.showPinboardDialog,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (current != null) actions.paste(current);
        },
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (current != null) actions.showPreview(current);
        },
        for (var i = 0; i < numbers.length; i++)
          SingleActivator(numbers[i], meta: true): () {
            if (i < items.length) actions.paste(items[i]);
          },
      },
      child: Focus(
        focusNode: _libraryFocus,
        autofocus: true,
        child: quick
            ? QuickPanel(
                actions: actions,
                search: _search,
                searchFocus: _searchFocus,
                listScroll: _scroll,
              )
            : ClipboardShelf(
                actions: actions,
                search: _search,
                searchFocus: _searchFocus,
                libraryFocus: _libraryFocus,
                listScroll: _scroll,
              ),
      ),
    );
  }
}

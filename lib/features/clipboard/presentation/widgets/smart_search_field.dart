import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tokens.dart';
import '../../../../app/widgets/keycap.dart';
import '../../application/library_view_controller.dart';
import '../../domain/search_token.dart';

/// Search field with filter chips. Typing offers filters (Link, Last week,
/// Mail…); click one or press Tab to take the first. Backspace in an empty
/// field removes the last chip.
class SmartSearchField extends ConsumerStatefulWidget {
  const SmartSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmitted,
    this.suffixIcon,
    this.height = 36,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onSubmitted;
  final Widget? suffixIcon;
  final double height;

  @override
  ConsumerState<SmartSearchField> createState() => _SmartSearchFieldState();
}

class _SmartSearchFieldState extends ConsumerState<SmartSearchField> {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKeyEvent = _onKey;
    widget.focusNode.addListener(_sync);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    if (widget.focusNode.onKeyEvent == _onKey) {
      widget.focusNode.onKeyEvent = null;
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final view = ref.read(libraryViewProvider.notifier);
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        widget.controller.text.isEmpty &&
        view.removeLastToken()) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final suggestions = ref.read(searchSuggestionsProvider);
      if (suggestions.isNotEmpty) {
        _pick(suggestions.first);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _pick(SearchToken token) {
    ref.read(libraryViewProvider.notifier).addToken(token);
    widget.controller.clear();
    widget.focusNode.requestFocus();
  }

  /// Shows the suggestion list only while focused and there is something to offer.
  void _sync() {
    if (!mounted) return;
    final show =
        widget.focusNode.hasFocus &&
        ref.read(searchSuggestionsProvider).isNotEmpty;
    if (show && !_overlay.isShowing) _overlay.show();
    if (!show && _overlay.isShowing) _overlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final tokens = ref.watch(libraryViewProvider.select((s) => s.tokens));
    final suggestions = ref.watch(searchSuggestionsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    final hasFilters = tokens.isNotEmpty || widget.controller.text.isNotEmpty;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(28, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: _Suggestions(suggestions: suggestions, onPick: _pick),
          ),
        ),
        child: SizedBox(
          height: widget.height,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: (value) =>
                ref.read(libraryViewProvider.notifier).search(value),
            onSubmitted: (_) => widget.onSubmitted(),
            style: const TextStyle(fontSize: ShelfType.body),
            decoration: InputDecoration(
              hintText: tokens.isEmpty ? widget.hintText : null,
              hintStyle: TextStyle(
                fontSize: ShelfType.body,
                color: colors.textTertiary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              prefixIconConstraints: BoxConstraints(
                minHeight: widget.height,
                maxWidth: 420,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 17, color: colors.textTertiary),
                      for (final token in tokens)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _Chip(
                            token: token,
                            onRemove: () => ref
                                .read(libraryViewProvider.notifier)
                                .removeToken(token),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 20,
              ),
              suffixIcon: hasFilters
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        widget.controller.clear();
                        final view = ref.read(libraryViewProvider.notifier);
                        view.search('');
                        for (final token in [...tokens]) {
                          view.removeToken(token);
                        }
                      },
                      icon: const Icon(Icons.close, size: 15),
                    )
                  : widget.suffixIcon,
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(SearchToken token) => switch (token.group) {
  SearchTokenGroup.kind => switch (token.value) {
    'link' => Icons.link_rounded,
    'image' => Icons.image_outlined,
    'file' => Icons.insert_drive_file_outlined,
    'snippet' => Icons.bookmark_outline,
    _ => Icons.notes_rounded,
  },
  SearchTokenGroup.date => Icons.calendar_today_outlined,
  SearchTokenGroup.app => Icons.apps_rounded,
};

class _Chip extends StatelessWidget {
  const _Chip({required this.token, required this.onRemove});
  final SearchToken token;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: 7, right: 2),
      decoration: BoxDecoration(
        color: colors.surfaceSelected,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(token), size: 13, color: colors.accentText),
          const SizedBox(width: 4),
          Text(
            token.label,
            style: TextStyle(
              fontSize: ShelfType.meta,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          InkResponse(
            onTap: onRemove,
            radius: 10,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close, size: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onPick});
  final List<SearchToken> suggestions;
  final ValueChanged<SearchToken> onPick;

  static String _groupLabel(SearchTokenGroup group) => switch (group) {
    SearchTokenGroup.kind => 'Type',
    SearchTokenGroup.date => 'Date',
    SearchTokenGroup.app => 'App',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final surface = Theme.of(context).dialogTheme.backgroundColor;
    return Material(
      color: surface,
      elevation: 10,
      shadowColor: colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShelfRadius.sm + 2),
        side: BorderSide(color: colors.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < suggestions.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onPick(suggestions[i]),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: i == 0
                        ? BoxDecoration(
                            color: colors.surfaceSelected,
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Row(
                      children: [
                        Icon(
                          _iconFor(suggestions[i]),
                          size: 15,
                          color: colors.accentText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestions[i].label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ShelfType.body,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (i == 0)
                          const Keycap('tab', dense: true)
                        else
                          Text(
                            _groupLabel(suggestions[i].group),
                            style: TextStyle(
                              fontSize: ShelfType.caption,
                              color: colors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

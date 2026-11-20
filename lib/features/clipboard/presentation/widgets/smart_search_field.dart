import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tokens.dart';
import '../../application/library_view_controller.dart';
import '../../data/clip_media.dart';
import '../../domain/search_token.dart';

/// Capsule search field with filter chips.
///
/// Typing offers filters (Link, Last week, Mail…) in a menu right under the
/// typed text: ↑/↓ to move, Return or Tab to add the highlighted one, or click.
/// Backspace in an empty field removes the last chip. Escape closes the menu,
/// then clears the search, then calls [onClose] (the shelf collapses search).
class SmartSearchField extends ConsumerStatefulWidget {
  const SmartSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.hintText = 'Search',
    this.onClose,
    this.height = 34,
    this.autofocus = false,
    this.bare = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback? onClose;
  final String hintText;
  final double height;
  final bool autofocus;

  /// No border or fill: an outer capsule (the shelf's SearchMorph) draws them.
  final bool bare;

  @override
  ConsumerState<SmartSearchField> createState() => _SmartSearchFieldState();
}

class _SmartSearchFieldState extends ConsumerState<SmartSearchField> {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();
  final _prefixKey = GlobalKey();
  int _highlight = 0;

  /// Set by Escape so the menu stays closed until the text changes.
  bool _dismissed = false;

  /// True while the ≡ filter menu is open, which takes focus from the field
  /// but must not count as clicking away.
  bool _filterMenuOpen = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKeyEvent = _onKey;
    widget.focusNode.addListener(_sync);
    widget.focusNode.addListener(_collapseWhenLeftEmpty);
  }

  /// Clicking away from an empty search collapses it (when it can collapse).
  void _collapseWhenLeftEmpty() {
    if (widget.onClose == null || widget.focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.focusNode.hasFocus || _filterMenuOpen) return;
      final state = ref.read(libraryViewProvider);
      if (state.query.isEmpty && state.tokens.isEmpty) widget.onClose?.call();
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    widget.focusNode.removeListener(_collapseWhenLeftEmpty);
    if (widget.focusNode.onKeyEvent == _onKey) {
      widget.focusNode.onKeyEvent = null;
    }
    super.dispose();
  }

  List<SearchToken> get _suggestions => ref.read(searchSuggestionsProvider);
  bool get _menuOpen => _overlay.isShowing && _suggestions.isNotEmpty;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final view = ref.read(libraryViewProvider.notifier);
    final suggestions = _suggestions;
    if (_menuOpen) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(() => _highlight = (_highlight + step) % suggestions.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.tab) {
        _pick(suggestions[_highlight.clamp(0, suggestions.length - 1)]);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.backspace &&
        widget.controller.text.isEmpty &&
        view.removeLastToken()) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_menuOpen) {
        setState(() => _dismissed = true);
        _sync();
        return KeyEventResult.handled;
      }
      final state = ref.read(libraryViewProvider);
      if (state.query.isNotEmpty || state.tokens.isNotEmpty) {
        _clear();
        return KeyEventResult.handled;
      }
      if (widget.onClose != null) {
        widget.onClose!();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _pick(SearchToken token) {
    ref.read(libraryViewProvider.notifier).addToken(token);
    widget.controller.clear();
    setState(() => _highlight = 0);
    widget.focusNode.requestFocus();
  }

  void _clear() {
    widget.controller.clear();
    ref.read(libraryViewProvider.notifier).clearSearch();
  }

  /// The menu shows only while focused, not dismissed, and with something to offer.
  void _sync() {
    if (!mounted) return;
    final show =
        widget.focusNode.hasFocus && !_dismissed && _suggestions.isNotEmpty;
    if (show && !_overlay.isShowing) _overlay.show();
    if (!show && _overlay.isShowing) _overlay.hide();
  }

  /// Left edge of the typed text, so the menu opens right under it.
  double _textStart() {
    final box = _prefixKey.currentContext?.findRenderObject() as RenderBox?;
    return (box?.size.width ?? 30) + 4;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final tokens = ref.watch(libraryViewProvider.select((s) => s.tokens));
    final suggestions = ref.watch(searchSuggestionsProvider);
    if (_highlight >= suggestions.length) _highlight = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    final hasContent = tokens.isNotEmpty || widget.controller.text.isNotEmpty;
    final radius = BorderRadius.circular(widget.height / 2);
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: Offset(_textStart() - 8, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: _SuggestionMenu(
              suggestions: suggestions,
              highlight: _highlight,
              onHover: (index) => setState(() => _highlight = index),
              onPick: _pick,
            ),
          ),
        ),
        child: SizedBox(
          height: widget.height,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            // The field is taller than one line of text (it matches the
            // capsule and prefix height); keep the text and caret centred.
            textAlignVertical: TextAlignVertical.center,
            onChanged: (value) {
              setState(() {
                _highlight = 0;
                _dismissed = false;
              });
              ref.read(libraryViewProvider.notifier).search(value);
            },
            onSubmitted: (_) => widget.onSubmitted(),
            // A click anywhere else closes an empty search.
            onTapOutside: (_) {
              final state = ref.read(libraryViewProvider);
              if (widget.onClose != null &&
                  !_filterMenuOpen &&
                  state.query.isEmpty &&
                  state.tokens.isEmpty) {
                widget.onClose!();
              }
            },
            style: const TextStyle(fontSize: ShelfType.body),
            decoration: InputDecoration(
              hintText: tokens.isEmpty ? widget.hintText : null,
              hintStyle: TextStyle(
                fontSize: ShelfType.body,
                color: colors.textTertiary,
              ),
              filled: !widget.bare,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: widget.bare
                  ? InputBorder.none
                  : OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(color: colors.stroke),
                    ),
              enabledBorder: widget.bare
                  ? InputBorder.none
                  : OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(color: colors.stroke),
                    ),
              focusedBorder: widget.bare
                  ? InputBorder.none
                  : OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(color: colors.accent, width: 2),
                    ),
              prefixIconConstraints: BoxConstraints(
                minHeight: widget.height,
                maxWidth: 460,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 11, right: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    key: _prefixKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 17, color: colors.textSecondary),
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
              suffixIconConstraints: const BoxConstraints(minHeight: 20),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FilterButton(
                      onPick: _pick,
                      onOpenChanged: (open) => _filterMenuOpen = open,
                    ),
                    // ✕ clears; with nothing to clear it closes search.
                    if (hasContent)
                      _FieldButton(
                        tooltip: 'Clear search',
                        icon: Icons.cancel,
                        onPressed: _clear,
                      )
                    else if (widget.onClose != null)
                      _FieldButton(
                        tooltip: 'Close search',
                        icon: Icons.close_rounded,
                        onPressed: widget.onClose!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData tokenIcon(SearchToken token) => switch (token.group) {
  SearchTokenGroup.kind => switch (token.value) {
    'link' => Icons.link_rounded,
    'image' => Icons.image_outlined,
    'file' => Icons.insert_drive_file_outlined,
    'snippet' => Icons.bookmark_outline,
    _ => Icons.notes_rounded,
  },
  SearchTokenGroup.date => Icons.calendar_month_outlined,
  SearchTokenGroup.app => Icons.apps_rounded,
};

/// A token's icon: the real app icon for apps, a glyph otherwise.
class TokenIcon extends ConsumerWidget {
  const TokenIcon(this.token, {super.key, this.size = 14, this.color});
  final SearchToken token;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Uint8List? appIcon;
    if (token.group == SearchTokenGroup.app) {
      final bundleID = ref.watch(appBundleIDsProvider)[token.value] ?? '';
      appIcon = ref.watch(appIconProvider(bundleID)).value;
    }
    if (appIcon != null) {
      return Image.memory(
        appIcon,
        width: size + 2,
        height: size + 2,
        gaplessPlayback: true,
      );
    }
    return Icon(
      tokenIcon(token),
      size: size,
      color: color ?? context.shelf.textSecondary,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.token, required this.onRemove});
  final SearchToken token;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Tooltip(
      message: 'Remove ${token.label} filter',
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: colors.strokeStrong,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TokenIcon(token, size: 12),
              const SizedBox(width: 4),
              Text(
                token.label,
                style: TextStyle(
                  fontSize: ShelfType.meta,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: 16,
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      foregroundColor: context.shelf.textTertiary,
      minimumSize: const Size(26, 26),
      fixedSize: const Size(26, 26),
      padding: EdgeInsets.zero,
    ),
    icon: Icon(icon),
  );
}

/// The ≡ button: every type and date filter, for when you'd rather click.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onPick, required this.onOpenChanged});
  final ValueChanged<SearchToken> onPick;
  final ValueChanged<bool> onOpenChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<SearchToken>(
    tooltip: 'Filters',
    onOpened: () => onOpenChanged(true),
    onCanceled: () => onOpenChanged(false),
    onSelected: (token) {
      onOpenChanged(false);
      onPick(token);
    },
    position: PopupMenuPosition.under,
    itemBuilder: (_) => [
      for (final token in SearchToken.kinds) _item(token),
      const PopupMenuDivider(),
      for (final token in SearchToken.dates) _item(token),
    ],
    child: SizedBox(
      width: 26,
      height: 26,
      child: Icon(
        Icons.filter_list_rounded,
        size: 17,
        color: context.shelf.textSecondary,
      ),
    ),
  );

  PopupMenuItem<SearchToken> _item(SearchToken token) => PopupMenuItem(
    value: token,
    height: 32,
    child: Row(
      children: [
        TokenIcon(token, size: 15),
        const SizedBox(width: 10),
        Text(token.label),
      ],
    ),
  );
}

class _SuggestionMenu extends StatelessWidget {
  const _SuggestionMenu({
    required this.suggestions,
    required this.highlight,
    required this.onHover,
    required this.onPick,
  });
  final List<SearchToken> suggestions;
  final int highlight;
  final ValueChanged<int> onHover;
  final ValueChanged<SearchToken> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Material(
      color: Theme.of(context).dialogTheme.backgroundColor,
      elevation: 4,
      shadowColor: colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShelfRadius.sm + 2),
        side: BorderSide(color: colors.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 168, maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < suggestions.length; i++)
                  MouseRegion(
                    onEnter: (_) => onHover(i),
                    child: GestureDetector(
                      onTap: () => onPick(suggestions[i]),
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: i == highlight ? colors.accent : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            TokenIcon(
                              suggestions[i],
                              size: 15,
                              color: i == highlight
                                  ? colors.onAccent
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              suggestions[i].label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ShelfType.body,
                                color: i == highlight
                                    ? colors.onAccent
                                    : colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

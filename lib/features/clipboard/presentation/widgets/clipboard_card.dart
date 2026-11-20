import 'package:flutter/material.dart';
import 'package:clipshelf/app/tokens.dart';
import 'package:clipshelf/app/widgets/hover_surface.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/domain/pinboard.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_style.dart';
import 'package:clipshelf/features/clipboard/presentation/widgets/item_context_menu.dart';

class ClipboardCard extends StatelessWidget {
  const ClipboardCard({
    super.key,
    required this.item,
    required this.index,
    required this.active,
    required this.actions,
    required this.boards,
    required this.onSelected,
  });
  final ClipItem item;
  final int index;
  final bool active;
  final ClipboardActions actions;
  final List<Pinboard> boards;
  final VoidCallback onSelected;

  String get _kindLabel => item.snippet
      ? 'Snippet'
      : isLink(item)
      ? 'Link'
      : switch (item.kind) {
          'text' => 'Text',
          'image' => 'Image',
          'file' => 'File',
          _ => 'Content',
        };

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final tint = cardColor(item, boards, colors);
    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onSelected();
          actions.paste(item);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: _CardBody(item: item, tint: tint),
        ),
      ),
    );
    return GestureDetector(
      onSecondaryTapDown: (details) async {
        final value = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            0,
            0,
          ),
          items: itemContextMenu(item, boards, colors),
        );
        if (value != null) actions.handleItem(value, item);
      },
      child: HoverSurface(
        selected: active,
        lift: true,
        border: true,
        radius: 14,
        color: colors.surfaceRaised,
        hoverColor: colors.surfaceRaised,
        selectedColor: colors.surfaceRaised,
        builder: (context, hovered) => ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: tint),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                      child: Row(
                        children: [
                          _KindChip(
                            icon: clipIcon(item),
                            label: _kindLabel,
                            tint: tint,
                          ),
                          const Spacer(),
                          if (index < 9) Keycap('⌘${index + 1}', dense: true),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: hovered || active ? 1 : 0,
                            child: PopupMenuButton<String>(
                              tooltip: 'Item actions',
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              onSelected: (value) =>
                                  actions.handleItem(value, item),
                              itemBuilder: (_) =>
                                  itemContextMenu(item, boards, colors),
                              icon: Icon(
                                Icons.more_horiz,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Draggable<String>(
                        data: item.id,
                        feedback: _DragFeedback(item: item, tint: tint),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: content,
                        ),
                        child: content,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Text(
                        '${item.source} · ${formatClipAge(item.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ShelfType.caption,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.icon,
    required this.label,
    required this.tint,
  });
  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
    decoration: BoxDecoration(
      color: tint.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tint),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: ShelfType.caption,
            fontWeight: FontWeight.w600,
            color: tint,
          ),
        ),
      ],
    ),
  );
}

/// Content area, shaped by what was copied.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.item, required this.tint});
  final ClipItem item;
  final Color tint;

  static bool _looksLikeCode(String text) =>
      text.contains('{') ||
      text.contains('=>') ||
      RegExp(
        r'^\s*(import|const|final|let|var|def|func|class)\s',
        multiLine: true,
      ).hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    if (item.preview != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(ShelfRadius.sm),
        child: ColoredBox(
          color: colors.surfaceHover,
          child: Image.memory(
            item.preview!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, error, stack) =>
                Icon(Icons.image_not_supported, color: colors.textTertiary),
          ),
        ),
      );
    }
    final text = item.text.isNotEmpty ? item.text : item.title;
    final link = isLink(item) ? Uri.tryParse(item.text.trim()) : null;
    final code = link == null && _looksLikeCode(text);
    return LayoutBuilder(
      builder: (context, size) {
        final lineHeight = code ? 18.0 : 19.0;
        final reserved = link != null ? 24.0 : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (link != null && link.host.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.public, size: 14, color: tint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        link.host.replaceFirst(RegExp(r'^www\.'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ShelfType.meta,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              text,
              maxLines: ((size.maxHeight - reserved) / lineHeight)
                  .floor()
                  .clamp(1, 20),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: code ? ShelfType.meta : ShelfType.body,
                height: code ? 1.5 : 1.45,
                color: link != null ? colors.textSecondary : colors.textPrimary,
                fontFamily: code ? ShelfType.monoFamily : null,
                fontFamilyFallback: code
                    ? const ['Menlo', ...ShelfType.fallback]
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.item, required this.tint});
  final ClipItem item;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(ShelfRadius.md),
          border: Border.all(color: tint, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          item.title,
          maxLines: 3,
          style: TextStyle(color: colors.textPrimary, fontSize: ShelfType.body),
        ),
      ),
    );
  }
}

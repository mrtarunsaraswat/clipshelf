import 'package:flutter/material.dart';
import 'package:clipshelf/app/tokens.dart';
import 'package:clipshelf/app/widgets/hover_surface.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/domain/pinboard.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_style.dart';
import 'package:clipshelf/features/clipboard/presentation/widgets/item_context_menu.dart';

/// One history row in the menu-bar and floating panels, Spotlight-style.
class QuickItemRow extends StatelessWidget {
  const QuickItemRow({
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

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final tint = cardColor(item, boards, colors);
    return HoverSurface(
      selected: active,
      radius: ShelfRadius.sm + 2,
      selectedColor: colors.surfaceSelected,
      builder: (context, hovered) => Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('quick-item-${item.id}'),
          borderRadius: BorderRadius.circular(ShelfRadius.sm + 2),
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: colors.surfaceHover,
          onTap: () {
            onSelected();
            actions.paste(item);
          },
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
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  // Images show their thumbnail where other rows show a
                  // type icon, so the text beside it can describe them.
                  if (item.preview != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 56,
                        height: 42,
                        color: colors.surfaceHover,
                        child: Image.memory(
                          item.preview!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, error, stack) =>
                              Icon(clipIcon(item), size: 17, color: tint),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(ShelfRadius.sm),
                      ),
                      child: Icon(clipIcon(item), size: 17, color: tint),
                    ),
                  SizedBox(width: item.preview != null ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ShelfType.body,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            item.source,
                            formatClipAge(item.date),
                            if (item.pixelWidth > 0)
                              '${item.pixelWidth} × ${item.pixelHeight}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ShelfType.caption,
                            color: colors.textTertiary,
                            fontFeatures: ShelfType.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < 9)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Keycap('⌘${index + 1}', dense: true),
                    ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: hovered || active ? 1 : 0,
                    child: IconButton(
                      tooltip: 'Copy to clipboard',
                      onPressed: () => actions.copy(item),
                      style: IconButton.styleFrom(
                        hoverColor: colors.surfaceHover,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.copy_outlined,
                        size: 16,
                        color: colors.accentText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

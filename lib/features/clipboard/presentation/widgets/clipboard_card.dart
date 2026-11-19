import 'package:flutter/material.dart';
import 'package:clipshelf/app/theme.dart';
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
  @override
  Widget build(BuildContext context) {
    final color = cardColor(item, boards);
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onSelected();
          actions.paste(item);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: item.preview != null
              ? Image.memory(
                  item.preview!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) =>
                      const Icon(Icons.image_not_supported),
                )
              : LayoutBuilder(
                  builder: (context, size) => Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      item.text.isNotEmpty ? item.text : item.title,
                      maxLines: (size.maxHeight / 20).floor().clamp(1, 20),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: const Color(0xFF344454),
                        fontFamily: item.text.contains('{')
                            ? 'monospace'
                            : null,
                      ),
                    ),
                  ),
                ),
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
          items: itemContextMenu(item, boards),
        );
        if (value != null) actions.handleItem(value, item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? accent : const Color(0xFFDDE1E6),
            width: active ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: color,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 3),
                  child: Row(
                    children: [
                      Icon(clipIcon(item), size: 17, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.snippet
                              ? 'Snippet'
                              : item.kind == 'text'
                              ? 'Text'
                              : item.kind == 'image'
                              ? 'Image'
                              : item.kind == 'file'
                              ? 'File'
                              : 'Content',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Item actions',
                        onSelected: (value) => actions.handleItem(value, item),
                        itemBuilder: (_) => itemContextMenu(item, boards),
                        icon: const Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Draggable<String>(
                data: item.id,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.title,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: content),
                child: content,
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDF0F3)),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 11, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.source} · ${formatClipAge(item.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                  if (index < 9)
                    Text(
                      '⌘${index + 1}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

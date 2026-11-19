import 'package:flutter/material.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/domain/pinboard.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_style.dart';
import 'package:clipshelf/features/clipboard/presentation/widgets/item_context_menu.dart';

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
  Widget build(BuildContext context) => Material(
    color: active ? const Color(0xFFF0F6F4) : Colors.white,
    child: InkWell(
      key: ValueKey('quick-item-${item.id}'),
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
          items: itemContextMenu(item, boards),
        );
        if (value != null) actions.handleItem(value, item);
      },
      child: SizedBox(
        height: 80,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F1EF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(clipIcon(item), size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: item.preview != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            item.preview!,
                            width: 110,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title.replaceAll('\n', ' '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.source,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
              ),
              if (index < 9)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '⌘${index + 1}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              IconButton(
                tooltip: 'Copy to clipboard',
                onPressed: () => actions.copy(item),
                icon: const Icon(Icons.copy_outlined, size: 17, color: accent),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

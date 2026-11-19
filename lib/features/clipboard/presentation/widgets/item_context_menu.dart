import 'package:flutter/material.dart';

import '../../domain/clipboard_item.dart';
import '../../domain/pinboard.dart';
import '../clipboard_style.dart';

List<PopupMenuEntry<String>> itemContextMenu(
  ClipItem item,
  List<Pinboard> boards,
) => [
  const PopupMenuItem(value: 'paste', child: Text('Paste')),
  const PopupMenuItem(value: 'copy', child: Text('Copy to clipboard')),
  if (item.text.isNotEmpty)
    const PopupMenuItem(value: 'plain', child: Text('Copy as plain text')),
  const PopupMenuItem(value: 'preview', child: Text('Preview')),
  if (item.text.isNotEmpty && !item.snippet)
    const PopupMenuItem(value: 'snippet', child: Text('Save as snippet')),
  if (boards.isNotEmpty) const PopupMenuDivider(),
  for (final board in boards)
    PopupMenuItem(
      value: 'pin:${board.id}',
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: boardColor(board.color)),
          const SizedBox(width: 10),
          Text('Pin to ${board.name}'),
        ],
      ),
    ),
  if (item.boardID.isNotEmpty)
    const PopupMenuItem(value: 'unpin', child: Text('Remove from pinboard')),
  const PopupMenuDivider(),
  const PopupMenuItem(value: 'delete', child: Text('Delete item')),
];

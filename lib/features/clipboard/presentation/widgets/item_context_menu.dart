import 'package:flutter/material.dart';

import '../../../../app/tokens.dart';
import '../../domain/clipboard_item.dart';
import '../../domain/pinboard.dart';
import '../clipboard_style.dart';

PopupMenuItem<String> _item(
  String value,
  IconData icon,
  String label,
  ShelfColors colors, {
  Color? color,
}) => PopupMenuItem(
  value: value,
  height: 36,
  child: Row(
    children: [
      Icon(icon, size: 16, color: color ?? colors.textSecondary),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color),
        ),
      ),
    ],
  ),
);

List<PopupMenuEntry<String>> itemContextMenu(
  ClipItem item,
  List<Pinboard> boards,
  ShelfColors colors,
) => [
  _item('paste', Icons.content_paste_go_outlined, 'Paste', colors),
  _item('copy', Icons.copy_outlined, 'Copy to clipboard', colors),
  if (item.text.isNotEmpty)
    _item('plain', Icons.text_fields, 'Copy as plain text', colors),
  _item('preview', Icons.visibility_outlined, 'Preview', colors),
  if (item.text.isNotEmpty && !item.snippet)
    _item('snippet', Icons.bookmark_add_outlined, 'Save as snippet', colors),
  if (boards.isNotEmpty) const PopupMenuDivider(),
  for (final board in boards)
    PopupMenuItem(
      value: 'pin:${board.id}',
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Center(
              child: Icon(
                Icons.circle,
                size: 10,
                color: boardColor(colors, board.color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Pin to ${board.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  if (item.boardID.isNotEmpty)
    _item('unpin', Icons.push_pin_outlined, 'Remove from pinboard', colors),
  const PopupMenuDivider(),
  _item(
    'delete',
    Icons.delete_outline,
    'Delete item',
    colors,
    color: colors.danger,
  ),
];

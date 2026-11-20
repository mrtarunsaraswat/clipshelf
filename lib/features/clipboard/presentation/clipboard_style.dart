import 'package:flutter/material.dart';

import '../../../app/tokens.dart';
import '../domain/clipboard_item.dart';
import '../domain/pinboard.dart';

/// Number of pinboard colours; a board's `color` is an index into this palette.
const boardColorCount = 6;
Color boardColor(ShelfColors colors, int index) =>
    colors.boards[index.abs() % colors.boards.length];
Color cardColor(ClipItem item, List<Pinboard> boards, ShelfColors colors) {
  if (item.boardID.isNotEmpty) {
    final board = boards.where((b) => b.id == item.boardID).firstOrNull;
    if (board != null) return boardColor(colors, board.color);
  }
  if (item.snippet) return colors.kindSnippet;
  if (item.kind == 'image') return colors.kindImage;
  if (item.kind == 'file') return colors.kindFile;
  if (isLink(item)) return colors.kindLink;
  return colors.kindText;
}

bool isLink(ClipItem item) => item.isLink;

IconData clipIcon(ClipItem item) => item.snippet
    ? Icons.bookmark_outline
    : switch (item.kind) {
        'image' => Icons.image_outlined,
        'file' => Icons.insert_drive_file_outlined,
        'other' => Icons.data_object,
        _ => Icons.notes_rounded,
      };
String formatClipAge(DateTime date) {
  final duration = DateTime.now().difference(date);
  if (duration.inMinutes < 1) return 'Just now';
  if (duration.inHours < 1) return '${duration.inMinutes}m ago';
  if (duration.inDays < 1) return '${duration.inHours}h ago';
  return '${duration.inDays}d ago';
}

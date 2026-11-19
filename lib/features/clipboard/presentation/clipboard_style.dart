import 'package:flutter/material.dart';

import '../domain/clipboard_item.dart';
import '../domain/pinboard.dart';

const boardColors = [
  Color(0xFF5B80DD),
  Color(0xFFE78A50),
  Color(0xFFAE75CD),
  Color(0xFF54A68D),
  Color(0xFFD67790),
  Color(0xFFC7A94A),
];
Color boardColor(int index) => boardColors[index.abs() % boardColors.length];
Color cardColor(ClipItem item, List<Pinboard> boards) {
  if (item.boardID.isNotEmpty) {
    final board = boards.where((b) => b.id == item.boardID).firstOrNull;
    if (board != null) return boardColor(board.color);
  }
  if (item.snippet) return const Color(0xFFB783C6);
  if (item.kind == 'image') return const Color(0xFF69A898);
  if (item.kind == 'file') return const Color(0xFFE2A05E);
  if (Uri.tryParse(item.text.trim())?.hasScheme == true) {
    return const Color(0xFF7298D1);
  }
  return const Color(0xFF718EA0);
}

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

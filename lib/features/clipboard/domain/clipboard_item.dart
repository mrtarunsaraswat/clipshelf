import 'dart:typed_data';

/// An immutable, materialized clipboard entry. Native code owns persistence.
class ClipItem {
  ClipItem({
    required this.id,
    required this.title,
    required this.text,
    required this.kind,
    required this.source,
    required this.snippet,
    required this.date,
    required this.size,
    required List<String> formats,
    this.boardID = '',
    Uint8List? preview,
  }) : formats = List.unmodifiable(formats),
       preview = preview == null
           ? null
           : Uint8List.fromList(preview).asUnmodifiableView();

  factory ClipItem.fromMap(Map<Object?, Object?> data) => ClipItem(
    id: data['id'] as String,
    title: data['title'] as String,
    text: data['text'] as String,
    kind: data['kind'] as String,
    source: data['source'] as String,
    snippet: data['snippet'] as bool,
    date: DateTime.fromMillisecondsSinceEpoch(
      ((data['date'] as num) * 1000).round(),
    ),
    size: data['size'] as int,
    formats: List<String>.from(data['formats'] as List),
    boardID: data['boardID'] as String? ?? '',
    preview: data['preview'] as Uint8List?,
  );
  final String id, title, text, kind, source, boardID;
  final bool snippet;
  final DateTime date;
  final int size;
  final List<String> formats;
  final Uint8List? preview;

  bool matches(String query) => '$title $text $source ${formats.join(' ')}'
      .toLowerCase()
      .contains(query.toLowerCase().trim());
}

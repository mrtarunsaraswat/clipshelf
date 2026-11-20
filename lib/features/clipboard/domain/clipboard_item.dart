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
    this.sourceBundleID = '',
    this.pixelWidth = 0,
    this.pixelHeight = 0,
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
    sourceBundleID: data['sourceBundleID'] as String? ?? '',
    pixelWidth: data['pixelWidth'] as int? ?? 0,
    pixelHeight: data['pixelHeight'] as int? ?? 0,
    preview: data['preview'] as Uint8List?,
  );
  final String id, title, text, kind, source, boardID;

  /// App the copy came from (for its icon); empty for snippets and old items.
  final String sourceBundleID;

  /// Original image size in pixels; 0 when unknown.
  final int pixelWidth, pixelHeight;
  final bool snippet;
  final DateTime date;
  final int size;
  final List<String> formats;
  final Uint8List? preview;

  /// Text that is a URL with a scheme (https://…, mailto:…).
  bool get isLink => Uri.tryParse(text.trim())?.hasScheme == true;

  bool matches(String query) => '$title $text $source ${formats.join(' ')}'
      .toLowerCase()
      .contains(query.toLowerCase().trim());
}

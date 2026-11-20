import 'clipboard_item.dart';

enum SearchTokenGroup { kind, date, app }

/// A search filter shown as a chip in the search field: a content type
/// (Link, Image…), a date range (Last week…) or a source app (Mail…).
/// Chips in the same group widen the results (Link or Image); different
/// groups narrow them (Link and Mail).
class SearchToken {
  const SearchToken._(this.group, this.value, this.label);

  const SearchToken.kind(String kind, String label)
    : this._(SearchTokenGroup.kind, kind, label);
  const SearchToken.date(String range, String label)
    : this._(SearchTokenGroup.date, range, label);
  SearchToken.app(String name) : this._(SearchTokenGroup.app, name, name);

  final SearchTokenGroup group;
  final String value, label;

  static const kinds = [
    SearchToken.kind('link', 'Link'),
    SearchToken.kind('text', 'Text'),
    SearchToken.kind('image', 'Image'),
    SearchToken.kind('file', 'File'),
    SearchToken.kind('snippet', 'Snippet'),
  ];
  static const dates = [
    SearchToken.date('today', 'Today'),
    SearchToken.date('yesterday', 'Yesterday'),
    SearchToken.date('week', 'Last week'),
    SearchToken.date('month', 'Last month'),
  ];

  bool matches(ClipItem item, DateTime now) => switch (group) {
    SearchTokenGroup.kind => switch (value) {
      'link' => item.isLink,
      'text' => item.kind == 'text' && !item.isLink,
      'snippet' => item.snippet,
      _ => item.kind == value,
    },
    SearchTokenGroup.date => _inRange(item.date, now),
    SearchTokenGroup.app => item.source == value,
  };

  bool _inRange(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (value) {
      'today' => !date.isBefore(today),
      'yesterday' =>
        !date.isBefore(today.subtract(const Duration(days: 1))) &&
            date.isBefore(today),
      'week' => now.difference(date) <= const Duration(days: 7),
      _ => now.difference(date) <= const Duration(days: 30),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is SearchToken && other.group == group && other.value == value;
  @override
  int get hashCode => Object.hash(group, value);
}

/// True when [item] satisfies every group of [tokens].
bool matchesTokens(ClipItem item, List<SearchToken> tokens, DateTime now) {
  for (final group in SearchTokenGroup.values) {
    final inGroup = tokens.where((t) => t.group == group);
    if (inGroup.isNotEmpty && !inGroup.any((t) => t.matches(item, now))) {
      return false;
    }
  }
  return true;
}

/// Filters to offer for what the user is typing: types and dates by prefix,
/// then source apps that appear in [clips]. Already-chosen tokens are skipped.
List<SearchToken> suggestTokens(
  String query,
  List<ClipItem> clips,
  List<SearchToken> chosen, {
  int limit = 6,
}) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return const [];
  bool fits(String label) {
    final lower = label.toLowerCase();
    return lower.startsWith(text) ||
        lower.split(' ').any((word) => word.startsWith(text));
  }

  final apps = <String>{
    for (final clip in clips)
      if (clip.source.isNotEmpty &&
          clip.source != 'Unknown app' &&
          clip.source != 'Snippet')
        clip.source,
  }.toList()..sort();
  return [
    ...SearchToken.kinds.where((t) => fits(t.label)),
    ...SearchToken.dates.where((t) => fits(t.label)),
    ...apps.map(SearchToken.app).where((t) => fits(t.label)),
  ].where((t) => !chosen.contains(t)).take(limit).toList();
}

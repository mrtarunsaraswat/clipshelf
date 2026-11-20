import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/domain/search_token.dart';
import 'package:flutter_test/flutter_test.dart';

ClipItem _item(
  String id, {
  String text = 'plain text',
  String kind = 'text',
  String source = 'Notes',
  bool snippet = false,
  DateTime? date,
}) => ClipItem(
  id: id,
  title: text,
  text: text,
  kind: kind,
  source: source,
  snippet: snippet,
  date: date ?? DateTime(2026, 11, 20, 12),
  size: text.length,
  formats: const [],
);

void main() {
  final now = DateTime(2026, 11, 20, 15);
  final link = _item('link', text: 'https://flutter.dev', source: 'Safari');
  final mailLink = _item('mail', text: 'https://example.com', source: 'Mail');
  final image = _item('image', text: '', kind: 'image', source: 'Preview');
  final old = _item('old', date: DateTime(2026, 9, 1));
  final yesterday = _item('yday', date: DateTime(2026, 11, 19, 20));

  test('kind tokens tell links apart from other text', () {
    const linkToken = SearchToken.kind('link', 'Link');
    const textToken = SearchToken.kind('text', 'Text');
    expect(linkToken.matches(link, now), isTrue);
    expect(linkToken.matches(old, now), isFalse);
    expect(textToken.matches(link, now), isFalse);
    expect(textToken.matches(old, now), isTrue);
  });

  test('date tokens use calendar days and rolling ranges', () {
    expect(SearchToken.dates[0].matches(link, now), isTrue); // Today
    expect(SearchToken.dates[0].matches(yesterday, now), isFalse);
    expect(SearchToken.dates[1].matches(yesterday, now), isTrue); // Yesterday
    expect(SearchToken.dates[2].matches(old, now), isFalse); // Last week
    expect(SearchToken.dates[3].matches(yesterday, now), isTrue); // Last month
  });

  test('same-group tokens widen, different groups narrow', () {
    const linkToken = SearchToken.kind('link', 'Link');
    const imageToken = SearchToken.kind('image', 'Image');
    final mail = SearchToken.app('Mail');
    expect(matchesTokens(link, [linkToken, imageToken], now), isTrue);
    expect(matchesTokens(image, [linkToken, imageToken], now), isTrue);
    expect(matchesTokens(link, [linkToken, mail], now), isFalse);
    expect(matchesTokens(mailLink, [linkToken, mail], now), isTrue);
    expect(matchesTokens(old, const [], now), isTrue);
  });

  test('suggestions match by word prefix and skip chosen filters', () {
    final clips = [link, mailLink, image];
    expect(suggestTokens('li', clips, const []).map((t) => t.label), ['Link']);
    expect(suggestTokens('week', clips, const []).map((t) => t.label), [
      'Last week',
    ]);
    expect(suggestTokens('ma', clips, const []).map((t) => t.label), ['Mail']);
    expect(
      suggestTokens('li', clips, const [SearchToken.kind('link', 'Link')]),
      isEmpty,
    );
    expect(suggestTokens('  ', clips, const []), isEmpty);
  });
}

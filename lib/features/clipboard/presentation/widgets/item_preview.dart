import 'package:flutter/material.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';

class ItemPreview extends StatelessWidget {
  const ItemPreview({super.key, required this.item, required this.actions});
  final ClipItem item;
  final ClipboardActions actions;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE4EAE4)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.snippet
                    ? 'SAVED SNIPPET'
                    : '${item.kind.toUpperCase()} PREVIEW',
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  color: Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Item actions',
              onSelected: (value) {
                if (value == 'delete') actions.delete(item);
                if (value == 'snippet') actions.showSnippet(item);
              },
              itemBuilder: (_) => [
                if (item.text.isNotEmpty && !item.snippet)
                  const PopupMenuItem(
                    value: 'snippet',
                    child: Text('Save as snippet'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete item'),
                ),
              ],
              icon: const Icon(Icons.more_horiz, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.preview != null)
                  Image.memory(
                    item.preview!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) =>
                        const Text('Preview unavailable'),
                  ),
                if (item.text.isNotEmpty)
                  SelectableText(
                    item.text,
                    style: const TextStyle(fontSize: 13, height: 1.65),
                  )
                else if (item.preview == null)
                  Text(item.title, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  '${item.source} · ${(item.size / 1024).toStringAsFixed(1)} KB',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  item.formats.join('\n'),
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: Colors.grey,
                  ),
                ),
                if (item.kind == 'file')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'File references require the original files to remain available.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => actions.paste(item),
            icon: const Icon(Icons.content_paste, size: 16),
            label: const Text('Paste into previous app'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => actions.copy(item),
            child: const Text('Copy only'),
          ),
        ),
      ],
    ),
  );
}

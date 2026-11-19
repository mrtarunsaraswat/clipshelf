import 'package:flutter/material.dart';

import '../../../app/tokens.dart';
import '../../../app/widgets/settings_group.dart';
import '../domain/snippet_draft.dart';

class SnippetDialog extends StatefulWidget {
  const SnippetDialog({super.key, this.initialText = ''});
  final String initialText;
  @override
  State<SnippetDialog> createState() => _SnippetDialogState();
}

class _SnippetDialogState extends State<SnippetDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  late final _text = TextEditingController(text: widget.initialText);
  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: SettingsIcon(
      Icons.bookmark_add_outlined,
      color: context.shelf.kindSnippet,
    ),
    title: const Text(
      'A little less typing.',
      style: TextStyle(
        fontSize: ShelfType.heading + 1,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Save an address, reply, or anything you use often.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.shelf.textSecondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Snippet name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _text,
              minLines: 5,
              maxLines: 9,
              maxLength: 1000000,
              decoration: const InputDecoration(labelText: 'Text'),
              validator: (text) => text == null || text.trim().isEmpty
                  ? 'Add some text to save.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              SnippetDraft(title: _title.text, text: _text.text),
            );
          }
        },
        child: const Text('Save snippet'),
      ),
    ],
  );
}

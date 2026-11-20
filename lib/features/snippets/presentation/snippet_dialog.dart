import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/tokens.dart';
import '../../../app/widgets/dialog_parts.dart';
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

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        SnippetDraft(title: _title.text, text: _text.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
      },
      child: AlertDialog(
        // Scroll instead of overflowing in the short shelf window.
        scrollable: true,
        clipBehavior: Clip.antiAlias,
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        title: ShelfDialogHeader(
          icon: Icons.bookmark_add_rounded,
          tint: colors.kindSnippet,
          title: 'A little less typing.',
          subtitle: 'Save an address, reply, or anything you use often.',
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldLabel(
                  'Name',
                  trailing: Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: ShelfType.caption,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: dialogFieldDecoration(
                    context,
                    'e.g. Email signature',
                  ),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Text'),
                TextFormField(
                  controller: _text,
                  minLines: 5,
                  maxLines: 9,
                  maxLength: 1000000,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: ShelfType.body,
                    height: 1.45,
                  ),
                  decoration: dialogFieldDecoration(
                    context,
                    'Type or paste the text you reuse…',
                  ),
                  validator: (text) => text == null || text.trim().isEmpty
                      ? 'Add some text to save.'
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 2),
                  child: ValueListenableBuilder(
                    valueListenable: _text,
                    builder: (context, value, _) {
                      final count = value.text.characters.length;
                      return Text(
                        '$count ${count == 1 ? 'character' : 'characters'}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: ShelfType.caption,
                          color: colors.textTertiary,
                          fontFeatures: ShelfType.tabular,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.fromLTRB(18, 0, 10, 0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Save snippet'),
                const SizedBox(width: 8),
                const OnFilledKeycap(label: '⌘↩'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

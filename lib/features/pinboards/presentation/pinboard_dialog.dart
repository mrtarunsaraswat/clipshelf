import 'package:flutter/material.dart';

import '../domain/pinboard_draft.dart';
import '../../../app/tokens.dart';
import '../../clipboard/presentation/clipboard_style.dart';

class PinboardDialog extends StatefulWidget {
  const PinboardDialog({super.key});
  @override
  State<PinboardDialog> createState() => _PinboardDialogState();
}

class _PinboardDialogState extends State<PinboardDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  int _color = 0;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New pinboard'),
    content: SizedBox(
      width: 360,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keep a project’s snippets, links, and images together.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 48,
              decoration: const InputDecoration(labelText: 'Pinboard name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Give your pinboard a name.'
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                for (var i = 0; i < boardColorCount; i++)
                  InkWell(
                    onTap: () => setState(() => _color = i),
                    borderRadius: BorderRadius.circular(18),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: boardColor(context.shelf, i),
                      child: _color == i
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
              ],
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
              PinboardDraft(name: _name.text.trim(), color: _color),
            );
          }
        },
        child: const Text('Create pinboard'),
      ),
    ],
  );
}

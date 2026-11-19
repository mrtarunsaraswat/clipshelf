import 'package:flutter/material.dart';

import '../domain/pinboard_draft.dart';
import '../../../app/tokens.dart';
import '../../../app/widgets/settings_group.dart';
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
    icon: SettingsIcon(
      Icons.push_pin_outlined,
      color: boardColor(context.shelf, _color),
    ),
    title: const Text(
      'New pinboard',
      style: TextStyle(
        fontSize: ShelfType.heading + 1,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: SizedBox(
      width: 360,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Keep a project’s snippets, links, and images together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.shelf.textSecondary),
              ),
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
            Text(
              'Colour',
              style: TextStyle(
                fontSize: ShelfType.meta,
                fontWeight: FontWeight.w600,
                color: context.shelf.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (var i = 0; i < boardColorCount; i++)
                  Tooltip(
                    message: 'Colour ${i + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() => _color = i),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 30,
                          height: 30,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == i
                                  ? boardColor(context.shelf, i)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: boardColor(context.shelf, i),
                              shape: BoxShape.circle,
                            ),
                            child: _color == i
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : null,
                          ),
                        ),
                      ),
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

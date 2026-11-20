import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/pinboard_draft.dart';
import '../../../app/tokens.dart';
import '../../../app/widgets/dialog_parts.dart';
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

  void _create() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        PinboardDraft(name: _name.text.trim(), color: _color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final tint = boardColor(colors, _color);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _create,
      },
      child: AlertDialog(
        // Scroll instead of overflowing in the short shelf window.
        scrollable: true,
        clipBehavior: Clip.antiAlias,
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        title: ShelfDialogHeader(
          icon: Icons.push_pin_rounded,
          tint: tint,
          title: 'New pinboard',
          subtitle: 'Keep a project’s snippets, links, and images together.',
        ),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Name'),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 48,
                  onFieldSubmitted: (_) => _create(),
                  decoration: dialogFieldDecoration(
                    context,
                    'e.g. Launch week',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Give your pinboard a name.'
                      : null,
                ),
                const SizedBox(height: 16),
                const FieldLabel('Colour'),
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
                const SizedBox(height: 16),
                const FieldLabel('Preview'),
                // How the new pinboard will look among the collection tabs.
                ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (context, value, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.stroke),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            value.text.trim().isEmpty
                                ? 'Pinboard'
                                : value.text.trim(),
                            style: TextStyle(
                              fontSize: ShelfType.meta,
                              fontWeight: FontWeight.w600,
                              color: value.text.trim().isEmpty
                                  ? colors.textTertiary
                                  : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
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
            onPressed: _create,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.fromLTRB(18, 0, 10, 0),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Create pinboard'),
                SizedBox(width: 8),
                OnFilledKeycap(label: '⌘↩'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

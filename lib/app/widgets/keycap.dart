import 'package:flutter/material.dart';

import '../tokens.dart';

/// A small keyboard-key badge, e.g. ⌘1 or esc.
class Keycap extends StatelessWidget {
  const Keycap(this.label, {super.key, this.dense = false});
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Container(
      constraints: BoxConstraints(minWidth: dense ? 16 : 20),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : 5,
        vertical: dense ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colors.stroke),
        boxShadow: [
          BoxShadow(color: colors.stroke, offset: const Offset(0, 1)),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: dense ? 10 : ShelfType.caption,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
          fontFeatures: ShelfType.tabular,
        ),
      ),
    );
  }
}

/// Keycaps followed by a short label, for footer hint bars.
class KeyHint extends StatelessWidget {
  const KeyHint({super.key, required this.keys, required this.label});
  final List<String> keys;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final key in keys) ...[
        Keycap(key, dense: true),
        const SizedBox(width: 3),
      ],
      const SizedBox(width: 2),
      Text(
        label,
        style: TextStyle(
          fontSize: ShelfType.caption,
          color: context.shelf.textTertiary,
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../tokens.dart';

/// A System Settings–style group: a small header above a rounded inset box
/// whose rows are separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });
  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Padding(
      padding: const EdgeInsets.only(bottom: ShelfSpace.xl - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ShelfType.meta,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(ShelfRadius.md),
              border: Border.all(color: colors.stroke),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ShelfRadius.md),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 52, color: colors.stroke),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: ShelfType.caption,
                  height: 1.5,
                  color: colors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Coloured rounded icon tile used as the leading element of a settings row.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Icon(icon, size: 15, color: Colors.white),
  );
}

/// Shared padding and type for rows inside a [SettingsGroup].
const settingsRowPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 2);
TextStyle settingsSubtitleStyle(BuildContext context) => TextStyle(
  fontSize: ShelfType.meta,
  height: 1.4,
  color: context.shelf.textSecondary,
);
